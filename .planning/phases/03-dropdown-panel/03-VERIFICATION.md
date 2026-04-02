---
phase: 03-dropdown-panel
verified: 2026-04-02T12:39:45Z
status: human_needed
score: 6/7 must-haves verified
re_verification: false
human_verification:
  - test: "Left-click menu bar item opens the popover panel (not a menu)"
    expected: "Panel slides down from menu bar item showing usage sections and Quit button"
    why_human: "NSPopover open/close behavior and popover.behavior = .transient cannot be confirmed by static analysis or build alone; requires runtime interaction"
  - test: "Clicking outside the popover dismisses it"
    expected: "Panel disappears when clicking anywhere outside it"
    why_human: "NSPopover transient behavior verified in code but only observable at runtime"
  - test: "Error state renders correctly when usageResponse is nil"
    expected: "Warning triangle icon plus error message text visible in panel; no crash"
    why_human: "Requires triggering an actual fetch failure (e.g. no network) and observing the running app"
  - test: "Progress bars are visually filled proportionally to utilization value"
    expected: "ProgressView bars show correct fill level matching the displayed percentage"
    why_human: "SwiftUI ProgressView rendering and visual correctness requires runtime observation"
---

# Phase 3: Dropdown Panel Verification Report

**Phase Goal:** Users can open the dropdown and see full daily/weekly usage detail with reset timing and error context
**Verified:** 2026-04-02T12:39:45Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Clicking the menu bar item opens a popover panel | ? NEEDS HUMAN | `togglePopover` wired to `button.sendAction(on: .leftMouseUp)`; no `statusItem.menu` present; confirmed at runtime by human (Task 3: approved) |
| 2 | Panel shows daily (five_hour) usage percentage and a filled progress bar | ✓ VERIFIED | `usageSection(title: "Daily (5h window)", period: response.fiveHour)` renders `displayString` and `ProgressView(value: period.utilization / 100.0)` |
| 3 | Panel shows weekly (seven_day) usage percentage and a filled progress bar | ✓ VERIFIED | `usageSection(title: "Weekly (7-day window)", period: response.sevenDay)` renders same structure |
| 4 | Panel shows time remaining until each period resets (e.g. "Resets in 2h 15m") | ✓ VERIFIED | `resetCountdown(from:)` parses ISO 8601 with fractional-seconds fallback; `countdownString(to:)` produces "Resets in Xh Ym at H:MMam/pm"; user-requested absolute time included |
| 5 | Panel shows a clear error message with icon when usageError is non-nil or usageResponse is nil | ✓ VERIFIED | `errorState()` branch renders `exclamationmark.triangle` SF Symbol at 24pt and `store.usageError?.localizedDescription ?? "No data available"` |
| 6 | Panel has a Quit button at the bottom that exits the app | ✓ VERIFIED | `quitButton()` calls `NSApplication.shared.terminate(nil)` present in both `normalState` and `errorState` branches |
| 7 | Popover closes when clicking outside it (transient behavior) | ? NEEDS HUMAN | `popover.behavior = .transient` set in `StatusBarController.init()`; runtime confirmation required |

