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
    var usageResponse: UsageResponse?
    var usageError: AppError?

    private let credentialsService = CredentialsService()
    private let apiClient = AnthropicAPIClient()

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

    func fetchUsage() async {
        guard let creds = credentials else {
            logger.warning("fetchUsage called with no credentials — skipping")
            return
        }
        let result = await apiClient.fetchUsage(accessToken: creds.accessToken)
        switch result {
        case .success(let response):
            self.usageResponse = response
            self.usageError = nil
            // Use five_hour utilization as primary display value
            if let fiveHour = response.fiveHour {
                self.menuBarTitle = fiveHour.displayString  // e.g. "51%"
            } else if let sevenDay = response.sevenDay {
                self.menuBarTitle = sevenDay.displayString
            } else {
                self.menuBarTitle = "—%"
            }
        case .failure(let error):
            self.usageResponse = nil
            self.usageError = error
            switch error {
            case .apiUnauthorized:
                self.menuBarTitle = "Auth expired"
            default:
                self.menuBarTitle = "API unavailable"
            }
            logger.error("API call failed: \(error.localizedDescription)")
        }
    }
}
