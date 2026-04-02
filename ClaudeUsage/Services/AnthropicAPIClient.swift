import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.ClaudeUsage", category: "AnthropicAPIClient")

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

            // Log raw response for empirical verification (Phase 1 only)
            if let raw = String(data: data, encoding: .utf8) {
                logger.debug("Raw API response: \(raw)")
            }

            switch httpResponse.statusCode {
            case 200:
                let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
                return .success(usage)
            case 401:
                return .failure(.apiUnauthorized)
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
