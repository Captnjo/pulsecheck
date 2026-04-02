import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "UsageStore")

@Observable
@MainActor
class UsageStore {
    var credentials: ClaudeOAuthCredentials?
    var credentialError: AppError?
    var menuBarTitle: String = "—%" {
        didSet { onTitleChanged?(menuBarTitle) }
    }
    var usageResponse: UsageResponse?
    var usageError: AppError?

    private let credentialsService = CredentialsService()
    private let apiClient = AnthropicAPIClient()
    private var pollingTask: Task<Void, Never>?
    private var backoffSeconds: Int = 60
    var onTitleChanged: ((String) -> Void)?

    func loadCredentials() async {
        let result = await credentialsService.loadCredentials()
        switch result {
        case .success(let creds):
            if creds.isExpired {
                self.credentials = nil
                self.credentialError = .apiUnauthorized
                self.menuBarTitle = "Auth expired"
                logger.warning("Loaded token is already expired")
            } else {
                self.credentials = creds
                self.credentialError = nil
            }
        case .failure:
            self.credentials = nil
            self.credentialError = .keychainItemNotFound
            self.menuBarTitle = "No credentials"
            logger.error("No credentials available from Keychain or file")
        }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { @MainActor in
            while !Task.isCancelled {
                logger.debug("Polling: fetching usage (interval: \(self.backoffSeconds)s)")
                await fetchUsage()
                do {
                    try await Task.sleep(for: .seconds(backoffSeconds))
                } catch {
                    break  // Task cancelled during sleep
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // TODO: Remove mock before release
    private func mockUsage() {
        let now = Date().addingTimeInterval(3 * 3600)
        let weekReset = Date().addingTimeInterval(165 * 3600)
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let response = UsageResponse(
            fiveHour: UsagePeriod(utilization: 57, resetsAt: fmt.string(from: now)),
            sevenDay: UsagePeriod(utilization: 12, resetsAt: fmt.string(from: weekReset)),
            sevenDayOauthApps: nil, sevenDayOpus: nil, sevenDaySonnet: nil,
            sevenDayCowork: nil, iguanaNecktie: nil, extraUsage: nil
        )
        self.usageResponse = response
        self.usageError = nil
        self.menuBarTitle = "57%"
    }

    func fetchUsage() async {
        // Uncomment next line to use mock data for screenshots:
        // mockUsage(); return

        guard let creds = credentials else {
            logger.warning("fetchUsage called with no credentials — skipping")
            return
        }
        let result = await apiClient.fetchUsage(accessToken: creds.accessToken)
        switch result {
        case .success(let response):
            self.usageResponse = response
            self.usageError = nil
            self.backoffSeconds = 60  // Reset to normal interval
            // Use five_hour utilization as primary display value
            if let fiveHour = response.fiveHour {
                self.menuBarTitle = fiveHour.displayString  // e.g. "51%"
            } else if let sevenDay = response.sevenDay {
                self.menuBarTitle = sevenDay.displayString
            } else {
                self.menuBarTitle = "—%"
            }
        case .failure(let error):
            self.usageError = error
            switch error {
            case .apiUnauthorized:
                self.usageResponse = nil
                self.menuBarTitle = "Auth expired"
                self.backoffSeconds = 60
            case .apiError(429, _):
                // Rate limited — keep last good data, back off
                self.backoffSeconds = min(backoffSeconds * 2, 600)  // Max 10 min
                logger.warning("Rate limited (429) — backing off to \(self.backoffSeconds)s")
            default:
                self.usageResponse = nil
                self.menuBarTitle = "—"
                self.backoffSeconds = 60
            }
            logger.error("API call failed: \(error.localizedDescription)")
        }
    }
}
