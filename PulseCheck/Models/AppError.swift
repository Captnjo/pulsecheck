import Foundation

enum AppError: Error, LocalizedError {
    case keychainItemNotFound
    case keychainDataMalformed
    case keychainReadFailed(OSStatus)
    case apiUnauthorized
    case apiError(Int, String)  // statusCode, body snippet
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .keychainItemNotFound:       return "Keychain item not found"
        case .keychainDataMalformed:      return "Keychain data malformed"
        case .keychainReadFailed(let s):  return "Keychain read failed (OSStatus \(s))"
        case .apiUnauthorized:            return "Auth expired — run claude auth login"
        case .apiError(let code, _):      return "API error \(code)"
        case .networkError:               return "Network error"
        }
    }
}
