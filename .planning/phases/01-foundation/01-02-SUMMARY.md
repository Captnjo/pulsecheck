---
phase: 01-foundation
plan: 02
subsystem: auth
tags: [keychain, security-framework, observable, swift6, credentials]

requires:
  - phase: 01-01
    provides: StatusBarController.updateTitle(_:), AppDelegate scaffold

provides:
  - AppError enum covering Keychain, file, API, and network failure cases
  - KeychainService reading claudeAiOauth nested JSON from Claude Code-credentials Keychain entry
  - CredentialsService with Keychain -> file fallback -> missing chain
  - UsageStore @Observable with credentials, credentialError, and menuBarTitle
  - AppDelegate wired to load credentials on launch and push title to status bar

affects: [01-03, all-future-phases]

tech-stack:
  added: [Security framework (SecItemCopyMatching), Observation (@Observable), OSLog]
  patterns: [@Observable @MainActor class for state, Keychain wrapper decode pattern, async Result return from service]

key-files:
  created:
    - ClaudeUsage/Models/AppError.swift
    - ClaudeUsage/Services/KeychainService.swift
    - ClaudeUsage/Services/CredentialsService.swift
    - ClaudeUsage/Store/UsageStore.swift
  modified:
    - ClaudeUsage/AppDelegate.swift
    - ClaudeUsage.xcodeproj/project.pbxproj

key-decisions:
  - "AppDelegate marked @MainActor for Swift 6 strict concurrency — required to initialize @MainActor UsageStore as stored property"
  - "kSecAttrAccount omitted from Keychain query to avoid hardcoding username 'jo'"
  - "expiresAt divided by 1000.0 before Date construction — field is milliseconds, not seconds"
  - "KeychainWrapper decode pattern: JSON is {claudeAiOauth: {...}}, not flat structure"

patterns-established:
  - "Keychain credentials accessed via KeychainWrapper struct, never flat decode"
  - "CredentialsService returns Result<ClaudeOAuthCredentials, AppError> — never throws to caller"
  - "UsageStore is the single source of truth for credentials and menu bar title"

requirements-completed: [AUTH-01, AUTH-02]

duration: 15min
completed: 2026-04-02
---

# Phase 1, Plan 02: Credential Reading Summary

**KeychainService decoding claudeAiOauth nested JSON from Claude Code-credentials, with CredentialsService Keychain-to-file fallback and @Observable UsageStore wired into AppDelegate launch**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-02
- **Completed:** 2026-04-02
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- AppError typed enum covers all failure modes in this phase and the next
- KeychainService reads claudeAiOauth nested structure using SecItemCopyMatching without kSecAttrAccount
- CredentialsService orchestrates Keychain first, file fallback second, graceful missing-state third
- UsageStore @Observable with menuBarTitle ("—%", "Auth expired", or "No credentials")
- AppDelegate loads credentials on launch and pushes resulting title to StatusBarController

## Task Commits

1. **Task 1: AppError enum and KeychainService** - `938c297` (feat)
2. **Task 2: CredentialsService, UsageStore, AppDelegate wiring** - `b706624` (feat)

## Files Created/Modified
- `ClaudeUsage/Models/AppError.swift` - Typed error enum with LocalizedError descriptions
- `ClaudeUsage/Services/KeychainService.swift` - Keychain read with KeychainWrapper + ClaudeOAuthCredentials
- `ClaudeUsage/Services/CredentialsService.swift` - Keychain -> file fallback -> failure orchestration
- `ClaudeUsage/Store/UsageStore.swift` - @Observable @MainActor state container
- `ClaudeUsage/AppDelegate.swift` - Added @MainActor, usageStore property, credential Task on launch
- `ClaudeUsage.xcodeproj/project.pbxproj` - Added Models/Services/Store groups and file references

## Decisions Made
- **@MainActor on AppDelegate:** Swift 6 strict concurrency (SWIFT_STRICT_CONCURRENCY=complete) disallows initializing a @MainActor class as a stored property default value in a non-isolated context. Marking AppDelegate @MainActor resolves this without removing the stored property pattern.
- **kSecAttrAccount omitted:** The Keychain account name is "jo" on the dev machine. Per research, other tools also omit kSecAttrAccount and let the Keychain return the first item matching the service name — this avoids any machine-specific hardcoding.
- **@Observable confirmed working:** Swift 6.3 / macOS 26.2 compiles @Observable without issues. macOS 14 deployment target alignment is correct.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] @MainActor added to AppDelegate for Swift 6 strict concurrency**
- **Found during:** Task 2 (AppDelegate wiring)
- **Issue:** `var usageStore = UsageStore()` failed to compile — "main actor-isolated default value in a nonisolated context". The project has SWIFT_STRICT_CONCURRENCY=complete, making this a compile error.
- **Fix:** Added `@MainActor` to the AppDelegate class declaration
- **Files modified:** ClaudeUsage/AppDelegate.swift
- **Verification:** BUILD SUCCEEDED after change
- **Committed in:** b706624 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — correctness bug)
**Impact on plan:** Necessary for compilation under Swift 6 strict concurrency. No scope creep. AppDelegate being @MainActor is appropriate for a class that only runs on the main thread.

## Issues Encountered

The plan specified `var usageStore = UsageStore()` but didn't account for SWIFT_STRICT_CONCURRENCY=complete in the project settings. @MainActor on AppDelegate is the correct Swift 6 fix.

## @Observable Under Swift 6.3

Compiled without warnings or errors. The `@Observable` macro with `@MainActor` class works as expected on the macOS 26.2 / Swift 6.3 development environment.

## Credential Loading Result

App successfully reads from Keychain on the development machine (Keychain path taken — service "Claude Code-credentials" present). File fallback code path is present but not testable on this machine (`.credentials.json` absent — expected per research).

## Known Stubs

None — all credential loading is fully wired. The `menuBarTitle` starts as "—%" and stays at "—%" when credentials load successfully (real percentage will be wired in Plan 03 after API call).

## Next Phase Readiness
- `accessToken` available via `usageStore.credentials?.accessToken` for Plan 03's API call
- `usageStore.menuBarTitle` will be updated by Plan 03 with real percentage
- `AppError.apiUnauthorized` and `.apiError` ready for Plan 03 error handling

## Self-Check: PASSED

- ClaudeUsage/Models/AppError.swift: FOUND
- ClaudeUsage/Services/KeychainService.swift: FOUND
- ClaudeUsage/Services/CredentialsService.swift: FOUND
- ClaudeUsage/Store/UsageStore.swift: FOUND
- Commit 938c297: FOUND
- Commit b706624: FOUND

---
*Phase: 01-foundation*
*Completed: 2026-04-02*
