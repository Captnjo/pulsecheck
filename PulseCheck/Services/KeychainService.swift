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
    typealias CopyMatching = @Sendable (CFDictionary) -> (OSStatus, AnyObject?)
    private let copyMatching: CopyMatching

    init(copyMatching: @escaping CopyMatching = { query in
        var result: AnyObject?
        let status = SecItemCopyMatching(query, &result)
        return (status, result)
    }) {
        self.copyMatching = copyMatching
    }

    static let serviceName = "Claude Code-credentials"
    static let shadowServiceName = "PulseCheck-claude-credentials"

    func readClaudeCredentials() throws -> ClaudeOAuthCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            // Password queries cannot combine ReturnData with MatchLimitAll.
            // Enumerate stable references, then read each item's data separately.
            kSecReturnPersistentRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
            // Do NOT include kSecAttrAccount — avoids hardcoding username
        ]
        let (status, result) = copyMatching(query as CFDictionary)
        logger.info("Claude Keychain read status=\(status, privacy: .public)")

        switch status {
        case errSecSuccess:
            guard let references = result as? [Data] else {
                throw AppError.keychainDataMalformed
            }
            guard !references.isEmpty else {
                throw AppError.keychainItemNotFound
            }
            logger.info("Claude Keychain reference count=\(references.count, privacy: .public)")
            // MUST decode through KeychainWrapper — actual JSON is { "claudeAiOauth": { ... } }
            let decoder = JSONDecoder()
            var candidates: [ClaudeOAuthCredentials] = []
            var readFailure: OSStatus?
            var malformed = false
            for reference in references {
                let itemQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecValuePersistentRef as String: reference,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                let (itemStatus, itemResult) = copyMatching(itemQuery as CFDictionary)
                guard itemStatus == errSecSuccess else {
                    logger.info("Claude Keychain item read status=\(itemStatus, privacy: .public)")
                    // An item can disappear between enumeration and reading.
                    if itemStatus != errSecItemNotFound, readFailure == nil {
                        readFailure = itemStatus
                    }
                    continue
                }
                guard let data = itemResult as? Data else {
                    malformed = true
                    continue
                }
                do {
                    candidates.append(try decoder.decode(KeychainWrapper.self, from: data).claudeAiOauth)
                } catch {
                    Self.logDecodingFailure(error)
                    malformed = true
                }
            }
            logger.info("Claude Keychain decoded candidate count=\(candidates.count, privacy: .public)")
            guard let credentials = Self.freshest(candidates) else {
                if let readFailure { throw AppError.keychainReadFailed(readFailure) }
                if malformed { throw AppError.keychainDataMalformed }
                throw AppError.keychainItemNotFound
            }
            logger.info("Keychain credentials loaded; expired=\(credentials.isExpired)")
            return credentials
        case errSecItemNotFound:
            throw AppError.keychainItemNotFound
        default:
            throw AppError.keychainReadFailed(status)
        }
    }

    /// Log only structural decoding metadata. Error descriptions can contain
    /// credential values and must never be passed to the logger.
    private static func logDecodingFailure(_ error: Error) {
        let category: String
        let codingPath: [any CodingKey]
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            category = "keyNotFound"
            codingPath = context.codingPath + [key]
        case DecodingError.valueNotFound(_, let context):
            category = "valueNotFound"
            codingPath = context.codingPath
        case DecodingError.typeMismatch(_, let context):
            category = "typeMismatch"
            codingPath = context.codingPath
        case DecodingError.dataCorrupted(let context):
            category = "dataCorrupted"
            codingPath = context.codingPath
        default:
            category = "other"
            codingPath = []
        }
        let path = codingPath.map(\.stringValue).joined(separator: ".")
        logger.error("Claude Keychain decode failed: category=\(category, privacy: .public), codingPath=\(path, privacy: .public)")
    }

    static func freshest(_ candidates: [ClaudeOAuthCredentials]) -> ClaudeOAuthCredentials? {
        guard var freshest = candidates.first else { return nil }
        for candidate in candidates.dropFirst() where candidate.expiresAt > freshest.expiresAt {
            freshest = candidate
        }
        return freshest
    }

    /// Claude Code's credentials file (~/.claude/.credentials.json), the store the
    /// CLI writes on Linux and newer macOS builds. Respects CLAUDE_CONFIG_DIR.
    static var credentialsFileURL: URL {
        let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
        let base: URL
        if let env, !env.isEmpty {
            base = URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        }
        return base.appendingPathComponent(".credentials.json")
    }

    /// Reads the credentials file. Accepts both the wrapped shape
    /// ({"claudeAiOauth": {...}}) and a bare credentials object.
    func readCredentialsFile(at url: URL) throws -> ClaudeOAuthCredentials {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let e as NSError where e.code == NSFileReadNoSuchFileError {
            throw AppError.keychainItemNotFound
        }
        if let wrapper = try? JSONDecoder().decode(KeychainWrapper.self, from: data) {
            return wrapper.claudeAiOauth
        }
        do {
            return try JSONDecoder().decode(ClaudeOAuthCredentials.self, from: data)
        } catch {
            throw AppError.keychainDataMalformed
        }
    }

    func readFileCredentials() throws -> ClaudeOAuthCredentials {
        try readCredentialsFile(at: Self.credentialsFileURL)
    }

    func readShadowCredentials() throws -> ClaudeOAuthCredentials {        let query: [String: Any] = [
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
        // Device-only + first-unlock: polls while the Mac is locked still succeed,
        // and the secret never leaves this machine via backups.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
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