**Score:** 5/5 programmatically verifiable truths confirmed; 2 require human runtime verification.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ClaudeUsage/Views/UsagePanelView.swift` | SwiftUI panel with daily/weekly meters, reset countdowns, error state, quit button | ✓ VERIFIED | 109 lines; both `normalState` and `errorState` fully implemented; `resetCountdown` helper present with fractional-seconds ISO 8601 fallback |
| `ClaudeUsage/StatusBarController.swift` | Popover wired to NSHostingController(rootView: UsagePanelView) | ✓ VERIFIED | 43 lines; `setStore(_:)` creates `NSHostingController`, assigns to `popover.contentViewController`; no `buildMenu` or `statusItem.menu` present |
| `ClaudeUsage/AppDelegate.swift` | UsageStore passed into StatusBarController for panel binding | ✓ VERIFIED | `statusBarController.setStore(usageStore)` called immediately after `StatusBarController()` construction |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `AppDelegate.swift` | `StatusBarController.swift` | `setStore(_ store: UsageStore)` | ✓ WIRED | Line 11: `statusBarController.setStore(usageStore)` present and called in `applicationDidFinishLaunching` |
| `StatusBarController.swift` | `UsagePanelView.swift` | `NSHostingController(rootView: UsagePanelView(store: store))` | ✓ WIRED | Lines 28-31: `NSHostingController(rootView: panelView)` with `popover.contentViewController = hosting` |
| `UsagePanelView.swift` | `UsageStore.usageResponse / usageError` | `@Observable` store observation via direct property access | ✓ WIRED | Lines 9, 59: `store.usageResponse` and `store.usageError` read directly in `body`; `UsageStore` is `@Observable` so observation is automatic |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| `UsagePanelView.swift` | `store.usageResponse` | `UsageStore.fetchUsage()` → `AnthropicAPIClient.fetchUsage(accessToken:)` → live HTTP request | Yes — live API call; `prisma`-equivalent is `AnthropicAPIClient` returning decoded `UsageResponse` | ✓ FLOWING |
| `UsagePanelView.swift` | `store.usageError` | `UsageStore.fetchUsage()` failure path sets `self.usageError = error` | Yes — real network/auth errors populate the field | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Build compiles cleanly | `xcodebuild -scheme ClaudeUsage -destination "platform=macOS" build` | `** BUILD SUCCEEDED **` | ✓ PASS |
| `resetCountdown` parses ISO 8601 with fractional seconds | Code review: `formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]` with fallback | Both paths present | ✓ PASS |
| Popover left-click wiring | `button.sendAction(on: [.leftMouseUp])` in StatusBarController.init() | Confirmed in source | ✓ PASS |
| Error state: no crash path | `errorState()` branch has no force-unwraps; uses nil coalescing | Confirmed in source | ✓ PASS |
| Runtime panel appearance/interaction | Requires running app | N/A | ? SKIP — needs human |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PANEL-01 | 03-01-PLAN.md | Panel shows daily usage out of daily limit with progress bar | ✓ SATISFIED | `usageSection(title: "Daily (5h window)", period: response.fiveHour)` renders `ProgressView(value: period.utilization / 100.0)` with `.progressViewStyle(.linear)` |
| PANEL-02 | 03-01-PLAN.md | Panel shows weekly usage out of weekly limit with progress bar | ✓ SATISFIED | `usageSection(title: "Weekly (7-day window)", period: response.sevenDay)` renders same `ProgressView` structure |
| PANEL-03 | 03-01-PLAN.md | Panel shows time remaining until limit resets | ✓ SATISFIED | `resetCountdown(from:)` produces "Resets in Xh Ym at H:MMam/pm"; enhanced beyond spec with absolute time per user request |
| PANEL-04 | 03-01-PLAN.md | Panel shows error state when offline or auth fails | ✓ SATISFIED | `errorState()` branch shows `exclamationmark.triangle` at 24pt and `store.usageError?.localizedDescription ?? "No data available"` |

No orphaned requirements: REQUIREMENTS.md maps PANEL-01 through PANEL-04 to Phase 3, all four are claimed by 03-01-PLAN.md, all four are implemented.

### Anti-Patterns Found

None. No TODOs, FIXMEs, placeholders, empty handler stubs, or hardcoded empty arrays/objects found in any of the three modified files.

### Human Verification Required

#### 1. Popover Opens on Left-Click

**Test:** Build and run the app (Cmd+R in Xcode). Left-click the menu bar item.
**Expected:** A popover panel appears below the menu bar item showing "Daily (5h window)" and "Weekly (7-day window)" sections with progress bars, reset countdown text, and a Quit button at the bottom.
**Why human:** NSPopover show/hide is a runtime behavior; static analysis confirms the wiring code is present but cannot verify macOS actually delivers the left-click event to `togglePopover`.

#### 2. Popover Dismisses on Outside Click

**Test:** With the popover open, click anywhere outside it.
**Expected:** The panel dismisses automatically without needing to click the menu bar item again.
**Why human:** `popover.behavior = .transient` is set in code, but macOS event routing for transient popovers can only be confirmed by interaction.

#### 3. Error State Renders When Offline

**Test:** Disable network (or wait for a failed poll). Open the panel.
**Expected:** The `exclamationmark.triangle` icon and an error message (e.g. network error description) appear instead of the usage sections.
**Why human:** Requires intentionally triggering a fetch failure and observing the app state.

#### 4. Progress Bars Visually Correct

**Test:** Open the panel when live usage data is loaded.
**Expected:** The colored fill in each `ProgressView` is visually proportional to the displayed percentage (e.g. a 51% bar is roughly half-filled).
**Why human:** SwiftUI rendering fidelity requires visual inspection.

### Gaps Summary

No code gaps found. All four artifacts exist, are substantive (no stubs or placeholders), are wired end-to-end, and data flows from a live API call through `UsageStore` into the panel view. The build compiles cleanly with no errors or warnings beyond the expected `appintentsmetadataprocessor` advisory.

The SUMMARY notes an approved human checkpoint (Task 3) was completed during execution. The four human verification items above confirm aspects of runtime appearance and interaction that static analysis cannot cover, but the automated evidence is fully consistent with the goal being achieved.

---

_Verified: 2026-04-02T12:39:45Z_
_Verifier: Claude (gsd-verifier)_
