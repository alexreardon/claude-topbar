import Foundation

// MARK: - Shared helpers

enum ISODate {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let withoutFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        return withFractional.date(from: value) ?? withoutFractional.date(from: value)
    }
}

func formatUSD(_ dollars: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "en_US")
    formatter.currencySymbol = "$"
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
}

// MARK: - Usage response

struct UsageResponse: Decodable, Sendable {
    /// Every rolling limit the API reports (session, weekly, per-model, ...), in
    /// display order. Built from the `limits` array, with the legacy top-level
    /// buckets (`five_hour`, `seven_day`, ...) filling any gaps. The API has moved
    /// limits around before, so nothing else reads the raw buckets.
    let rollingLimits: [UsageLimit]
    let extraUsage: ExtraUsage?
    /// Present on accounts governed by a dollar spend limit instead of rolling sessions.
    let spend: SpendInfo?
    /// Dollar-denominated credit balances (e.g. the Claude Code & Cowork "Included credit").
    /// Keyed by internal codenames that change over time, so we discover them dynamically.
    let creditBuckets: [CreditBucket]

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    /// Keys we decode explicitly — everything else is probed for being a credit bucket.
    private static let knownKeys: Set<String> = [
        "five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet",
        "extra_usage", "spend", "limits",
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)

        func bucket(_ key: String) -> UsageBucket? {
            guard let codingKey = DynamicKey(stringValue: key) else { return nil }
            return try? container.decodeIfPresent(UsageBucket.self, forKey: codingKey)
        }

        var limits: [UsageLimit] = []
        func add(_ limit: UsageLimit) {
            if !limits.contains(where: { $0.covers(limit) }) { limits.append(limit) }
        }
        // The `limits` array is the current source and names model-scoped caps.
        let entries = DynamicKey(stringValue: "limits")
            .flatMap { (try? container.decodeIfPresent([LimitEntry].self, forKey: $0)) ?? nil } ?? []
        entries.compactMap(\.usageLimit).forEach(add)
        // Legacy top-level buckets fill any gaps.
        let legacy: [(key: String, group: String, model: String?)] = [
            ("five_hour", "session", nil),
            ("seven_day", "weekly", nil),
            ("seven_day_opus", "weekly", "Opus"),
            ("seven_day_sonnet", "weekly", "Sonnet"),
        ]
        for (key, group, model) in legacy {
            guard let b = bucket(key) else { continue }
            add(UsageLimit(group: group, model: model, utilization: b.utilization, resetsAt: b.resetsAt))
        }
        rollingLimits = UsageLimit.displayOrder(limits)

        extraUsage = DynamicKey(stringValue: "extra_usage")
            .flatMap { try? container.decodeIfPresent(ExtraUsage.self, forKey: $0) }
        spend = DynamicKey(stringValue: "spend")
            .flatMap { try? container.decodeIfPresent(SpendInfo.self, forKey: $0) }

        var credits: [CreditBucket] = []
        for key in container.allKeys where !Self.knownKeys.contains(key.stringValue) {
            if let raw = try? container.decodeIfPresent(CreditBucket.Raw.self, forKey: key),
               raw.hasCredit {
                credits.append(CreditBucket(key: key.stringValue, raw: raw))
            }
        }
        creditBuckets = credits
    }

    /// The limit the menu bar shows unless the user pins one: the overall limit
    /// closest to its cap (for most plans, the weekly limit). Model-scoped caps
    /// only block one model, so they count only when no overall limit exists.
    var automaticLimit: UsageLimit? {
        let overall = rollingLimits.filter { $0.scope == .overall }
        let candidates = overall.isEmpty ? rollingLimits : overall
        // On a tie, prefer the longer window: it blocks you for longer.
        return candidates.max {
            ($0.bucket.utilization, $0.windowHours ?? 0) < ($1.bucket.utilization, $1.windowHours ?? 0)
        }
    }

    /// Spend-limit accounts (e.g. Enterprise) have no rolling limits, so their
    /// dollar cap is the measure. It has no time window, so it is not paced.
    var spendLimit: UsageLimit? {
        guard rollingLimits.isEmpty, let spend, spend.enabled == true, let percent = spend.percent else {
            return nil
        }
        return UsageLimit(
            id: "spend", label: "Spend limit", scope: .overall,
            bucket: UsageBucket(utilization: percent, resetsAt: nil), windowHours: nil
        )
    }

    /// Whether there's anything meaningful to render in the panel.
    var hasDisplayableUsage: Bool {
        !rollingLimits.isEmpty
            || (spend?.enabled == true)
            || !creditBuckets.isEmpty
            || (extraUsage?.isEnabled == true && extraUsage?.percentage != nil)
    }
}

