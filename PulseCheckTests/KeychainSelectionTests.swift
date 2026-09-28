import XCTest
import Security
@testable import PulseCheck

final class KeychainSelectionTests: XCTestCase {

    func testReadsDuplicatePasswordsIndividuallyAndSelectsFreshest() throws {
        let fossil = try JSONEncoder().encode(KeychainWrapper(claudeAiOauth: makeCredentials(accessToken: "fossil", expiresAt: 1)))
        let live = try JSONEncoder().encode(KeychainWrapper(claudeAiOauth: makeCredentials(accessToken: "live", expiresAt: 2)))
        let service = mockService(items: [(errSecSuccess, fossil), (errSecSuccess, live)])
        XCTAssertEqual(try service.readClaudeCredentials().accessToken, "live")
    }

    func testSkipsUnreadableAndMalformedDuplicatesWhenOneIsValid() throws {
        let live = try JSONEncoder().encode(KeychainWrapper(claudeAiOauth: makeCredentials(accessToken: "live", expiresAt: 2)))
        let service = mockService(items: [(errSecAuthFailed, nil), (errSecSuccess, Data("{}".utf8)), (errSecSuccess, live)])
        XCTAssertEqual(try service.readClaudeCredentials().accessToken, "live")
    }

    func testPreservesReadFailureWhenNoDuplicateCanBeDecoded() {
        let service = mockService(items: [(errSecAuthFailed, nil), (errSecSuccess, Data("{}".utf8))])
        XCTAssertThrowsError(try service.readClaudeCredentials()) { error in
            guard case AppError.keychainReadFailed(let status) = error else { return XCTFail("Expected read failure") }
            XCTAssertEqual(status, errSecAuthFailed)
        }
    }

    func testReportsMalformedDataWhenAllReadableItemsAreMalformed() {
        let service = mockService(items: [(errSecSuccess, Data("{}".utf8))])
        XCTAssertThrowsError(try service.readClaudeCredentials()) { error in
            guard case AppError.keychainDataMalformed = error else { return XCTFail("Expected malformed data") }
        }
    }

    func testReportsMissingItems() {
        let service = mockService(items: [])
        XCTAssertThrowsError(try service.readClaudeCredentials()) { error in
            guard case AppError.keychainItemNotFound = error else { return XCTFail("Expected missing item") }
        }
    }

    func testReportsMissingItemsWhenTheyDisappearAfterEnumeration() {
        let service = mockService(items: [(errSecItemNotFound, nil)])
        XCTAssertThrowsError(try service.readClaudeCredentials()) { error in
            guard case AppError.keychainItemNotFound = error else { return XCTFail("Expected missing item") }
        }
    }

    func testPreservesEnumerationReadFailure() {
        let service = KeychainService { _ in (errSecInteractionNotAllowed, nil) }
        XCTAssertThrowsError(try service.readClaudeCredentials()) { error in
            guard case AppError.keychainReadFailed(let status) = error else { return XCTFail("Expected read failure") }
            XCTAssertEqual(status, errSecInteractionNotAllowed)
        }
    }

    private func mockService(items: [(OSStatus, Data?)]) -> KeychainService {
        KeychainService { query in
            let query = query as! [String: Any]
            if query[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String {
                // Apple's password-query contract: returning data for every match
                // is unsupported and produces errSecParam, even for one item.
                if query[kSecReturnData as String] as? Bool == true { return (errSecParam, nil) }
                XCTAssertEqual(query[kSecReturnPersistentRef as String] as? Bool, true)
                guard !items.isEmpty else { return (errSecItemNotFound, nil) }
                return (errSecSuccess, items.indices.map { Data([UInt8($0)]) } as NSArray)
            }
            XCTAssertEqual(query[kSecMatchLimit as String] as? String, kSecMatchLimitOne as String)
            XCTAssertEqual(query[kSecReturnData as String] as? Bool, true)
            guard let ref = query[kSecValuePersistentRef as String] as? Data,
                  let index = ref.first, Int(index) < items.count else {
                XCTFail("Expected one of the enumerated persistent references")
                return (errSecParam, nil)
            }
            let (status, data) = items[Int(index)]
            return (status, data as NSData?)
        }
    }

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
