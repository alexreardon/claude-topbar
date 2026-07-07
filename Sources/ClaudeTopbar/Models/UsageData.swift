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
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let extraUsage: ExtraUsage?
    /// Present on accounts governed by a dollar spend limit instead of rolling sessions.
    let spend: SpendInfo?
    /// Dollar-denominated credit balances (e.g. the Claude Code & Cowork "Included credit").
    /// Keyed by internal codenames that change over time, so we discover them dynamically.
    let creditBuckets: [CreditBucket]
    /// Per-model weekly caps from the `limits` array (e.g. a weekly limit scoped to
    /// Fable). This is where per-model weekly data lives now that the top-level
    /// `seven_day_opus`/`seven_day_sonnet` buckets are being retired.
    let weeklyScopedLimits: [ScopedLimit]

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

        fiveHour = bucket("five_hour")
        sevenDay = bucket("seven_day")
        sevenDayOpus = bucket("seven_day_opus")
        sevenDaySonnet = bucket("seven_day_sonnet")
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

        let limits = DynamicKey(stringValue: "limits")
            .flatMap { (try? container.decodeIfPresent([ScopedLimit].self, forKey: $0)) ?? nil } ?? []
        weeklyScopedLimits = limits.filter { $0.kind == "weekly_scoped" && $0.modelName != nil }
    }

    /// Whether there's anything meaningful to render in the panel.
    var hasDisplayableUsage: Bool {
        fiveHour != nil || sevenDay != nil || sevenDayOpus != nil || sevenDaySonnet != nil
            || !weeklyScopedLimits.isEmpty
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

// MARK: - Model-scoped limits (from the `limits` array)

/// One entry in the API's `limits` array. Alongside the top-level `five_hour`/
/// `seven_day` buckets, the API returns a `limits` array that also carries
/// per-model weekly caps (`kind == "weekly_scoped"`) — e.g. a weekly limit that
/// applies only to Fable. See `UsageResponse.weeklyScopedLimits`.
struct ScopedLimit: Decodable, Sendable, Identifiable {
    let group: String?
    let kind: String?
    let percent: Double?
    let resetsAt: String?
    let severity: String?
    let isActive: Bool?
    /// Display name of the model this limit is scoped to, e.g. "Fable".
    let modelName: String?

    var id: String { [kind, modelName].compactMap { $0 }.joined(separator: ":") }

    private enum CodingKeys: String, CodingKey {
        case group, kind, percent, severity, scope
        case resetsAt = "resets_at"
        case isActive = "is_active"
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
        severity = try? c.decode(String.self, forKey: .severity)
        isActive = try? c.decode(Bool.self, forKey: .isActive)
        let scope = (try? c.decodeIfPresent(Scope.self, forKey: .scope)) ?? nil
        modelName = scope?.model?.displayName
    }

    /// Render through the shared `UsageBucket` machinery (window tick, reset countdown).
    var bucket: UsageBucket {
        UsageBucket(utilization: percent ?? 0, resetsAt: resetsAt)
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
    let monthlyLimit: Int?
    let usedCredits: Int?
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
        self.monthlyLimit = try? container.decode(Int.self, forKey: .monthlyLimit)
        self.usedCredits = try? container.decode(Int.self, forKey: .usedCredits)
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
        return Double(usedCredits) / 100.0
    }

    var limitDollars: Double? {
        guard let monthlyLimit else { return nil }
        return Double(monthlyLimit) / 100.0
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