// MARK: - Rolling-session buckets

struct UsageBucket: Codable, Sendable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.utilization = (try? container.decode(Double.self, forKey: .utilization)) ?? 0
        self.resetsAt = try? container.decode(String.self, forKey: .resetsAt)
    }

    /// Build a bucket directly (used to render `limits` entries through the same machinery).
    init(utilization: Double, resetsAt: String?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }

    var resetsAtDate: Date? { ISODate.parse(resetsAt) }

    /// utilization comes from the API as 0-100 (already a percentage)
    var percentage: Int {
        Int(utilization.rounded())
    }

    /// Normalized to 0.0-1.0 for progress bars
    var fraction: Double {
        min(utilization / 100.0, 1.0)
    }

    /// How far through the time window we are (0.0 to 1.0)
    func windowProgress(windowHours: Double) -> Double {
        guard let resetsAt = resetsAtDate else { return 0 }
        let windowDuration = windowHours * 3600
        let windowStart = resetsAt.addingTimeInterval(-windowDuration)
        let now = Date()
        guard now >= windowStart else { return 0 }
        guard now < resetsAt else { return 1 }
        return now.timeIntervalSince(windowStart) / windowDuration
    }
}

// MARK: - Rolling limits (normalized)

/// One rolling usage limit, normalized from either the `limits` array or a
/// legacy top-level bucket. The menu bar and the panel both read this shape.
struct UsageLimit: Identifiable, Sendable {
    enum Scope: Sendable, Equatable {
        /// Applies to all usage, e.g. the weekly limit.
        case overall
        /// Applies to one model only, e.g. a weekly limit for Fable.
        case model(String)
    }

    /// Stable across polls (e.g. "weekly", "weekly:fable"). Saved when the user
    /// pins a limit to the menu bar.
    let id: String
    let label: String
    let scope: Scope
    let bucket: UsageBucket
    /// Length of the rolling window. Nil when unknown or when there is no window.
    let windowHours: Double?

    /// Pace against time only when both the window and its end are known.
    var isPaced: Bool { windowHours != nil && bucket.resetsAtDate != nil }

    /// How far through the window we are (0.0 to 1.0); 0 when not paced.
    var windowProgress: Double {
        guard let windowHours else { return 0 }
        return bucket.windowProgress(windowHours: windowHours)
    }

    enum Level { case normal, warning, critical }

    /// One color rule for every view: thresholds first, then pace against time.
    func level(windowProgress: Double) -> Level {
        if bucket.percentage >= 95 { return .critical }
        if bucket.percentage >= 80 { return .warning }
        guard isPaced else { return .normal }
        return bucket.fraction < windowProgress ? .normal : .warning
    }

    /// True when `other` is the same limit, so it should not show twice.
    /// Model names are matched loosely ("Opus" vs "Opus 4.8").
    func covers(_ other: UsageLimit) -> Bool {
        if id == other.id { return true }
        guard case .model(let a) = scope, case .model(let b) = other.scope,
              windowHours == other.windowHours else { return false }
        let (x, y) = (a.lowercased(), b.lowercased())
        return x.contains(y) || y.contains(x)
    }

