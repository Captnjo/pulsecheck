import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "CredentialsService")

enum CredentialSource: Equatable {
    /// Claude Code's own keychain item. Its refresh token belongs to Claude Code —
    /// PulseCheck must NEVER use it (using it rotates it and logs Claude Code out).
    case claudeCode
    /// Credentials PulseCheck obtained through its own refresh calls.
    /// The refresh token is ours to consume.
    case shadow
}

struct CredentialSet {
    let credentials: ClaudeOAuthCredentials
    let source: CredentialSource
}

struct CredentialsService {
    private let keychain = KeychainService()

    func loadCredentials() async -> Result<CredentialSet, AppError> {
        // Shadow-first: prefer PulseCheck's own refreshed credentials. While the
        // shadow is valid we deliberately do NOT read Claude Code's keychain item —
        // every read risks a Keychain access prompt, and our own token working is
        // proof we don't need Claude Code's. Claude's item is consulted only when
        // the shadow is missing or expired (below) or on a 401 (UsageStore).
        if let shadow = try? keychain.readShadowCredentials() {
            if !shadow.isExpired {
                return .success(CredentialSet(credentials: shadow, source: .shadow))
            }
            // Shadow expired: before refreshing, see if Claude Code holds newer
            // credentials (re-auth or its own refresh). Compared on expiresAt
            // because a refresh-token mismatch alone can't tell "Claude Code is
            // fresher" apart from "our shadow is fresher".
            if let primary = try? keychain.readClaudeCredentials(),
               primary.expiresAt > shadow.expiresAt {
                keychain.deleteShadowCredentials()
                logger.info("Claude Code has newer credentials — adopting them, discarding shadow")
                return .success(CredentialSet(credentials: primary, source: .claudeCode))
            }
            logger.info("Shadow credentials expired — returning for refresh attempt")
            return .success(CredentialSet(credentials: shadow, source: .shadow))
        }

        // No shadow — read from Claude Code's keychain item
        do {
            let credentials = try keychain.readClaudeCredentials()
            logger.info("Credentials loaded from Claude Code Keychain")
            return .success(CredentialSet(credentials: credentials, source: .claudeCode))
        } catch let appError as AppError {
            logger.error("Keychain read error: \(appError.localizedDescription)")
            return .failure(appError)
        } catch {
            logger.error("Keychain read error: \(error.localizedDescription)")
            return .failure(.keychainItemNotFound)
        }
    }
}
