---
phase: 02-live-data
plan: 01
subsystem: api
tags: [swift, polling, async, task, osal, menubar]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: UsageStore.fetchUsage(), AppDelegate with statusBarController, Keychain credential loading

provides:
  - UsageStore.startPolling() — 60-second polling loop using Task + Task.sleep
  - UsageStore.stopPolling() — cancels and clears pollingTask
  - AppDelegate.applicationWillTerminate — clean task cancellation on quit
  - Error display shows "—" (em dash, no %) on API failure to distinguish from "—%" loading state

affects: [03-popover-ui, any phase touching UsageStore polling or error display]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Unstructured Task + Task.sleep(for: .seconds(60)) loop for polling, @MainActor isolated"
    - "Guard break on CancellationError from Task.sleep to exit polling loop cleanly"
    - "pollingTask?.cancel() before reassigning — idempotent startPolling()"

key-files:
  created: []
  modified:
    - ClaudeUsage/Store/UsageStore.swift
    - ClaudeUsage/AppDelegate.swift

key-decisions:
  - "startPolling() uses unstructured Task (not structured concurrency) stored as a property — allows explicit cancellation from applicationWillTerminate"
  - "startPolling() called inside the initial launch Task after fetchUsage(), not at top level — ensures first-fetch completes before 60s cadence starts"
  - "Error display uses em dash without % ('—') for API failures to distinguish from '—%' loading state (DISP-01 locked decision)"
  - "No exponential backoff — plain 60s cadence regardless of errors per plan spec"

patterns-established:
  - "Polling pattern: private Task stored property, startPolling()/stopPolling() pair, cancel-on-sleep via CancellationError"
  - "App lifecycle cleanup: applicationWillTerminate cancels background Tasks"

requirements-completed: [POLL-01, POLL-02, DISP-01]

# Metrics
duration: 2min
completed: 2026-04-02
---

# Phase 2 Plan 1: Live Data Polling Summary

**60-second polling loop via stored Task with Task.sleep, wired to app lifecycle in AppDelegate; API error display changed to "—" to distinguish from loading state**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-02T07:14:06Z
- **Completed:** 2026-04-02T07:15:27Z
- **Tasks:** 2 of 3 automated (Task 3 is human-verify checkpoint)
- **Files modified:** 2

## Accomplishments
- UsageStore gains `startPolling()` and `stopPolling()` with a properly cancellation-aware Task loop
- AppDelegate wires polling start after initial fetch and stops on app quit
- API error display changed from "API unavailable" to "—" (em dash, no %) per DISP-01 decision

## Task Commits

Each task was committed atomically:

1. **Task 1: Add startPolling/stopPolling to UsageStore** - `fd7b2b5` (feat)
2. **Task 2: Wire poll lifecycle in AppDelegate** - `6d64f38` (feat)
3. **Task 3: Verify live polling in menu bar** - checkpoint:human-verify (pending user verification)

## Files Created/Modified
- `ClaudeUsage/Store/UsageStore.swift` - Added pollingTask property, startPolling(), stopPolling(); fixed error display
- `ClaudeUsage/AppDelegate.swift` - Added startPolling() call after initial fetch; added applicationWillTerminate with stopPolling()

## Decisions Made
- `startPolling()` is idempotent — cancels any existing task before creating a new one; safe to call from AppDelegate without guard
- The polling Task is `@MainActor` isolated to match UsageStore's actor isolation, avoiding any concurrency boundary crossings
- `startPolling()` is placed inside the initial launch `Task { @MainActor in ... }` block (not at top level), so first fetch always completes before 60s cadence begins

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Polling is live — menu bar percentage now updates every 60 seconds automatically
- App quits cleanly with no orphaned background tasks
- Task 3 (human-verify checkpoint) requires user to confirm polling messages in Console.app
- Phase 3 (popover UI) can proceed after checkpoint approval — UsageStore polling is the data source it needs

## Self-Check: PASSED

- FOUND: ClaudeUsage/Store/UsageStore.swift
- FOUND: ClaudeUsage/AppDelegate.swift
- FOUND: .planning/phases/02-live-data/02-01-SUMMARY.md
- FOUND commit: fd7b2b5
- FOUND commit: 6d64f38

---
*Phase: 02-live-data*
*Completed: 2026-04-02*
