import Foundation

enum AppError: Error, LocalizedError {
    case keychainItemNotFound
    case keychainDataMalformed
    case keychainReadFailed(OSStatus)
    case apiUnauthorized
    case apiError(Int, String)  // statusCode, body snippet
    case rateLimited(retryAfterSeconds: Int?)  // 429, with Retry-After when the server sends one
    case networkError(Error)
    case tokenRefreshFailed(Int, String)  // HTTP status code, body snippet
    case keychainWriteFailed(OSStatus)
    case providerNotAuthenticated(String)  // provider display name — not logged in / not installed
    case providerUnavailable(String)       // provider display name — nothing monitorable

    var errorDescription: String? {
        switch self {
        case .keychainItemNotFound:               return "Keychain item not found"
        case .keychainDataMalformed:              return "Keychain data malformed"
        case .keychainReadFailed(let s):          return "Keychain read failed (OSStatus \(s))"
        case .apiUnauthorized:                    return "Auth expired — run the CLI to refresh"
        case .apiError(let code, _):              return "API error \(code)"
        case .rateLimited:                        return "Rate limited — retrying with backoff"
        case .networkError:                       return "Network error"
        case .tokenRefreshFailed(let code, _):   return "Token refresh failed (HTTP \(code))"
        case .keychainWriteFailed(let s):         return "Keychain write failed (OSStatus \(s))"
        case .providerNotAuthenticated(let p):    return "\(p) not logged in"
        case .providerUnavailable(let p):         return "\(p) not detected"
        }
    }
}
