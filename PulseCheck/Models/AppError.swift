import Foundation

enum AppError: Error, LocalizedError {
    case keychainItemNotFound
    case keychainDataMalformed
    case keychainReadFailed(OSStatus)
    case credentialsFileNotFound
    case credentialsFileMalformed(Error)
    case apiUnauthorized
    case apiError(Int, String)  // statusCode, body snippet
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .keychainItemNotFound:       return "Keychain item not found"
        case .keychainDataMalformed:      return "Keychain data malformed"
        case .keychainReadFailed(let s):  return "Keychain read failed (OSStatus \(s))"
        case .credentialsFileNotFound:    return "~/.claude/.credentials.json not found"
        case .credentialsFileMalformed:   return "Credentials file JSON malformed"
        case .apiUnauthorized:            return "Auth expired — run claude auth login"
        case .apiError(let code, _):      return "API error \(code)"
        case .networkError:               return "Network error"
        }
    }
}
