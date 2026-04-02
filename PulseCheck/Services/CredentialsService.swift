import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "CredentialsService")

struct CredentialsService {
    private let keychain = KeychainService()

    func loadCredentials() async -> Result<ClaudeOAuthCredentials, AppError> {
        do {
            let credentials = try keychain.readClaudeCredentials()
            logger.info("Credentials loaded from Keychain")
            return .success(credentials)
        } catch let appError as AppError {
            logger.error("Keychain read error: \(appError.localizedDescription)")
            return .failure(appError)
        } catch {
            logger.error("Keychain read error: \(error.localizedDescription)")
            return .failure(.keychainItemNotFound)
        }
    }
}
