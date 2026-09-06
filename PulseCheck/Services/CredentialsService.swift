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
        // shadow is valid we deliberately do NOT read Claude Code's stores —
        // every keychain read risks a prompt, and our own token working is proof
        // we don't need theirs. Claude Code's stores are consulted only when the
        // shadow is missing or expired (below) or on a 401 (UsageStore).
        if let shadow = try? keychain.readShadowCredentials() {
            if !shadow.isExpired {
                return .success(CredentialSet(credentials: shadow, source: .shadow))
            }
            // Shadow expired: before refreshing, see if Claude Code holds newer
            // credentials (re-auth or its own refresh) in either of its stores.
            if let primary = freshestClaudeCodeCredentials(), primary.expiresAt > shadow.expiresAt {
                keychain.deleteShadowCredentials()
                logger.info("Claude Code has newer credentials — adopting them, discarding shadow")
                return .success(CredentialSet(credentials: primary, source: .claudeCode))
            }
            logger.info("Shadow credentials expired — returning for refresh attempt")
            return .success(CredentialSet(credentials: shadow, source: .shadow))
        }

        // No shadow — read Claude Code's stores (keychain item and/or credentials
        // file; whichever is fresher). On 2.x builds the keychain item can be a
        // fossil while the file is live, or vice versa.
        if let primary = freshestClaudeCodeCredentials() {
            logger.info("Credentials loaded from Claude Code (keychain/file, freshest by expiry)")
            return .success(CredentialSet(credentials: primary, source: .claudeCode))
        }
        logger.error("No Claude Code credentials available in keychain or file")
        return .failure(.keychainItemNotFound)
    }

    /// Freshest of Claude Code's two persistent stores by expiresAt. Both are
    /// read-only; the refresh-token safety rule applies to either source.
    private func freshestClaudeCodeCredentials() -> ClaudeOAuthCredentials? {
        let keychainCreds = try? keychain.readClaudeCredentials()
        let fileCreds = try? keychain.readFileCredentials()
        switch (keychainCreds, fileCreds) {
        case let (k?, f?):
            return k.expiresAt >= f.expiresAt ? k : f
        case let (k?, nil):
            return k
        case let (nil, f?):
            return f
        default:
            return nil
        }
    }
}
