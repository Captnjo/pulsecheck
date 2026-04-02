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
    var isFetching: Bool = false
    var lastFetchDate: Date?

    private let credentialsService = CredentialsService()
    private let apiClient = AnthropicAPIClient()
    private let tokenRefreshService = TokenRefreshService()
    private let keychain = KeychainService()
    private var pollingTask: Task<Void, Never>?
    private var backoffSeconds: Int = 60
    private var lastCredentialCheck: Date = .distantPast
    private let credentialRecheckInterval: TimeInterval = 300  // 5 minutes
    var onTitleChanged: ((String) -> Void)?

    func loadCredentials() async {
        let result = await credentialsService.loadCredentials()
        switch result {
        case .success(let creds):
            self.credentials = creds
            self.credentialError = nil
            if creds.isExpired {
                logger.info("Loaded expired credentials — refresh will be attempted on next fetch")
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

    func manualRefresh() async {
        pollingTask?.cancel()
        pollingTask = nil
        await fetchUsage()
        startPolling()
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func fetchUsage() async {
        guard !isFetching else {
            logger.debug("fetchUsage skipped — already in progress")
            return
        }
        isFetching = true
        defer { isFetching = false }
        // Re-read credentials if missing or expired — Claude Code may have refreshed them
        // Throttle to avoid spamming Keychain prompts if user clicked "Allow" instead of "Always Allow"
        if (credentials == nil || (credentials?.isExpired ?? false))
            && Date().timeIntervalSince(lastCredentialCheck) >= credentialRecheckInterval {
            lastCredentialCheck = Date()
            await loadCredentials()
        }
        guard let creds = credentials else {
            logger.warning("fetchUsage called with no credentials — skipping")
            return
        }
        let result = await apiClient.fetchUsage(accessToken: creds.accessToken)
        switch result {
        case .success(let response):
            self.usageResponse = response
            self.lastFetchDate = Date()
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
            switch error {
            case .apiUnauthorized:
                // Attempt single token refresh
                guard !creds.refreshToken.isEmpty else {
                    self.usageResponse = nil
                    self.menuBarTitle = "Auth expired"
                    self.backoffSeconds = 60
                    self.usageError = error
                    logger.error("401 received but no refresh token available")
                    break
                }
                do {
                    logger.info("401 received — attempting token refresh")
                    let newCreds = try await tokenRefreshService.refresh(
                        using: creds.refreshToken,
                        preservingScopes: creds.scopes
                    )
                    try keychain.writeShadowCredentials(newCreds)
                    self.credentials = newCreds
                    logger.info("Token refreshed successfully — retrying API call")

                    // Retry once with new token
                    let retryResult = await apiClient.fetchUsage(accessToken: newCreds.accessToken)
                    switch retryResult {
                    case .success(let response):
                        self.usageResponse = response
                        self.lastFetchDate = Date()
                        self.usageError = nil
                        self.backoffSeconds = 60
                        if let fiveHour = response.fiveHour {
                            self.menuBarTitle = fiveHour.displayString
                        } else if let sevenDay = response.sevenDay {
                            self.menuBarTitle = sevenDay.displayString
                        } else {
                            self.menuBarTitle = "—%"
                        }
                    case .failure(let retryError):
                        self.usageError = retryError
                        self.usageResponse = nil
                        self.menuBarTitle = "Auth expired"
                        self.backoffSeconds = 60
                        logger.error("Retry after refresh failed: \(retryError.localizedDescription)")
                    }
                } catch {
                    // Refresh failed — clear shadow, show error, let next poll cycle re-read Claude Code's token
                    logger.error("Token refresh failed: \(error.localizedDescription)")
                    self.credentials = nil
                    self.usageError = .apiUnauthorized
                    self.usageResponse = nil
                    self.menuBarTitle = "Auth expired"
                    self.backoffSeconds = 60
                    keychain.deleteShadowCredentials()
                }
            case .apiError(429, _):
                // Rate limited — keep last good data, back off
                self.usageError = error
                self.backoffSeconds = min(backoffSeconds * 2, 600)  // Max 10 min
                logger.warning("Rate limited (429) — backing off to \(self.backoffSeconds)s")
            default:
                self.usageError = error
                self.usageResponse = nil
                self.menuBarTitle = "—"
                self.backoffSeconds = 60
            }
            logger.error("API call failed: \(error.localizedDescription)")
        }
    }
}
