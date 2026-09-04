import XCTest
@testable import PulseCheck

final class ProviderLogicTests: XCTestCase {

    // MARK: - Codex decoding (wham/usage)

    func testCodexUsageDecodingFullPayload() throws {
        let json = """
        {"plan_type":"pro",
         "rate_limit":{"allowed":true,"limit_reached":false,
           "primary_window":{"used_percent":42,"limit_window_seconds":18000,"reset_after_seconds":3600,"reset_at":1788500000},
           "secondary_window":{"used_percent":13,"limit_window_seconds":604800,"reset_after_seconds":86400,"reset_at":1790000000}}}
        """
        let usage = try JSONDecoder().decode(CodexUsage.self, from: Data(json.utf8))
        XCTAssertEqual(usage.planType, "pro")
        XCTAssertEqual(usage.primaryWindow?.usedPercent, 42)
        XCTAssertEqual(usage.primaryWindow?.displayString, "42%")
        XCTAssertFalse(usage.primaryWindow?.isWeekly ?? true)
        XCTAssertEqual(usage.secondaryWindow?.usedPercent, 13)
        XCTAssertTrue(usage.secondaryWindow?.isWeekly ?? false)
    }

    func testCodexUsageDecodingEmptyRateLimit() throws {
        let json = #"{"plan_type":"free","rate_limit":{"allowed":true,"limit_reached":false}}"#
        let usage = try JSONDecoder().decode(CodexUsage.self, from: Data(json.utf8))
        XCTAssertNil(usage.primaryWindow)
        XCTAssertNil(usage.secondaryWindow)
    }

    // MARK: - OpenRouter decoding (/api/v1/key)

    func testOpenRouterKeyInfoDecodingWithLimit() throws {
        let json = """
        {"data":{"label":"opencode","limit":50.0,"limit_remaining":30.5,
         "usage":120.5,"usage_daily":12.4,"usage_weekly":38.2,"usage_monthly":90.1,
         "is_free_tier":false}}
        """
        let info = try JSONDecoder().decode(OpenRouterKeyInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.usageDaily, 12.4, accuracy: 0.001)
        XCTAssertEqual(info.usageWeekly, 38.2, accuracy: 0.001)
        XCTAssertEqual(info.limitRemaining ?? -1, 30.5, accuracy: 0.001)
        let utilization = try XCTUnwrap(info.limitUtilization)
        XCTAssertEqual(utilization, 39.0, accuracy: 0.001)
    }

    func testOpenRouterKeyInfoDecodingUnlimitedKey() throws {
        let json = """
        {"data":{"label":"opencode","limit":null,"limit_remaining":null,
         "usage":10.0,"usage_daily":1.0,"usage_weekly":5.0,"usage_monthly":9.0,
         "is_free_tier":false}}
        """
        let info = try JSONDecoder().decode(OpenRouterKeyInfo.self, from: Data(json.utf8))
        XCTAssertNil(info.limitUtilization)
    }

    func testOpenRouterLimitUtilizationClampsToHundred() throws {
        let json = """
        {"data":{"limit":10.0,"limit_remaining":-5.0,"usage":15.0,"usage_daily":0,
        "usage_weekly":0,"usage_monthly":0,"is_free_tier":false}}
        """
        let info = try JSONDecoder().decode(OpenRouterKeyInfo.self, from: Data(json.utf8))
        let utilization = try XCTUnwrap(info.limitUtilization)
        XCTAssertEqual(utilization, 100.0, accuracy: 0.001)
    }

    // MARK: - Worst-of menu bar title

    func testWorstOfPicksHighestUtilization() {
        XCTAssertEqual(
            WorstOf.title(claudeFiveHour: 51, codexPrimary: 87, openRouterLimit: 40),
            "87%"
        )
    }

    func testWorstOfIgnoresNilProviders() {
        XCTAssertEqual(
            WorstOf.title(claudeFiveHour: nil, codexPrimary: 25, openRouterLimit: nil),
            "25%"
        )
    }

    func testWorstOfWithNoDataShowsPlaceholder() {
        XCTAssertEqual(
            WorstOf.title(claudeFiveHour: nil, codexPrimary: nil, openRouterLimit: nil),
            "—%"
        )
    }

    func testWorstOfIncludesOpenRouterOnlyWithLimit() {
        XCTAssertEqual(
            WorstOf.title(claudeFiveHour: 10, codexPrimary: 10, openRouterLimit: nil),
            "10%"
        )
    }
}
