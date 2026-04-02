---
phase: 03-dropdown-panel
plan: 01
subsystem: ui
tags: [swiftui, nspopover, nshostingcontroller, progressview, menu-bar]

requires:
  - phase: 02-live-data
    provides: UsageStore with polling, usageResponse, onTitleChanged
provides:
  - UsagePanelView SwiftUI panel with daily/weekly progress bars
  - Reset countdown with absolute time ("Resets in 2h 15m at 2:30pm")
  - Error state display with icon
  - Quit button in panel
affects: [04-launch-readiness]

tech-stack:
  added: [SwiftUI ProgressView, NSHostingController, ISO8601DateFormatter]
  patterns: [SwiftUI view hosted in NSPopover via NSHostingController]

key-files:
  created:
    - ClaudeUsage/Views/UsagePanelView.swift
  modified:
    - ClaudeUsage/StatusBarController.swift
    - ClaudeUsage/AppDelegate.swift

key-decisions:
  - "Removed statusItem.menu to unblock popover toggle on left-click"
  - "Quit button moved into SwiftUI panel (no more right-click menu)"
  - "Reset time shows both countdown and absolute time per user request"
  - "UsagePeriod.resetsAt is ISO 8601 string, parsed with fractional seconds fallback"

patterns-established:
  - "SwiftUI views observe @Observable UsageStore via direct property access"
  - "StatusBarController.setStore() creates NSHostingController and assigns to popover"

requirements-completed: [PANEL-01, PANEL-02, PANEL-03, PANEL-04]

duration: 10min
completed: 2026-04-02
---

# Phase 3, Plan 01: Dropdown Panel Summary

**SwiftUI popover panel with daily/weekly progress bars, reset countdowns with absolute time, error state, and quit button**

## Performance

- **Duration:** ~10 min
- **Tasks:** 3 (2 auto + 1 checkpoint)
- **Files created:** 1
- **Files modified:** 2

## Accomplishments
- UsagePanelView with Daily (5h) and Weekly (7-day) sections
- Linear ProgressView bars showing utilization percentage
- Reset countdown with absolute time ("Resets in 2h 15m at 2:30pm")
- Error state replaces content with warning icon + message
- Quit button at bottom of panel
- Removed NSMenu conflict that blocked popover toggle

## Task Commits

1. **Task 1: Create UsagePanelView.swift** - `7156449`
2. **Task 2: Wire into StatusBarController** - `e2babee`
3. **Task 3: Checkpoint — human verified** - approved
4. **Enhancement: Add absolute reset time** - `3ed52a2` (user request)

## Decisions Made
- Removed statusItem.menu entirely — Quit moved into SwiftUI panel
- Added "at HH:MMam/pm" after countdown per user request

## Deviations from Plan

### User-Requested Enhancement
- **Added absolute time to reset countdown** — user asked for "at 2:30pm" after the relative countdown
- Committed as `3ed52a2`

## Issues Encountered
None.

## Next Phase Readiness
- Panel complete, ready for Launch at Login in Phase 4

---
*Phase: 03-dropdown-panel*
*Completed: 2026-04-02*
