import XCTest
@testable import PulseCheck

final class CredentialLogicTests: XCTestCase {

    // MARK: - Form encoding (S2)

    func testFormEncodingLeavesUnreservedCharactersIntact() {
        XCTAssertEqual(TokenRefreshService.formEncode("abcXYZ0123-._~"), "abcXYZ0123-._~")
    }

    func testFormEncodingEscapesReservedCharacters() {
        XCTAssertEqual(TokenRefreshService.formEncode("a+b&c=d%e/f"), "a%2Bb%26c%3Dd%25e%2Ff")
    }

    func testFormEncodingEscapesSpaceAsPercent20() {
        XCTAssertEqual(TokenRefreshService.formEncode("a b"), "a%20b")
    }

    // MARK: - Expiry math

    func testExpiredCredentialsDetected() {
        let pastMs = Int64(Date().addingTimeInterval(-60).timeIntervalSince1970 * 1000)
        XCTAssertTrue(makeCreds(expiresAtMs: pastMs).isExpired)
    }

    func testFutureCredentialsNotExpired() {
        let futureMs = Int64(Date().addingTimeInterval(3_600).timeIntervalSince1970 * 1000)
        XCTAssertFalse(makeCreds(expiresAtMs: futureMs).isExpired)
    }

    // MARK: - Decoding

    func testOAuthTokenResponseDecoding() throws {
        let json = #"{"access_token":"at","refresh_token":"rt","expires_in":3600}"#
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.accessToken, "at")
        XCTAssertEqual(response.refreshToken, "rt")
        XCTAssertEqual(response.expiresIn, 3600)
    }

    func testOAuthTokenResponseToCredentialsPreservesScopesAndExpiry() throws {
        let json = #"{"access_token":"at","refresh_token":"rt","expires_in":3600}"#
        let response = try JSONDecoder().decode(OAuthTokenResponse.self, from: Data(json.utf8))
        let creds = response.toCredentials(preservingScopes: ["user:profile"])
        XCTAssertEqual(creds.accessToken, "at")
        XCTAssertEqual(creds.refreshToken, "rt")
        XCTAssertEqual(creds.scopes, ["user:profile"])
        XCTAssertFalse(creds.isExpired)
    }

    func testKeychainWrapperDecodingUsesClaudeAiOauthKey() throws {
        let json = """
        {"claudeAiOauth":{"accessToken":"at","refreshToken":"rt","expiresAt":9999999999999,
        "scopes":["user:profile"],"subscriptionType":"max","rateLimitTier":null}}
        """
        let wrapper = try JSONDecoder().decode(KeychainWrapper.self, from: Data(json.utf8))
        XCTAssertEqual(wrapper.claudeAiOauth.accessToken, "at")
        XCTAssertEqual(wrapper.claudeAiOauth.refreshToken, "rt")
        XCTAssertEqual(wrapper.claudeAiOauth.subscriptionType, "max")
        XCTAssertNil(wrapper.claudeAiOauth.rateLimitTier)
    }

    func testUsageResponseDecodingFullPayload() throws {
        let json = """
        {"five_hour":{"utilization":51.4,"resets_at":"2026-09-04T09:00:00.823692+00:00"},
         "seven_day":{"utilization":12.0,"resets_at":"2026-09-08T09:00:00+00:00"},
         "extra_usage":{"is_enabled":false}}
        """
        let usage = try JSONDecoder().decode(UsageResponse.self, from: Data(json.utf8))
        XCTAssertEqual(usage.fiveHour?.utilization ?? -1, 51.4, accuracy: 0.001)
        XCTAssertEqual(usage.sevenDay?.displayString, "12%")
        XCTAssertNil(usage.sevenDayOauthApps)
        XCTAssertNil(usage.sevenDayOpus)
        XCTAssertEqual(usage.extraUsage?.isEnabled, false)
        XCTAssertNil(usage.extraUsage?.monthlyLimit)
    }

    func testUsageResponseDecodingAbsentPeriods() throws {
        let json = #"{"five_hour":null}"#
        let usage = try JSONDecoder().decode(UsageResponse.self, from: Data(json.utf8))
        XCTAssertNil(usage.fiveHour)
        XCTAssertNil(usage.sevenDay)
    }

    // MARK: - Display string

    func testDisplayStringRoundsToNearestPercent() throws {
        XCTAssertEqual(try period(utilization: 50.4).displayString, "50%")
        XCTAssertEqual(try period(utilization: 50.5).displayString, "51%")
        XCTAssertEqual(try period(utilization: 99.6).displayString, "100%")
    }

    // MARK: - Credential selection (provenance rules)

    func testCredentialSetSourcesAreDistinct() {
        let creds = makeCreds(expiresAtMs: 0)
        XCTAssertNotEqual(CredentialSource.claudeCode, CredentialSource.shadow)
        let set = CredentialSet(credentials: creds, source: .shadow)
        XCTAssertEqual(set.source, .shadow)
    }

    // MARK: - Helpers

    private func makeCreds(expiresAtMs: Int64) -> ClaudeOAuthCredentials {
        ClaudeOAuthCredentials(
            accessToken: "at",
            refreshToken: "rt",
            expiresAt: expiresAtMs,
            scopes: ["user:profile"],
            subscriptionType: nil,
            rateLimitTier: nil
        )
    }

    private func period(utilization: Double) throws -> UsagePeriod {
        let json = #"{"utilization":\#(utilization),"resets_at":"2026-09-04T09:00:00+00:00"}"#
        return try JSONDecoder().decode(UsagePeriod.self, from: Data(json.utf8))
    }
}