    /// Overall limits first, shortest window first; then model limits in API order.
    static func displayOrder(_ limits: [UsageLimit]) -> [UsageLimit] {
        let overall = limits.enumerated()
            .filter { $0.element.scope == .overall }
            .sorted {
                ($0.element.windowHours ?? .infinity, $0.offset) < ($1.element.windowHours ?? .infinity, $1.offset)
            }
            .map(\.element)
        return overall + limits.filter { $0.scope != .overall }
    }
}

extension UsageLimit {
    private struct Window {
        let id: String
        let title: String
        let suffix: String
        let hours: Double
    }

    /// Window groups we know. Unknown groups still show, just without a pace tick.
    private static func window(for group: String) -> Window? {
        switch group.lowercased() {
        case "session", "five_hour": return Window(id: "session", title: "Session", suffix: "5h", hours: 5)
        case "daily": return Window(id: "daily", title: "Daily", suffix: "24h", hours: 24)
        case "weekly", "seven_day": return Window(id: "weekly", title: "Weekly", suffix: "7d", hours: 7 * 24)
        default: return nil
        }
    }

    init(group: String, model: String?, utilization: Double, resetsAt: String?) {
        let window = Self.window(for: group)
        let groupID = window?.id ?? group.lowercased()
        let suffix = window.map { " (\($0.suffix))" } ?? ""
        if let model {
            id = "\(groupID):\(model.lowercased())"
            label = model + suffix
            scope = .model(model)
        } else {
            id = groupID
            label = (window?.title ?? group.replacingOccurrences(of: "_", with: " ").capitalized) + suffix
            scope = .overall
        }
        bucket = UsageBucket(utilization: utilization, resetsAt: resetsAt)
        windowHours = window?.hours
    }
}

/// One entry in the API's `limits` array, e.g.
/// `{"kind": "weekly_scoped", "group": "weekly", "percent": 65, "resets_at": ...,
///   "scope": {"model": {"display_name": "Fable"}}}`.
private struct LimitEntry: Decodable {
    let group: String?
    let kind: String?
    let percent: Double?
    let resetsAt: String?
    /// Display name of the model this limit is scoped to, e.g. "Fable".
    let modelName: String?

    private enum CodingKeys: String, CodingKey {
        case group, kind, percent, scope
        case resetsAt = "resets_at"
    }

    private struct Scope: Decodable {
        struct Model: Decodable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
        let model: Model?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        group = try? c.decode(String.self, forKey: .group)
        kind = try? c.decode(String.self, forKey: .kind)
        percent = try? c.decode(Double.self, forKey: .percent)
        resetsAt = try? c.decode(String.self, forKey: .resetsAt)
        let scope = (try? c.decodeIfPresent(Scope.self, forKey: .scope)) ?? nil
        modelName = scope?.model?.displayName
    }

    var usageLimit: UsageLimit? {
        // Prefer `group`; else take it from `kind` ("weekly_all" -> "weekly").
        guard let group = group ?? kind?.split(separator: "_").first.map(String.init) else { return nil }
        return UsageLimit(group: group, model: modelName, utilization: percent ?? 0, resetsAt: resetsAt)
    }
}

// MARK: - Spend limit

struct Money: Decodable, Sendable {
    let amountMinor: Double?
    let exponent: Int?
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case amountMinor = "amount_minor"
        case exponent
        case currency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.amountMinor = try? container.decode(Double.self, forKey: .amountMinor)
        self.exponent = try? container.decode(Int.self, forKey: .exponent)
        self.currency = try? container.decode(String.self, forKey: .currency)
    }

    var dollars: Double? {
        guard let amountMinor else { return nil }
        return amountMinor / pow(10, Double(exponent ?? 2))
    }
}

