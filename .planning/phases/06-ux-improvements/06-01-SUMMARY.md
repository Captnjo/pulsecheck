---
phase: 06-ux-improvements
plan: 01
subsystem: ui
tags: [swiftui, menubar, polling, timestamp, refresh]

# Dependency graph
requires:
  - phase: 05-visual-polish
    provides: menu bar icon and panel UI foundation

provides:
  - isFetching guard preventing concurrent API fetches
  - lastFetchDate tracking on successful API responses only
  - Absolute timestamp display in panel footer
  - Manual refresh button with spin animation and double-fetch guard

affects: [07-oauth-refresh, any future polling changes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - isFetching guard pattern with defer cleanup for concurrent-request prevention
    - TimelineView(.periodic) for auto-refreshing UI without explicit timers
    - Absolute timestamp display (date/time string) instead of relative formatting

key-files:
  created: []
  modified:
    - PulseCheck/Store/UsageStore.swift
    - PulseCheck/Views/UsagePanelView.swift

key-decisions:
  - "Used absolute timestamp format (date + time string) instead of RelativeDateTimeFormatter — avoids ambiguity of '3 minutes ago' becoming stale between panel opens"
  - "Used .borderless button style (not .plain) for the refresh button — renders correctly in the menu bar panel context"
  - "lastFetchDate set only on successful API response, never on failure — timestamp accurately reflects when data was last known-good"
  - "startPolling() called after manual fetchUsage() to reset the 60-second countdown from zero"

patterns-established:
  - "isFetching guard: set true at top of fetchUsage(), use defer to reset false — prevents race conditions cleanly"
  - "TimelineView(.periodic(from:by:)) for auto-refreshing caption text without separate timers"

requirements-completed: [PANEL-10, PANEL-11]

# Metrics
duration: ~30min
completed: 2026-04-02
---

# Phase 06 Plan 01: Last Updated Timestamp and Manual Refresh Summary

**Absolute timestamp + borderless refresh button in panel footer, with isFetching guard preventing concurrent API calls and polling countdown reset on manual refresh**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-04-02
- **Completed:** 2026-04-02
- **Tasks:** 2 auto + 1 human-verify checkpoint
- **Files modified:** 2

## Accomplishments

- Added `isFetching: Bool` and `lastFetchDate: Date?` to UsageStore with guard preventing concurrent fetches
- Added `timestampAndRefreshRow()` to UsagePanelView showing absolute timestamp and refresh button in both normalState and errorState
- Human verification confirmed: button triggers API calls (confirmed via 429 responses in logs), absolute timestamp displays correctly

## Task Commits

Each task was committed atomically:

1. **Task 1: Add isFetching guard and lastFetchDate to UsageStore** - `be54016` (feat)
2. **Task 2: Add timestamp and refresh button row to UsagePanelView** - `01f3ccc` (feat)
3. **Task 2-fix: Use absolute timestamp, fix refresh button** - `93d01dc` (fix)

## Files Created/Modified

- `PulseCheck/Store/UsageStore.swift` — Added `isFetching` guard, `lastFetchDate` tracking (set only on successful fetch)
- `PulseCheck/Views/UsagePanelView.swift` — Added `timestampAndRefreshRow()` with TimelineView, absolute timestamp, and .borderless refresh button with spin animation

## Decisions Made

- **Absolute vs relative timestamp:** Plan specified `RelativeDateTimeFormatter` (e.g. "Updated 3 minutes ago"), but this was changed to an absolute date/time string during the fix commit. The absolute format avoids the timestamp appearing stale when the panel is opened well after the last fetch — the exact time is always accurate.
- **Button style:** Changed from `.plain` to `.borderless` for the refresh button — `.plain` did not render correctly in the menu bar panel context.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Switched to absolute timestamp and fixed button style**
- **Found during:** Task 2 (initial implementation)
- **Issue:** `RelativeDateTimeFormatter` output can appear stale when the panel is opened minutes after the last fetch; `.plain` button style rendered incorrectly
- **Fix:** Replaced relative formatter with absolute date/time string (`formatted(date: .abbreviated, time: .shortened)`); changed button style to `.borderless`
- **Files modified:** `PulseCheck/Views/UsagePanelView.swift`, `PulseCheck/Store/UsageStore.swift`
- **Verification:** User confirmed absolute timestamp shows correctly and button triggers API calls
- **Committed in:** `93d01dc` (fix commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Fix improves UX accuracy. No scope creep.

## Issues Encountered

- Initial plan called for `RelativeDateTimeFormatter` and `.plain` button style; both required adjustments during implementation before human verification. Fix was contained to a single follow-up commit.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Panel now shows reliable last-updated feedback and supports manual refresh
- PANEL-10 and PANEL-11 requirements satisfied
- Phase 06 plan 01 complete — ready for any remaining phase 06 plans or phase 07 (OAuth refresh)

---
*Phase: 06-ux-improvements*
*Completed: 2026-04-02*
