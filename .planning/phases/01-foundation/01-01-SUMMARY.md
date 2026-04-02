---
phase: 01-foundation
plan: 01
subsystem: ui
tags: [appkit, nsstatus-item, nspopover, menu-bar, macos]

requires:
  - phase: none
    provides: greenfield
provides:
  - Xcode project scaffold with LSUIElement
  - NSStatusItem with placeholder title
  - NSPopover for dropdown panel
  - Quit menu item
affects: [01-02, 01-03, all-future-phases]

tech-stack:
  added: [AppKit, SwiftUI]
  patterns: [NSStatusItem + NSPopover, AppDelegate lifecycle]

key-files:
  created:
    - ClaudeUsage.xcodeproj/project.pbxproj
    - ClaudeUsage/ClaudeUsageApp.swift
    - ClaudeUsage/AppDelegate.swift
    - ClaudeUsage/StatusBarController.swift
    - ClaudeUsage/Resources/Info.plist
    - ClaudeUsage/Resources/ClaudeUsage.entitlements
  modified: []

key-decisions:
  - "StatusBarController inherits NSObject for #selector support"
  - "Right-click for menu, left-click for popover"
  - "NSApp.setActivationPolicy(.accessory) for LSUIElement behavior"

patterns-established:
  - "AppDelegate owns StatusBarController as stored property"
  - "StatusBarController manages NSStatusItem lifetime"

requirements-completed: [LIFE-01, LIFE-02]

duration: 5min
completed: 2026-04-02
---

# Phase 1, Plan 01: App Shell Summary

**Xcode project scaffold with NSStatusItem showing —% in menu bar, NSPopover, and Quit via right-click menu**

## Performance

- **Duration:** ~5 min
- **Tasks:** 3 (2 auto + 1 checkpoint)
- **Files created:** 6

## Accomplishments
- Xcode project with LSUIElement=YES, no Dock icon
- NSStatusItem displays "—%" in menu bar
- Right-click shows Quit menu, left-click toggles popover
- Network entitlement in place for API calls
- Build succeeds with xcodebuild

## Task Commits

1. **Task 1: Create Xcode project with Info.plist and entitlements** - `add1367`
2. **Task 2: Implement AppDelegate and StatusBarController** - `b277653`
3. **Task 3: Checkpoint — human verified** - approved
4. **Fix: StatusBarController NSObject inheritance** - `af2cd19`

## Files Created/Modified
- `ClaudeUsage.xcodeproj/project.pbxproj` - Xcode project config
- `ClaudeUsage/ClaudeUsageApp.swift` - @main entry point with AppDelegate adaptor
- `ClaudeUsage/AppDelegate.swift` - Creates StatusBarController on launch
- `ClaudeUsage/StatusBarController.swift` - NSStatusItem + NSPopover + quit menu
- `ClaudeUsage/Resources/Info.plist` - LSUIElement=YES, bundle ID
- `ClaudeUsage/Resources/ClaudeUsage.entitlements` - Network client entitlement

## Decisions Made
- StatusBarController needs NSObject inheritance for #selector — properties must init before super.init()

## Deviations from Plan

### Auto-fixed Issues

**1. StatusBarController missing NSObject inheritance**
- **Found during:** Post-checkpoint build verification
- **Issue:** #selector requires NSObject base class; init ordering required properties before super.init()
- **Fix:** Added `: NSObject`, reordered init
- **Committed in:** af2cd19

---

**Total deviations:** 1 auto-fixed
**Impact on plan:** Necessary for correctness. No scope creep.

## Issues Encountered
None beyond the NSObject fix above.

## Next Phase Readiness
- StatusBarController.updateTitle(_:) ready for credential/API status updates
- AppDelegate ready for UsageStore integration in Plan 01-02

---
*Phase: 01-foundation*
*Completed: 2026-04-02*
