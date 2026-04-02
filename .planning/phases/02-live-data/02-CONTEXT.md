# Phase 2: Live Data - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a 60-second polling loop so the daily usage percentage in the menu bar stays current without user action. Handle network errors gracefully — show "—" on failure, keep polling on schedule. This phase does NOT build the dropdown panel (Phase 3).

</domain>

<decisions>
## Implementation Decisions

### Polling Architecture
- Use Task.sleep loop in UsageStore for polling — structured concurrency with auto-cancellation
- Keep "—%" as the initial display before first fetch completes (already the default from Phase 1)
- On error: show "—" in menu bar (em dash, no %), keep polling on the regular 60s schedule — no exponential backoff, no retry acceleration

### Display Behavior
- Menu bar shows fiveHour (daily) usage percentage — matches /usage command output
- On error: "—" (em dash only, no %) to distinguish from "—%" loading state
- Log polling activity at OSLog .debug level — visible in Console.app but not noisy

### User Clarification
- Menu bar: daily usage percentage only
- Popover (Phase 3): progress bars + reset times for BOTH daily and weekly

### Claude's Discretion
- Task cancellation strategy when app quits
- Whether to fetch immediately on launch or wait for first poll interval

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- UsageStore.fetchUsage() — already makes a single API call and updates menuBarTitle
- AnthropicAPIClient.fetchUsage(accessToken:) — returns Result<UsageResponse, AppError>
- StatusBarController.updateTitle(_:) — sets menu bar text
- AppDelegate already calls fetchUsage once on launch

### Established Patterns
- @Observable @MainActor UsageStore for state
- AppDelegate owns StatusBarController and UsageStore
- OSLog for debug logging in AnthropicAPIClient

### Integration Points
- UsageStore needs a startPolling()/stopPolling() method
- AppDelegate should call startPolling() after initial fetch
- Polling task should be cancelled on app quit

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond standard polling pattern — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

- Popover with progress bars and reset times for daily + weekly → Phase 3
- Color-coded percentage based on thresholds → v2

</deferred>
