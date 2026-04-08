import Foundation

struct UsageResponse: Codable, Sendable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }
}

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

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    var resetsAtDate: Date? {
        guard let resetsAt else { return nil }
        return Self.isoFormatter.date(from: resetsAt) ?? Self.isoFormatterNoFrac.date(from: resetsAt)
    }

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