struct SpendInfo: Decodable, Sendable {
    let used: Money?
    let limit: Money?
    let percent: Double?
    let severity: String?
    let enabled: Bool?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.used = try? container.decode(Money.self, forKey: .used)
        self.limit = try? container.decode(Money.self, forKey: .limit)
        self.percent = try? container.decode(Double.self, forKey: .percent)
        self.severity = try? container.decode(String.self, forKey: .severity)
        self.enabled = try? container.decode(Bool.self, forKey: .enabled)
    }

    enum CodingKeys: String, CodingKey {
        case used, limit, percent, severity, enabled
    }

    var percentage: Int? {
        guard let percent else { return nil }
        return Int(percent.rounded())
    }

    var fraction: Double? {
        guard let percent else { return nil }
        return min(percent / 100.0, 1.0)
    }

    /// e.g. "$0.00 of $300.00"
    var amountSummary: String? {
        guard let used = used?.dollars, let limit = limit?.dollars else { return nil }
        return "\(formatUSD(used)) of \(formatUSD(limit))"
    }
}

// MARK: - Dollar credit buckets (e.g. "Included credit")

struct CreditBucket: Sendable, Identifiable {
    let key: String
    let utilization: Double
    let resetsAt: String?
    let limitDollars: Double?
    let usedDollars: Double?
    let remainingDollars: Double?

    var id: String { key }

    init(key: String, raw: Raw) {
        self.key = key
        self.utilization = raw.utilization ?? 0
        self.resetsAt = raw.resetsAt
        self.limitDollars = raw.limitDollars
        self.usedDollars = raw.usedDollars
        self.remainingDollars = raw.remainingDollars
    }

    /// Raw shape as returned by the API; key comes from the parent container.
    struct Raw: Decodable {
        let utilization: Double?
        let resetsAt: String?
        let limitDollars: Double?
        let usedDollars: Double?
        let remainingDollars: Double?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
            case limitDollars = "limit_dollars"
            case usedDollars = "used_dollars"
            case remainingDollars = "remaining_dollars"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.utilization = try? container.decode(Double.self, forKey: .utilization)
            self.resetsAt = try? container.decode(String.self, forKey: .resetsAt)
            self.limitDollars = try? container.decode(Double.self, forKey: .limitDollars)
            self.usedDollars = try? container.decode(Double.self, forKey: .usedDollars)
            self.remainingDollars = try? container.decode(Double.self, forKey: .remainingDollars)
        }

        /// Only treat as a real credit balance if it carries a dollar limit.
        var hasCredit: Bool { limitDollars != nil }
    }

    var percentage: Int {
        Int(utilization.rounded())
    }

    var fraction: Double {
        min(utilization / 100.0, 1.0)
    }

    var resetsAtDate: Date? { ISODate.parse(resetsAt) }

    /// e.g. "$59.38 of $1,000.00"
    var amountSummary: String? {
        guard let used = usedDollars, let limit = limitDollars else { return nil }
        return "\(formatUSD(used)) of \(formatUSD(limit))"
    }

    /// Human label for the known internal codenames; falls back to a title-cased key.
    var label: String {
        switch key {
        case "cinder_cove": return "Included credit"
        default:
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Extra usage (pay-as-you-go overflow)

struct ExtraUsage: Codable, Sendable {
    let utilization: Double?
    let monthlyLimit: Double?
    let usedCredits: Double?
    let isEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case utilization
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case isEnabled = "is_enabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.utilization = try? container.decode(Double.self, forKey: .utilization)
        self.monthlyLimit = try? container.decode(Double.self, forKey: .monthlyLimit)
        self.usedCredits = try? container.decode(Double.self, forKey: .usedCredits)
        self.isEnabled = try? container.decode(Bool.self, forKey: .isEnabled)
    }

    var percentage: Int? {
        guard let utilization else { return nil }
        return Int(utilization.rounded())
    }

    var fraction: Double? {
        guard let utilization else { return nil }
        return min(utilization / 100.0, 1.0)
    }

    var spentDollars: Double? {
        guard let usedCredits else { return nil }
        return usedCredits / 100.0
    }

    var limitDollars: Double? {
        guard let monthlyLimit else { return nil }
        return monthlyLimit / 100.0
    }

    var spentFormatted: String? {
        guard let dollars = spentDollars else { return nil }
        return String(format: "$%.2f", dollars)
    }
}

struct Organization: Codable, Sendable {
    let uuid: String
    let name: String?
}
