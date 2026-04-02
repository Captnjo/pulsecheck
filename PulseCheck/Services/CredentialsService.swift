import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "CredentialsService")

struct CredentialsService {
    private let keychain = KeychainService()

    func loadCredentials() async -> Result<ClaudeOAuthCredentials, AppError> {
        // Step 1: Try Keychain
        do {
            let credentials = try keychain.readClaudeCredentials()
            logger.info("Credentials loaded from Keychain")
            return .success(credentials)
        } catch AppError.keychainItemNotFound {
            logger.info("Keychain item absent — trying file fallback")
        } catch {
            logger.error("Keychain read error: \(error.localizedDescription)")
        }

        // Step 2: Try ~/.claude/.credentials.json
        do {
            let credentials = try readCredentialsFromFile()
            logger.info("Credentials loaded from file fallback")
            return .success(credentials)
        } catch AppError.credentialsFileNotFound {
            logger.info("Credentials file absent")
        } catch {
            logger.error("File credentials error: \(error.localizedDescription)")
        }

        // Step 3: Neither source available
        return .failure(AppError.keychainItemNotFound)
    }

    private func readCredentialsFromFile() throws -> ClaudeOAuthCredentials {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AppError.credentialsFileNotFound
        }
        let data = try Data(contentsOf: path)
        // Parse defensively: try wrapper first, then flat structure
        if let wrapper = try? JSONDecoder().decode(KeychainWrapper.self, from: data) {
            logger.info("File credentials parsed as wrapper structure")
            return wrapper.claudeAiOauth
        }
        logger.info("File credentials parsed as flat structure")
        return try JSONDecoder().decode(ClaudeOAuthCredentials.self, from: data)
    }
}
