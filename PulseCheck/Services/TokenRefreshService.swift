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

    func refresh(using refreshToken: String, preservingScopes scopes: [String]) async throws -> ClaudeOAuthCredentials {
        if refreshTask == nil {
            refreshTask = Task {
                defer { refreshTask = nil }
                return try await performRefresh(refreshToken: refreshToken, scopes: scopes)
            }
        }
        return try await refreshTask!.value
    }

    private func performRefresh(refreshToken: String, scopes: [String]) async throws -> ClaudeOAuthCredentials {
        var request = URLRequest(url: Self.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(Self.clientID)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

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
