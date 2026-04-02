import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "com.jo.ClaudeUsage", category: "KeychainService")

struct KeychainWrapper: Decodable {
    let claudeAiOauth: ClaudeOAuthCredentials
}

struct ClaudeOAuthCredentials: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64        // milliseconds since epoch — divide by 1000 for Date
    let scopes: [String]
    let subscriptionType: String?
    let rateLimitTier: String?

    var isExpired: Bool {
        let expiryDate = Date(timeIntervalSince1970: TimeInterval(expiresAt) / 1000.0)
        return expiryDate < Date()
    }
}

struct KeychainService {
    static let serviceName = "Claude Code-credentials"

    func readClaudeCredentials() throws -> ClaudeOAuthCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
            // Do NOT include kSecAttrAccount — avoids hardcoding username
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw AppError.keychainDataMalformed
            }
            // MUST decode through KeychainWrapper — actual JSON is { "claudeAiOauth": { ... } }
            let wrapper = try JSONDecoder().decode(KeychainWrapper.self, from: data)
            logger.info("Keychain credentials loaded; expired=\(wrapper.claudeAiOauth.isExpired)")
            return wrapper.claudeAiOauth
        case errSecItemNotFound:
            throw AppError.keychainItemNotFound
        default:
            throw AppError.keychainReadFailed(status)
        }
    }
}
