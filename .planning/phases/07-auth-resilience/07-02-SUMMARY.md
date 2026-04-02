---
phase: 07-auth-resilience
plan: 02
subsystem: auth
tags: [token-refresh, keychain, shadow-credentials, oauth, 401-retry, credential-loading]

requires:
  - phase: 07-01
    provides: [TokenRefreshService actor, shadow Keychain CRUD, AppError.tokenRefreshFailed/keychainWriteFailed]

provides:
  - shadow-first credential loading with Claude Code re-auth detection in CredentialsService
  - 401-refresh-retry flow in UsageStore (single attempt, write shadow on success, clear on failure)
  - expired credentials passed to caller for refresh rather than rejected immediately

affects: [CredentialsService, UsageStore, polling-loop]

tech-stack:
  added: []
  patterns: [shadow-first-credential-read, re-auth-detection-via-token-comparison, 401-refresh-retry-single-attempt]

key-files:
  created: []
  modified:
    - PulseCheck/Services/CredentialsService.swift
    - PulseCheck/Store/UsageStore.swift

key-decisions:
  - "expired-credentials-passed-not-rejected: CredentialsService returns expired shadow credentials to caller; UsageStore's 401 flow handles refresh — prevents silent 'Auth expired' on first expired encounter"
  - "shadow-write-on-refresh-success: After successful TokenRefreshService.refresh(), new credentials written to shadow Keychain immediately and self.credentials updated to avoid re-reading on next cycle"
  - "shadow-delete-on-refresh-failure: Failed token refresh deletes shadow Keychain item so next poll cycle re-reads from Claude Code's Keychain item rather than retrying with a known-bad token"

patterns-established:
  - "Credential loading: shadow-first read, re-auth detection by refreshToken comparison, expired-but-valid return"
  - "401 recovery: single refresh attempt via actor, shadow write, immediate retry — no second refresh on retry failure"

requirements-completed: [AUTH-10]

duration: 10min
completed: 2026-04-03
---

# Phase 07 Plan 02: Token Refresh Wiring Summary

**Shadow-first CredentialsService with re-auth detection and UsageStore 401-refresh-retry using single-attempt guard, shadow Keychain write on success, and shadow delete on failure.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-03T00:00:00Z
- **Completed:** 2026-04-03T00:10:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- CredentialsService.loadCredentials() reads shadow Keychain first, detects Claude Code re-auth by comparing refreshToken values, discards stale shadow and returns primary credentials when mismatch detected
- UsageStore.loadCredentials() no longer rejects expired tokens — returns them so the 401 path in fetchUsage() handles refresh rather than showing "Auth expired" prematurely
- UsageStore.fetchUsage() handles 401 with single token refresh attempt, retries API call once with the new token, writes to shadow Keychain on success, clears shadow and sets credentials to nil on failure so next cycle re-reads from Claude Code

## Task Commits

1. **Task 1: CredentialsService shadow-first read with re-auth detection** - `191a4e1` (feat)
2. **Task 2: UsageStore 401-refresh-retry flow** - `7c6b255` (feat)

## Files Created/Modified

- `PulseCheck/Services/CredentialsService.swift` - Shadow-first credential loading with re-auth detection and expired-credential pass-through
- `PulseCheck/Store/UsageStore.swift` - 401-refresh-retry flow, tokenRefreshService and keychain properties added, loadCredentials() updated to pass expired credentials

## Decisions Made

- **Expired credentials passed, not rejected** — CredentialsService now returns expired shadow credentials so UsageStore can use the refreshToken in its 401 path. Rejecting at load time would cause immediate "Auth expired" display on startup after the shadow token expires naturally.
- **Shadow write immediately after refresh** — `self.credentials = newCreds` and `try keychain.writeShadowCredentials(newCreds)` both happen before the retry, so subsequent polling cycles immediately use the new token without needing another Keychain re-read.
- **Shadow delete on failure** — Clearing the shadow item on refresh failure ensures the next poll cycle falls back to Claude Code's Keychain item rather than retrying with the known-bad shadow token.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Adapted non-compiling guard pattern for non-optional String**

- **Found during:** Task 2 (UsageStore 401-refresh-retry)
- **Issue:** Plan snippet contained `guard let refreshToken = creds.refreshToken as String?` — `refreshToken` is a non-optional `String`, so the `as String?` cast and guard-let pattern would not compile
- **Fix:** Replaced with `guard !creds.refreshToken.isEmpty else` which achieves the same guard (no refresh token available) while compiling correctly
- **Files modified:** PulseCheck/Store/UsageStore.swift
- **Verification:** Build succeeded
- **Committed in:** 7c6b255 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - non-compiling plan snippet adapted)
**Impact on plan:** Minimal — identical runtime behavior, corrected Swift type system usage.

## Issues Encountered

None — both tasks implemented cleanly. The plan snippet for Task 2 had a non-compiling guard pattern which was corrected inline (deviation above).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- AUTH-10 complete — the app can now silently refresh expired tokens and continue polling without user intervention
- Full v1.1 milestone feature set is implemented: adaptive icon, timestamp, refresh button, auto-token-refresh
- Phase 07 is complete; ready for milestone validation and v1.1 release preparation

## Known Stubs

None — all methods are fully implemented.

## Self-Check: PASSED

- PulseCheck/Services/CredentialsService.swift: FOUND
- PulseCheck/Store/UsageStore.swift: FOUND
- .planning/phases/07-auth-resilience/07-02-SUMMARY.md: FOUND
- Commit 191a4e1: FOUND
- Commit 7c6b255: FOUND
- xcodebuild BUILD SUCCEEDED

---
*Phase: 07-auth-resilience*
*Completed: 2026-04-03*
