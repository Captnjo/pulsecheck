import Foundation

/// Providers PulseCheck can monitor. Raw value is used as tab identity.
enum Provider: String, CaseIterable, Identifiable {
    case claude
    case codex
    case openRouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .openRouter: return "OpenRouter"
        }
    }
}

// MARK: - Codex (ChatGPT OAuth usage)

/// Response of GET https://chatgpt.com/backend-api/wham/usage
/// Mirrors openai/codex RateLimitStatusPayload / RateLimitStatusDetails / RateLimitWindowSnapshot.
struct CodexUsage: Decodable {
    struct Window: Decodable {
        let usedPercent: Int          // 0-100
        let limitWindowSeconds: Int   // e.g. 18000 = 5h, 604800 = 7d
        let resetAfterSeconds: Int
        let resetAt: Int              // unix seconds

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case limitWindowSeconds = "limit_window_seconds"
            case resetAfterSeconds = "reset_after_seconds"
            case resetAt = "reset_at"
        }

        var displayString: String {
            "\(Int(usedPercent))%"
        }

        var isWeekly: Bool { limitWindowSeconds >= 7 * 24 * 3600 }

        /// Label derived from the window's actual length, mirroring codex's own
        /// `get_limits_duration` (±5% tolerance) — OpenAI reassigns what primary/
        /// secondary mean per plan, so position must never imply a duration.
        var windowLabel: String {
            let minutes = Double(limitWindowSeconds) / 60.0
            func isApprox(_ expectedMinutes: Double) -> Bool {
                minutes >= expectedMinutes * 0.95 && minutes <= expectedMinutes * 1.05
            }
            let hour = 60.0, day = 24 * hour
            if isApprox(5 * hour) { return "5-hour window" }
            if isApprox(day) { return "Daily window" }
            if isApprox(7 * day) { return "Weekly window" }
            if isApprox(30 * day) { return "Monthly window" }
            if isApprox(365 * day) { return "Annual window" }
            // Unknown length — humanize the raw duration
            let days = limitWindowSeconds / 86400
            if days >= 1 { return "\(days)-day window" }
            let hours = limitWindowSeconds / 3600
            return "\(hours)-hour window"
        }

        /// Weekly windows get an absolute reset date; shorter ones get a countdown.
        var isWeeklyOrLonger: Bool { limitWindowSeconds >= 7 * 24 * 3600 }
    }

    struct RateLimit: Decodable {
        let allowed: Bool
        let limitReached: Bool
        let primaryWindow: Window?    // 5h window
        let secondaryWindow: Window?  // 7d window

        enum CodingKeys: String, CodingKey {
            case allowed
            case limitReached = "limit_reached"
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    let planType: String?
    let rateLimit: RateLimit?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
    }

    var primaryWindow: Window? { rateLimit?.primaryWindow }
    var secondaryWindow: Window? { rateLimit?.secondaryWindow }
}

// MARK: - OpenRouter (opencode provider)

/// Response of GET https://openrouter.ai/api/v1/key — dollar spend, not % windows.
struct OpenRouterKeyInfo: Decodable {
    struct KeyData: Decodable {
        let usageDaily: Double
        let usageWeekly: Double
        let usageMonthly: Double
        let limit: Double?            // per-key credit cap, nil = unlimited
        let limitRemaining: Double?

        enum CodingKeys: String, CodingKey {
            case usageDaily = "usage_daily"
            case usageWeekly = "usage_weekly"
            case usageMonthly = "usage_monthly"
            case limit
            case limitRemaining = "limit_remaining"
        }
    }

    let key: KeyData

    enum CodingKeys: String, CodingKey {
        case key = "data"
    }

    var usageDaily: Double { key.usageDaily }
    var usageWeekly: Double { key.usageWeekly }
    var usageMonthly: Double { key.usageMonthly }
    var limit: Double? { key.limit }
    var limitRemaining: Double? { key.limitRemaining }

    /// Percent of per-key limit consumed; nil when no per-key limit is set.
    var limitUtilization: Double? {
        guard let limit, limit > 0 else { return nil }
        let remaining = limitRemaining ?? 0
        return max(0, min(100, (limit - remaining) / limit * 100))
    }
}

/// Worst-of computation for the menu bar title: the most-constrained percentage
/// across providers. OpenRouter only contributes when a per-key limit is set.
enum WorstOf {
    static func title(claudeFiveHour: Double?, codexPrimary: Double?, openRouterLimit: Double?) -> String {
        let candidates = [claudeFiveHour, codexPrimary, openRouterLimit].compactMap { $0 }
        guard let worst = candidates.max() else { return "—%" }
        return "\(Int(worst.rounded()))%"
    }
}
