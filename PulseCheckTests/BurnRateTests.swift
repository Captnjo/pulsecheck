import XCTest
@testable import PulseCheck

final class BurnRateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_500_000)

    private func date(_ minutesAgo: Double) -> Date {
        now.addingTimeInterval(-minutesAgo * 60)
    }

    // MARK: - Recording

    func testRecordKeepsRollingWindow() {
        var model = BurnRateModel()
        for i in 0..<20 {
            model.record(Double(i), at: now.addingTimeInterval(Double(i) * 60))
        }
        XCTAssertEqual(model.samples.count, BurnRateModel.maxSamples)
        XCTAssertEqual(model.samples.first?.utilization, 8)  // last 12 of 0..19
    }

    func testRecordIgnoresRapidDuplicates() {
        var model = BurnRateModel()
        model.record(50, at: now)
        model.record(50, at: now.addingTimeInterval(5))
        XCTAssertEqual(model.samples.count, 1)
        model.record(51, at: now.addingTimeInterval(10))
        XCTAssertEqual(model.samples.count, 2)
    }

    // MARK: - Rate

    func testRateNeedsFiveMinutesOfSpan() {
        var model = BurnRateModel()
        model.record(10, at: now)
        model.record(20, at: now.addingTimeInterval(3 * 60))
        XCTAssertNil(model.percentPerMinute, "3-minute span is too short to trust")
    }

    func testRateComputesPercentPerMinute() {
        var model = BurnRateModel()
        model.record(10, at: date(10))
        model.record(20, at: now)  // +10% over 10 minutes
        XCTAssertEqual(model.percentPerMinute ?? 0, 1.0, accuracy: 0.001)
    }

    // MARK: - Projection

    func testProjectionExtrapolatesToReset() {
        var model = BurnRateModel()
        model.record(10, at: date(30))
        model.record(25, at: now)  // 15% over 30 min = 0.5%/min
        let reset = now.addingTimeInterval(2 * 3600)  // 2h to reset
        let projected = model.projectedPercentAtReset(now: now, resetAt: reset, current: 25)
        XCTAssertEqual(projected ?? 0, 25 + 60, accuracy: 0.5)  // 0.5 * 120min
    }

    func testProjectionCapsAt100() {
        var model = BurnRateModel()
        model.record(50, at: date(30))
        model.record(65, at: now)  // 0.5%/min
        let reset = now.addingTimeInterval(4 * 3600)  // 4h — would exceed 100
        let projected = model.projectedPercentAtReset(now: now, resetAt: reset, current: 65)
        XCTAssertEqual(projected, 100)
    }

    func testProjectionNilWhenFalling() {
        var model = BurnRateModel()
        model.record(60, at: date(10))
        model.record(40, at: now)  // draining, no risk
        XCTAssertNil(model.projectedPercentAtReset(now: now, resetAt: now.addingTimeInterval(3600), current: 40))
        XCTAssertNil(model.minutesUntilFull(now: now, current: 40))
    }

    func testMinutesUntilFull() {
        var model = BurnRateModel()
        model.record(80, at: date(10))
        model.record(85, at: now)  // 0.5%/min, 15% left → 30 min
        let minutes = model.minutesUntilFull(now: now, current: 85)
        XCTAssertEqual(minutes ?? 0, 30, accuracy: 0.5)
    }

    // MARK: - Severity buckets

    func testSeverityBuckets() {
        XCTAssertEqual(UsageSeverity.forPercent(49), .normal)
        XCTAssertEqual(UsageSeverity.forPercent(50), .elevated)
        XCTAssertEqual(UsageSeverity.forPercent(79), .elevated)
        XCTAssertEqual(UsageSeverity.forPercent(80), .high)
    }

    // MARK: - Percent-scale normalization

    private func period(_ utilization: Double) -> UsagePeriod {
        try! JSONDecoder().decode(
            UsagePeriod.self,
            from: Data(#"{"utilization":\#(utilization),"resets_at":"2026-09-04T09:00:00+00:00"}"#.utf8)
        )
    }

    func testNormalizationRescalesFractionPayload() {
        let response = UsageResponse(
            fiveHour: period(0.51), sevenDay: period(0.12), sevenDayOauthApps: nil,
            sevenDayOpus: nil, sevenDaySonnet: nil, sevenDayCowork: nil,
            iguanaNecktie: nil, extraUsage: nil
        )
        let normalized = response.normalized()
        XCTAssertEqual(normalized.fiveHour?.utilization ?? -1, 51, accuracy: 0.001)
    }

    func testNormalizationLeavesPercentPayloadAlone() {
        let response = UsageResponse(
            fiveHour: period(51), sevenDay: period(12), sevenDayOauthApps: nil,
            sevenDayOpus: nil, sevenDaySonnet: nil, sevenDayCowork: nil,
            iguanaNecktie: nil, extraUsage: nil
        )
        let normalized = response.normalized()
        XCTAssertEqual(normalized.fiveHour?.utilization ?? -1, 51, accuracy: 0.001)
    }

    func testOauthAppsPreferredForWeekly() {
        let response = UsageResponse(
            fiveHour: nil,
            sevenDay: period(90),          // generic bucket (all Anthropic usage)
            sevenDayOauthApps: period(42), // Claude Code only
            sevenDayOpus: nil, sevenDaySonnet: nil, sevenDayCowork: nil,
            iguanaNecktie: nil, extraUsage: nil
        )
        XCTAssertEqual(response.effectiveSevenDay?.utilization ?? -1, 42, accuracy: 0.001)
    }
}
