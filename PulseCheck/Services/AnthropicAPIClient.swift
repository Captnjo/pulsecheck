import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "AnthropicAPIClient")

struct AnthropicAPIClient {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func fetchUsage(accessToken: String) async -> Result<UsageResponse, AppError> {
        var request = URLRequest(url: Self.usageURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            logger.info("API response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
                return .success(usage)
            case 401:
                return .failure(.apiUnauthorized)
            case 403:
                let bodySnippet = String(data: data.prefix(500), encoding: .utf8) ?? ""
                if bodySnippet.contains("scope") || bodySnippet.contains("user:profile") {
                    logger.warning("403 scope-loss detected — routing to apiUnauthorized")
                    return .failure(.apiUnauthorized)
                }
                return .failure(.apiError(403, String(data: data.prefix(200), encoding: .utf8) ?? ""))
            default:
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
                return .failure(.apiError(httpResponse.statusCode, snippet))
            }
        } catch let error as DecodingError {
            logger.error("JSON decode error: \(error)")
            return .failure(.apiError(0, error.localizedDescription))
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }
}
