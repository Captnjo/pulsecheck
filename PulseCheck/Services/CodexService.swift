import Foundation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "CodexService")

/// Codex CLI credentials from ~/.codex/auth.json.
/// READ-ONLY by design: codex's refresh token belongs to codex — PulseCheck never
/// uses it, never rotates it, never writes this file. If the access token is stale,
/// PulseCheck shows a "run codex" state and re-syncs after codex refreshes itself.
struct CodexCredentials {
    let accessToken: String
    let accountId: String
    let lastRefresh: String?
}

enum CodexCredentialsError: Error {
    case notFound          // no auth.json — codex not installed / not logged in
    case wrongMode         // apikey mode — no ChatGPT usage windows to report
    case unreadable(String)
}

enum CodexCredentialsReader {
    static var authFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
    }

    static func load() -> Result<CodexCredentials, CodexCredentialsError> {
        guard FileManager.default.fileExists(atPath: authFileURL.path) else {
            return .failure(.notFound)
        }
        do {
            let raw = try Data(contentsOf: authFileURL)
            let obj = try JSONSerialization.jsonObject(with: raw) as? [String: Any] ?? [:]
            guard (obj["auth_mode"] as? String) == "chatgpt" else {
                return .failure(.wrongMode)
            }
            let tokens = obj["tokens"] as? [String: Any] ?? [:]
            guard let access = tokens["access_token"] as? String, !access.isEmpty,
                  let account = tokens["account_id"] as? String, !account.isEmpty else {
                return .failure(.unreadable("unreadable"))
            }
            return .success(CodexCredentials(
                accessToken: access,
                accountId: account,
                lastRefresh: obj["last_refresh"] as? String
            ))
        } catch {
            logger.error("Failed to read codex auth: \(error.localizedDescription)")
            return .failure(.unreadable("unreadable"))
        }
    }
}

struct CodexAPIClient {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetchUsage(credentials: CodexCredentials) async -> Result<CodexUsage, AppError> {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountId, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.apiError(0, "non-HTTP response"))
            }
            logger.info("Codex usage response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let usage = try JSONDecoder().decode(CodexUsage.self, from: data)
                return .success(usage)
            case 401, 403:
                // Token stale or revoked — codex will refresh on its next run.
                return .failure(.apiUnauthorized)
            default:
                let snippet = String(data: data.prefix(200), encoding: .utf8) ?? ""
                return .failure(.apiError(httpResponse.statusCode, snippet))
            }
        } catch let error as DecodingError {
            logger.error("Codex JSON decode error: \(error)")
            return .failure(.apiError(0, error.localizedDescription))
        } catch {
            logger.error("Codex network error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }
}
