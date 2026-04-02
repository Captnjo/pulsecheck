import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "KeychainService")

struct KeychainWrapper: Codable {
    let claudeAiOauth: ClaudeOAuthCredentials
}

struct ClaudeOAuthCredentials: Codable {
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
    static let shadowServiceName = "PulseCheck-claude-credentials"

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

    func readShadowCredentials() throws -> ClaudeOAuthCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.shadowServiceName,
            kSecAttrAccount as String: "pulsecheck",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw AppError.keychainDataMalformed
            }
            let wrapper = try JSONDecoder().decode(KeychainWrapper.self, from: data)
            logger.info("Shadow Keychain credentials loaded; expired=\(wrapper.claudeAiOauth.isExpired)")
            return wrapper.claudeAiOauth
        case errSecItemNotFound:
            throw AppError.keychainItemNotFound
        default:
            throw AppError.keychainReadFailed(status)
        }
    }

    func writeShadowCredentials(_ credentials: ClaudeOAuthCredentials) throws {
        let data = try JSONEncoder().encode(KeychainWrapper(claudeAiOauth: credentials))
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.shadowServiceName,
            kSecAttrAccount as String: "pulsecheck"
        ]
        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw AppError.keychainWriteFailed(updateStatus)
            }
        } else if addStatus != errSecSuccess {
            throw AppError.keychainWriteFailed(addStatus)
        }
        logger.info("Shadow Keychain credentials written successfully")
    }

    func deleteShadowCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.shadowServiceName,
            kSecAttrAccount as String: "pulsecheck"
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.info("Shadow Keychain delete returned status: \(status)")
        } else {
            logger.info("Shadow Keychain credentials deleted")
        }
    }
}
