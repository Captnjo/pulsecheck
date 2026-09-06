import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "TokenRefreshService")

struct OAuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int  // seconds

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

extension OAuthTokenResponse {
    func toCredentials(preservingScopes scopes: [String]) -> ClaudeOAuthCredentials {
        let expiresAtMs = Int64(Date().timeIntervalSince1970 * 1000) + Int64(expiresIn * 1000)
        return ClaudeOAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAtMs,
            scopes: scopes,
            subscriptionType: nil,
            rateLimitTier: nil
        )
    }
}

actor TokenRefreshService {
    private static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    private static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private var refreshTask: Task<ClaudeOAuthCredentials, Error>?
    private var refreshTaskToken: String?

    /// Deduplicates concurrent refreshes for the same refresh token. Keyed by token:
    /// a caller with a different token must never receive an in-flight task's result.
    func refresh(using refreshToken: String, preservingScopes scopes: [String]) async throws -> ClaudeOAuthCredentials {
        if let existing = refreshTask, refreshTaskToken == refreshToken {
            return try await existing.value
        }
        refreshTaskToken = refreshToken
        let task = Task<ClaudeOAuthCredentials, Error> {
            try await performRefresh(refreshToken: refreshToken, scopes: scopes)
        }
        refreshTask = task
        defer {
            if refreshTaskToken == refreshToken {
                refreshTask = nil
                refreshTaskToken = nil
            }
        }
        return try await task.value
    }

    /// A definitive refresh rejection means the lineage is dead (OAuth
    /// invalid_grant): 400/401 from the token endpoint. Anything else — 429,
    /// 5xx, network, non-HTTP — is transient and must NOT cost us the shadow
    /// lineage (the Sept-4 storm deleted it on a mere 429; never again).
    static func isDefinitiveRefreshRejection(_ error: Error) -> Bool {
        if case AppError.tokenRefreshFailed(let status, _) = error {
            return status == 400 || status == 401
        }
        return false
    }

    /// Percent-encodes a value for an application/x-www-form-urlencoded body.
    /// Internal (not private) so unit tests can cover it.
    static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func performRefresh(refreshToken: String, scopes: [String]) async throws -> ClaudeOAuthCredentials {
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&refresh_token=\(Self.formEncode(refreshToken))&client_id=\(Self.formEncode(Self.clientID))"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Token refresh received non-HTTP response")
            throw AppError.tokenRefreshFailed(0, "non-HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            let credentials = tokenResponse.toCredentials(preservingScopes: scopes)
            logger.info("Token refresh succeeded; new token expires in \(tokenResponse.expiresIn)s")
            return credentials
        default:
            let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
            logger.error("Token refresh failed with HTTP \(httpResponse.statusCode): \(snippet)")
            throw AppError.tokenRefreshFailed(httpResponse.statusCode, snippet)
        }
    }
}
