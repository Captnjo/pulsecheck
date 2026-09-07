import XCTest
@testable import PulseCheck

final class KeychainSelectionTests: XCTestCase {

    func testFreshestSelectsLiveCredentialsOverFossilCredentials() {
        let fossil = makeCredentials(accessToken: "fossil", expiresAt: 1_779_000_000_000)
        let live = makeCredentials(accessToken: "live", expiresAt: 1_800_000_000_000)

        let freshest = KeychainService.freshest([fossil, live])

        XCTAssertEqual(freshest?.accessToken, "live")
    }

    func testFreshestReturnsOnlyCandidate() {
        let live = makeCredentials(accessToken: "live", expiresAt: 1_800_000_000_000)

        let freshest = KeychainService.freshest([live])

        XCTAssertEqual(freshest?.accessToken, "live")
    }

    func testFreshestReturnsNilForEmptyCandidates() {
        XCTAssertNil(KeychainService.freshest([]))
    }

    func testFreshestKeepsFirstCandidateWhenExpiryTies() {
        let first = makeCredentials(accessToken: "first", expiresAt: 1_800_000_000_000)
        let second = makeCredentials(accessToken: "second", expiresAt: 1_800_000_000_000)

        let freshest = KeychainService.freshest([first, second])

        XCTAssertEqual(freshest?.accessToken, "first")
    }

    private func makeCredentials(accessToken: String, expiresAt: Int64) -> ClaudeOAuthCredentials {
        ClaudeOAuthCredentials(
            accessToken: accessToken,
            refreshToken: "refresh-token",
            expiresAt: expiresAt,
            scopes: ["user:profile"],
            subscriptionType: nil,
            rateLimitTier: nil
        )
    }
}
