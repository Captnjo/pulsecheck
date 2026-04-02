import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "CredentialsService")

struct CredentialsService {
    private let keychain = KeychainService()

    func loadCredentials() async -> Result<ClaudeOAuthCredentials, AppError> {
        // Shadow-first: prefer PulseCheck's own refreshed credentials
        if let shadow = try? keychain.readShadowCredentials() {
            // Check if user re-authenticated via Claude Code
            if let primary = try? keychain.readClaudeCredentials(),
               shadow.refreshToken != primary.refreshToken {
                // User ran `claude auth login` — discard stale shadow
                keychain.deleteShadowCredentials()
                logger.info("User re-authenticated via Claude Code — discarding shadow credentials")
                return .success(primary)
            }
            if !shadow.isExpired {
                logger.info("Using shadow credentials (not expired)")
                return .success(shadow)
            }
            // Shadow exists but is expired — return it anyway so caller has refreshToken
            logger.info("Shadow credentials expired — returning for refresh attempt")
            return .success(shadow)
        }

        // No shadow — read from Claude Code's Keychain item
        do {
            let credentials = try keychain.readClaudeCredentials()
            logger.info("Credentials loaded from Claude Code Keychain")
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
