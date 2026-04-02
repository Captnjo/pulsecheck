import Foundation

struct UsageResponse: Decodable {
    let fiveHour: UsagePeriod?
    let sevenDay: UsagePeriod?
    let sevenDayOauthApps: UsagePeriod?
    let sevenDayOpus: UsagePeriod?
    let sevenDaySonnet: UsagePeriod?
    let sevenDayCowork: UsagePeriod?
    let iguanaNecktie: UsagePeriod?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayCowork = "seven_day_cowork"
        case iguanaNecktie = "iguana_necktie"
        case extraUsage = "extra_usage"
    }
}

struct UsagePeriod: Decodable {
    let utilization: Double  // PERCENTAGE 0-100. e.g. 51.0 = 51%. Do NOT multiply by 100.
    let resetsAt: String     // ISO 8601 e.g. "2026-04-02T09:00:00.823692+00:00"

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var displayString: String {
        return "\(Int(utilization.rounded()))%"
    }
}

struct ExtraUsage: Decodable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }
}
