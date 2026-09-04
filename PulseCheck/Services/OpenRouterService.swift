import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "OpenRouterService")

/// OpenRouter API key stored by opencode at ~/.local/share/opencode/auth.json.
/// Read-only; the key belongs to opencode/OpenRouter and is never modified here.
struct OpenRouterCredentials {
    let apiKey: String
}

enum OpenRouterCredentialsError: Error {
    case notFound          // opencode not installed / never authed
    case noOpenRouterKey   // authed with other providers only
    case unreadable(String)
}

enum OpenRouterCredentialsReader {
    static var authFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/share/opencode/auth.json")
    }

    static func load() -> Result<OpenRouterCredentials, OpenRouterCredentialsError> {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return .failure(.notFound)
        }
        do {
            let raw = try Data(contentsOf: authFileURL)
            let obj = try JSONSerialization.jsonObject(with: raw) as? [String: Any] ?? [:]
            guard let entry = obj["openrouter"] as? [String: Any] else {
                return .failure(.noOpenRouterKey)
            }
            guard let key = entry["key"] as? String, !key.isEmpty else {
                return .failure(.noOpenRouterKey)
            }
            return .success(OpenRouterCredentials(apiKey: key))
        } catch {
            logger.error("Failed to read opencode auth: \(error.localizedDescription)")
            return .failure(.unreadable(error.localizedDescription))
        }
    }
}

struct OpenRouterAPIClient {
    private static let keyURL = URL(string: "https://openrouter.ai/api/v1/key")!

    func fetchKeyInfo(apiKey: String) async -> Result<OpenRouterKeyInfo, AppError> {
        var request = URLRequest(url: Self.keyURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.apiError(0, "non-HTTP response"))
            }
            logger.info("OpenRouter key response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let info = try JSONDecoder().decode(OpenRouterKeyInfo.self, from: data)
                return .success(info)
            case 401, 403:
                return .failure(.apiUnauthorized)
            default:
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
                return .failure(.apiError(httpResponse.statusCode, snippet))
            }
        } catch let error as DecodingError {
            logger.error("OpenRouter JSON decode error: \(error)")
            return .failure(.apiError(0, error.localizedDescription))
        } catch {
            logger.error("OpenRouter network error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }
}
