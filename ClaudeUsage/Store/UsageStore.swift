import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.jo.ClaudeUsage", category: "UsageStore")

@Observable
@MainActor
class UsageStore {
    var credentials: ClaudeOAuthCredentials?
    var credentialError: AppError?
    var menuBarTitle: String = "—%"

    private let credentialsService = CredentialsService()

    func loadCredentials() async {
        let result = await credentialsService.loadCredentials()
        switch result {
        case .success(let creds):
            self.credentials = creds
            self.credentialError = nil
            // Keep —% until API call in Plan 03 provides real data
            // If token is already expired, surface that in title
            if creds.isExpired {
                self.menuBarTitle = "Auth expired"
                logger.warning("Loaded token is already expired")
            }
        case .failure:
            self.credentials = nil
            self.credentialError = .keychainItemNotFound
            self.menuBarTitle = "No credentials"
            logger.error("No credentials available from Keychain or file")
        }
    }
}
