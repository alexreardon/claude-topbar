import Foundation

struct UsageResponse: Codable, Sendable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDaySonnet: UsageBucket?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
    }
}

struct UsageBucket: Codable, Sendable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
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
        Self.isoFormatter.date(from: resetsAt) ?? Self.isoFormatterNoFrac.date(from: resetsAt)
    }

    /// utilization comes from the API as 0-100 (already a percentage)
    var percentage: Int {
        Int(utilization.rounded())
    }

    /// Normalized to 0.0-1.0 for progress bars
    var fraction: Double {
        min(utilization / 100.0, 1.0)
    }
}

struct Organization: Codable, Sendable {
    let uuid: String
    let name: String?
}
