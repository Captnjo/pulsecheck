import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.jo.PulseCheck", category: "UsageStore")

@Observable
@MainActor
class UsageStore {
    var credentials: ClaudeOAuthCredentials?
    private(set) var credentialSource: CredentialSource?
    var credentialError: AppError?
    var usageResponse: UsageResponse?
    var usageError: AppError?
    /// Non-blocking status text shown alongside stale data (degrade-don't-blind).
    var usageStaleNotice: String?
    /// Set when a transport failure suggests the next poll may succeed sooner.
    var retryAdvised: Bool = false
    var isFetching: Bool = false
    var lastFetchDate: Date?

    // Codex (read-only ChatGPT OAuth usage)
    var codexUsage: CodexUsage?
    var codexError: AppError?
    var codexLastFetch: Date?

    // OpenRouter (spend data via opencode's stored key)
    var openRouterUsage: OpenRouterKeyInfo?
    var openRouterError: AppError?
    var openRouterLastFetch: Date?

    private let credentialsService = CredentialsService()
    private let apiClient = AnthropicAPIClient()
    private let tokenRefreshService = TokenRefreshService()
    private let keychain = KeychainService()
    private let codexAPIClient = CodexAPIClient()
    private let openRouterAPIClient = OpenRouterAPIClient()
    private var pollingTask: Task<Void, Never>?
    private var backoffSeconds: Int = 60
    private var lastCredentialCheck: Date = .distantPast
    private let credentialRecheckInterval: TimeInterval = 300  // 5 minutes
    /// The access token that last received a persistent 401. Until the keychain
    /// yields a DIFFERENT token, calling the usage endpoint is pointless — and
    /// repeated rejected calls trip Anthropic's abuse limiter (the 429 storm of
    /// 2026-09-04). Skip API calls for a known-rejected token.
    private var rejectedAccessToken: String?
    /// Burn-rate history per display window (five-hour tracked; weekly moves too
    /// slowly to project meaningfully).
    private var burnRate = BurnRateModel()
    /// Last fetch attempt (success or fail) — drives the manual-refresh spam guard.
    private var lastFetchAttempt: Date = .distantPast
    private let refreshReuseInterval: TimeInterval = 15

