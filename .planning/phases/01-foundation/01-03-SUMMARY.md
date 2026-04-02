---
phase: 01-foundation
plan: 03
subsystem: api
tags: [urlsession, codable, observable, swift6, anthropic-api, oauth]

requires:
  - phase: 01-02
    provides: UsageStore @Observable, ClaudeOAuthCredentials with accessToken, AppError cases apiUnauthorized/apiError/networkError

provides:
  - UsageResponse, UsagePeriod, ExtraUsage Codable structs matching empirical API response shape
  - AnthropicAPIClient.fetchUsage(accessToken:) returning Result<UsageResponse, AppError>
  - UsageStore.fetchUsage() wired to API client, updates menuBarTitle from fiveHour.displayString
  - AppDelegate launch sequence: loadCredentials -> updateTitle -> fetchUsage -> updateTitle

affects: [02-polling, all-future-phases]

tech-stack:
  added: [OSLog (AnthropicAPIClient), URLSession async/await]
  patterns: [Result<T, AppError> return from async service, fiveHour primary / sevenDay fallback display logic]

key-files:
  created:
    - ClaudeUsage/Models/UsageResponse.swift
    - ClaudeUsage/Services/AnthropicAPIClient.swift
  modified:
    - ClaudeUsage/Store/UsageStore.swift
    - ClaudeUsage/AppDelegate.swift
    - ClaudeUsage.xcodeproj/project.pbxproj

key-decisions:
  - "utilization field is already 0-100 percentage — displayString does not multiply, just rounds to Int and appends %"
  - "fiveHour is primary display value; sevenDay is fallback; '—%' if both nil"
  - "AnthropicAPIClient is a struct (not actor) — called from @MainActor UsageStore, no data race"
  - "Raw API response logged at .debug level in Phase 1 for empirical verification"

patterns-established:
  - "AnthropicAPIClient returns Result<UsageResponse, AppError> — caller decides how to surface errors"
  - "Error display strings are set in UsageStore.fetchUsage switch — 'Auth expired' for 401, 'API unavailable' for others"

requirements-completed: [AUTH-01, AUTH-02]

duration: 15min
completed: 2026-04-02
---

# Phase 1, Plan 03: API Client and Menu Bar Wiring Summary

**AnthropicAPIClient making GET /api/oauth/usage with OAuth bearer token, UsageResponse Codable model with empirical field names, and UsageStore wiring credentials to live percentage display in the menu bar**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-02
- **Completed:** 2026-04-02
- **Tasks:** 2 auto + 1 checkpoint (checkpoint pending human verification)
- **Files modified:** 5

## Accomplishments
- UsageResponse, UsagePeriod, ExtraUsage Codable structs match empirically confirmed API response shape including all nullable fields
- AnthropicAPIClient sends exact confirmed headers: Bearer token, anthropic-beta oauth-2025-04-20, Accept application/json
- Raw response logged to Console.app via OSLog for empirical verification
- UsageStore.fetchUsage() updates menuBarTitle to real percentage (e.g. "51%") or error string ("Auth expired", "API unavailable")
- AppDelegate launch sequence extended: loadCredentials -> title update -> fetchUsage -> title update

## Task Commits

1. **Task 1: UsageResponse Codable models and AnthropicAPIClient** - `be0f2b7` (feat)
2. **Task 2: Wire API call into UsageStore and update menu bar title** - `352b5c6` (feat)

## Files Created/Modified
- `ClaudeUsage/Models/UsageResponse.swift` - UsageResponse, UsagePeriod, ExtraUsage Decodable structs; UsagePeriod.displayString rounds utilization to Int and appends %
- `ClaudeUsage/Services/AnthropicAPIClient.swift` - fetchUsage(accessToken:) with exact OAuth headers, 200/401/default status handling, OSLog debug logging
- `ClaudeUsage/Store/UsageStore.swift` - Added usageResponse, usageError properties, apiClient instance, fetchUsage() async method
- `ClaudeUsage/AppDelegate.swift` - Extended Task block to call fetchUsage after loadCredentials, with second updateTitle call
- `ClaudeUsage.xcodeproj/project.pbxproj` - Added UsageResponse.swift and AnthropicAPIClient.swift file references and build sources entries

## Decisions Made
- **utilization is 0-100 not 0-1:** Per empirical research (51.0 = 51%), displayString uses `Int(utilization.rounded())` directly. No multiplication.
- **Struct for AnthropicAPIClient:** No mutable state needed. Struct is safe to call from @MainActor UsageStore without Sendable concerns.
- **fiveHour primary, sevenDay fallback:** Plan spec. If fiveHour nil (shouldn't happen based on empirical data), sevenDay is shown.
- **Phase 1 raw logging:** .debug level OSLog of full JSON response enables post-launch empirical verification in Console.app.

## Deviations from Plan

None — plan executed exactly as written.

## Checkpoint Pending

**Task 3 (checkpoint:human-verify)** requires running the app in Xcode and visually verifying:
1. Menu bar updates from —% to a real percentage (e.g. "51%") after launch
2. Console.app shows "API response status: 200" and raw JSON
3. Percentage is reasonable (between 0% and 100%)
4. App relaunches and shows percentage again (not stuck on —%)

See CHECKPOINT REACHED message for full verification steps.

## Known Stubs

None — all data flow is wired. The menu bar percentage will show real API data after the checkpoint is approved.

## Next Phase Readiness
- End-to-end credential → API → display path is implemented and builds cleanly
- Phase 2 (polling) can wrap fetchUsage() in a Timer loop in UsageStore
- usageResponse property available for future dropdown panel display (Phase 2 UI work)

## Self-Check: PASSED

- ClaudeUsage/Models/UsageResponse.swift: FOUND
- ClaudeUsage/Services/AnthropicAPIClient.swift: FOUND
- Commit be0f2b7: FOUND (feat(01-03): UsageResponse Codable models and AnthropicAPIClient)
- Commit 352b5c6: FOUND (feat(01-03): wire API call into UsageStore and update menu bar title)

---
*Phase: 01-foundation*
*Completed: 2026-04-02*
