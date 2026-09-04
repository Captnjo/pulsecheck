import Foundation

/// Burn-rate projection over a rolling window of poll observations.
///
/// Each poll records (time, utilization). Fitting a line through the recent
/// samples gives a burn rate (%/minute) that projects when the window hits
/// 100% — the "will I make it" answer a raw percentage can't give.
struct BurnRateModel {
    struct Sample: Equatable {
        let time: Date
        let utilization: Double  // percent 0-100
    }

    private(set) var samples: [Sample] = []
    static let maxSamples = 12          // ~12 min of history at 60s polling
    static let minSpanMinutes = 5.0     // need ≥5 min of data before trusting a trend

    mutating func record(_ utilization: Double, at time: Date = Date()) {
        // Ignore exact duplicates (refetch of unchanged window)
        if let last = samples.last, last.utilization == utilization, time.timeIntervalSince(last.time) < 60 {
            return
        }
        samples.append(Sample(time: time, utilization: utilization))
        if samples.count > Self.maxSamples {
            samples.removeFirst(samples.count - Self.maxSamples)
        }
    }

    mutating func reset() {
        samples.removeAll()
    }

    /// Utilization change per minute through the sample span. Nil when there is
    /// too little data or the span is too short for a stable slope.
    var percentPerMinute: Double? {
        guard samples.count >= 2 else { return nil }
        let first = samples.first!, last = samples.last!
        let spanMinutes = last.time.timeIntervalSince(first.time) / 60.0
        guard spanMinutes >= Self.minSpanMinutes else { return nil }
        return (last.utilization - first.utilization) / spanMinutes
    }

    /// Projection: where utilization will be when the window resets.
    /// Considers only rising trends (falling utilization = window drained, no risk).
    /// - Parameters:
    ///   - now: current time
    ///   - resetAt: when the window resets
    ///   - current: latest utilization sample
    /// - Returns: projected percent at reset, or nil when unprovable.
    func projectedPercentAtReset(now: Date, resetAt: Date, current: Double) -> Double? {
        guard let rate = percentPerMinute, rate > 0.01 else { return nil }
        let minutesToReset = max(0, resetAt.timeIntervalSince(now) / 60.0)
        return min(100, current + rate * minutesToReset)
    }

    /// Time until the window hits 100% at the current burn rate. Nil when not
    /// rising or no trend yet.
    func minutesUntilFull(now: Date, current: Double) -> Double? {
        guard let rate = percentPerMinute, rate > 0.01, current < 100 else { return nil }
        return (100 - current) / rate
    }
}

/// Color buckets shared by bars and status captions.
enum UsageSeverity {
    case normal, elevated, high

    static func forPercent(_ percent: Double) -> UsageSeverity {
        switch percent {
        case ..<50: return .normal
        case ..<80: return .elevated
        default: return .high
        }
    }
}