    func loadCredentials() async {
        let result = await credentialsService.loadCredentials()
        switch result {
        case .success(let set):
            self.credentials = set.credentials
            self.credentialSource = set.source
            self.credentialError = nil
            if set.credentials.isExpired {
                logger.info("Loaded credentials are expired (source: \(set.source == .shadow ? "shadow" : "claudeCode"))")
            }
        case .failure:
            self.credentials = nil
            self.credentialSource = nil
            self.credentialError = .keychainItemNotFound
            self.usageError = .providerNotAuthenticated("Claude Code")
            logger.error("No Claude Code credentials available from Keychain")
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
        // Spam guard (Omarchy pattern): repeated clicks reuse the recent result
        // instead of firing a request per click.
        guard Date().timeIntervalSince(lastFetchAttempt) >= refreshReuseInterval else {
            logger.debug("manualRefresh skipped — fetched within reuse window")
            return
        }
        lastFetchAttempt = Date()
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
        // Re-read credentials if missing or stale-expired — Claude Code may have
        // refreshed them. Missing → re-read immediately; expired → throttle re-reads
        // to avoid spamming Keychain prompts if user clicked "Allow" not "Always Allow".
        let missing = credentials == nil
        let expired = credentials?.isExpired ?? false
        if missing || (expired && Date().timeIntervalSince(lastCredentialCheck) >= credentialRecheckInterval) {
            lastCredentialCheck = Date()
            await loadCredentials()
        }
        guard let creds = credentials else {
            logger.warning("No Claude credentials — fetching remaining providers only")
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchCodexUsage() }
                group.addTask { await self.fetchOpenRouterUsage() }
            }
            return
        }
        if creds.accessToken == rejectedAccessToken {
            // Same token already rejected server-side — an API call is useless and
            // risks tripping the rate limiter again. But the keychain MUST still be
            // re-read on a throttle: a token can be revoked server-side while still
            // unexpired locally, and if we stopped re-reading here we'd never
            // notice Claude Code rotating the keychain (the 1.4.1 stuck-state bug).
            if Date().timeIntervalSince(lastCredentialCheck) >= credentialRecheckInterval {
                lastCredentialCheck = Date()
                await loadCredentials()
            }
            if let fresh = credentials, fresh.accessToken != rejectedAccessToken {
                logger.info("Keychain rotated past rejected token — resuming API calls")
                rejectedAccessToken = nil
            } else {
                logger.debug("Skipping API call — token still rejected; awaiting keychain change")
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await self.fetchCodexUsage() }
                    group.addTask { await self.fetchOpenRouterUsage() }
                }
                return
            }
        }
        guard let currentCreds = credentials else { return }
        let result = await apiClient.fetchUsage(accessToken: currentCreds.accessToken)
        await handleUsageResult(result, using: currentCreds)

        // Codex + OpenRouter in parallel; each is independent of Claude's state
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchCodexUsage() }
            group.addTask { await self.fetchOpenRouterUsage() }
        }
    }

    private func fetchCodexUsage() async {
        switch CodexCredentialsReader.load() {
        case .failure(.notFound):
            codexUsage = nil
            codexError = .providerUnavailable("Codex")
        case .failure(.wrongMode):
            codexUsage = nil
            codexError = .providerUnavailable("Codex (API-key mode)")
        case .failure:
            codexUsage = nil
            codexError = .providerUnavailable("Codex")
        case .success(let creds):
            let result = await codexAPIClient.fetchUsage(credentials: creds)
            switch result {
            case .success(let usage):
                codexUsage = usage
                codexError = nil
                codexLastFetch = Date()
            case .failure(let error):
                // Keep last good data on transient errors; clear on auth failures
                if case .apiUnauthorized = error {
                    codexUsage = nil
                }
                codexError = error
            }
        }
    }

    private func fetchOpenRouterUsage() async {
        switch OpenRouterCredentialsReader.load() {
        case .failure(.notFound):
            openRouterUsage = nil
            openRouterError = .providerUnavailable("opencode")
        case .failure:
            openRouterUsage = nil
            openRouterError = .providerNotAuthenticated("OpenRouter")
        case .success(let creds):
            let result = await openRouterAPIClient.fetchKeyInfo(apiKey: creds.apiKey)
            switch result {
            case .success(let info):
                openRouterUsage = info
                openRouterError = nil
                openRouterLastFetch = Date()
            case .failure(let error):
                if case .apiUnauthorized = error {
                    openRouterUsage = nil
                }
                openRouterError = error
            }
        }
    }


    // MARK: - Burn-rate projection (Claude five-hour window)

    /// Projected utilization at window reset, or nil when no trend is provable.
    func projectedFiveHourAtReset() -> Double? {
        guard let current = usageResponse?.fiveHour?.utilization,
              let resetsAt = usageResponse?.fiveHour?.resetsAt,
              let resetDate = parseISO(resetsAt) else { return nil }
        return burnRate.projectedPercentAtReset(now: Date(), resetAt: resetDate, current: current)
    }

    /// Human caption like "burning fast — out in ~1h20m", or nil when steady.
    func burnRateCaption() -> String? {
        guard let current = usageResponse?.fiveHour?.utilization else { return nil }
        guard let minutes = burnRate.minutesUntilFull(now: Date(), current: current) else { return nil }
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        if hours > 0 {
            return "burning fast — out in ~\(hours)h\(mins)m at this rate"
        }
        return "burning fast — out in ~\(mins)m at this rate"
    }

    private func parseISO(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }

    private func applySuccess(_ response: UsageResponse) {
        self.usageResponse = response
        self.lastFetchDate = Date()
        self.usageError = nil
        self.usageStaleNotice = nil
        self.backoffSeconds = 60
        self.rejectedAccessToken = nil
        if let fiveHour = response.fiveHour {
            burnRate.record(fiveHour.utilization)
        }
    }

    /// Keep the last good data visible with an honest status line, instead of
    /// wiping it (Omarchy's degrade-don't-blind pattern). Stale data is dropped
    /// only when its window has reset — numbers from a finished window are lies.
    private func degradeWithLastError(_ error: AppError) {
        self.usageError = error
        self.usageStaleNotice = Self.staleNotice(for: error)
        // Transport failure → the network may be back any second; retry sooner.
        // Server rejections keep/raise backoff.
        if AnthropicAPIClient.isTransportFailure(error) {
            self.backoffSeconds = 30
            self.retryAdvised = true
        } else {
            self.backoffSeconds = 60
        }
    }

    private static func staleNotice(for error: AppError) -> String? {
        switch error {
        case .rateLimited(let retryAfter):
            var text = "Anthropic is rate-limiting checks right now"
            if let retryAfter { text += " (retrying in ~\(retryAfter)s)" }
            return text + " — showing last known usage."
        case .networkError:
            return "Can't reach Anthropic — showing last known usage."
        case .apiError(let code, _):
            return "Anthropic returned error \(code) — showing last known usage."
        default:
            return nil
        }
    }

    private func setAuthExpired() {
        self.credentials = nil
        self.credentialSource = nil
        self.usageError = .apiUnauthorized
        // Keep last known usage visible with an honest notice; the numbers go
        // stale but are better than blinding the panel (Omarchy pattern).
        self.usageStaleNotice = "Auth expired — showing last known usage until Claude Code runs again."
        self.backoffSeconds = 60
    }

    private func handleUsageResult(_ result: Result<UsageResponse, AppError>, using creds: ClaudeOAuthCredentials) async {
        switch result {
        case .success(let response):
            applySuccess(response)
        case .failure(let error):
            switch error {
            case .apiUnauthorized:
                await handleUnauthorized(with: creds)
            case .rateLimited(let retryAfter):
                // Rate limited — keep last good data, back off. Honor Retry-After
                // when the server sends one (capped at 30 min).
                degradeWithLastError(error)
                var backoff = min(backoffSeconds * 2, 600)
                if let retryAfter {
                    backoff = max(backoff, min(retryAfter, 1800))
                }
                self.backoffSeconds = backoff
                logger.warning("Rate limited (429) — backing off to \(self.backoffSeconds)s")
            default:
                degradeWithLastError(error)
            }
            logger.error("API call failed: \(error.localizedDescription)")
        }
    }

    // SAFETY RULE: never consume Claude Code's primary refresh token. Its refresh
    // tokens rotate on every use — refreshing with Claude Code's token invalidates
    // the copy Claude Code holds and forces it to sign back in. Self-refresh is only
    // allowed with credentials PulseCheck obtained through its own refresh calls
    // (source == .shadow).
    private func handleUnauthorized(with creds: ClaudeOAuthCredentials) async {
        logger.info("401 received — re-reading credentials from Keychain")
        let previousToken = creds.accessToken
        rejectedAccessToken = previousToken  // remember: do not call again with this token
        await loadCredentials()  // unthrottled: recovery path

        // Claude Code may have refreshed since the failed call — retry with its token
        if let fresh = credentials, fresh.accessToken != previousToken {
            logger.info("Credentials changed since last fetch — retrying with new token")
            let retry = await apiClient.fetchUsage(accessToken: fresh.accessToken)
            if case .success(let response) = retry {
                applySuccess(response)
                return
            }
            // Still failing — fall through; do NOT loop on 401
        }

        guard credentialSource == .shadow,
              let refreshToken = credentials?.refreshToken,
              !refreshToken.isEmpty else {
            // Credentials are Claude Code's (or gone) — nothing safe to refresh with.
            // Claude Code will obtain fresh tokens on its next run; we re-sync then.
            logger.error("401 persists on Claude Code-owned credentials — not consuming its refresh token; showing auth-expired")
            setAuthExpired()
            return
        }

        do {
            logger.info("401 persists — refreshing PulseCheck-owned credentials")
            let newCreds = try await tokenRefreshService.refresh(
                using: refreshToken,
                preservingScopes: credentials?.scopes ?? []
            )
            try keychain.writeShadowCredentials(newCreds)
            self.credentials = newCreds
            self.credentialSource = .shadow
            logger.info("Token refreshed successfully — retrying API call")
            self.rejectedAccessToken = nil  // new token lineage, API calls allowed again

            let retry = await apiClient.fetchUsage(accessToken: newCreds.accessToken)
            switch retry {
            case .success(let response):
                applySuccess(response)
            case .failure(let retryError):
                if case .rateLimited(let retryAfter) = retryError {
                    degradeWithLastError(retryError)
                    var backoff = min(backoffSeconds * 2, 600)
                    if let retryAfter {
                        backoff = max(backoff, min(retryAfter, 1800))
                    }
                    self.backoffSeconds = backoff
                } else if case .apiUnauthorized = retryError {
                    self.usageError = retryError
                    self.usageStaleNotice = "Auth expired — showing last known usage until Claude Code runs again."
                    self.backoffSeconds = 60
                } else {
                    degradeWithLastError(retryError)
                }
                logger.error("Retry after refresh failed: \(retryError.localizedDescription)")
            }
        } catch {
            logger.error("Token refresh failed: \(error.localizedDescription)")
            keychain.deleteShadowCredentials()
            setAuthExpired()
        }
    }
}
