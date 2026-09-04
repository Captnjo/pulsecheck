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

    /// Percent-scale normalization: the API's convention is undocumented and has
    /// wobbled (0–100 vs 0–1). If every value in the payload is ≤ 1, treat the
    /// payload as fractions and rescale — mirroring Omarchy's scanner heuristic.
    /// `utilization` remains the RAW decoded value; read it via `displayPercent`.
    func normalized() -> UsageResponse {
        let raw: [Double?] = [
            fiveHour?.utilization, sevenDay?.utilization, sevenDayOauthApps?.utilization,
            sevenDayOpus?.utilization, sevenDaySonnet?.utilization, sevenDayCowork?.utilization,
            iguanaNecktie?.utilization,
        ].map { $0.flatMap { Double($0) } }
        let values = raw.compactMap { $0 }
        guard !values.isEmpty, values.allSatisfy({ $0 <= 1.0 }) else { return self }

        func scaled(_ p: UsagePeriod?) -> UsagePeriod? {
            guard let p else { return nil }
            return UsagePeriod(utilization: p.utilization * 100, resetsAt: p.resetsAt)
        }
        return UsageResponse(
            fiveHour: scaled(fiveHour),
            sevenDay: scaled(sevenDay),
            sevenDayOauthApps: scaled(sevenDayOauthApps),
            sevenDayOpus: scaled(sevenDayOpus),
            sevenDaySonnet: scaled(sevenDaySonnet),
            sevenDayCowork: scaled(sevenDayCowork),
            iguanaNecktie: scaled(iguanaNecktie),
            extraUsage: extraUsage
        )
    }

    /// Weekly bucket that isolates Claude Code usage from other Anthropic usage
    /// (the generic seven_day bucket includes everything).
    var effectiveSevenDay: UsagePeriod? { sevenDayOauthApps ?? sevenDay }
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

/// Errors, classified by what the app should DO next — the Omarchy distinction:
/// a transport failure reached no server (retry soon, the route may be back),
/// while a server rejection means stop pestering and wait.
enum UsageFetchOutcome {
    case success(UsageResponse)
    case transportDown(AppError)          // no server reached — retry sooner
    case serverRejected(AppError)         // 401/429/5xx — respect backoff
}
