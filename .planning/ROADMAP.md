# Roadmap: Claude Mac Widget

## Overview

Four phases that build from the inside out: first a working macOS app shell with verified API access and credential reading, then live polling with menu bar display, then the full dropdown panel, then launch-readiness polish. Each phase delivers something runnable and independently testable before the next phase begins.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Working app shell, Keychain credential read, API endpoint verified
- [ ] **Phase 2: Live Data** - 60-second polling engine, live usage percentage in menu bar
- [ ] **Phase 3: Dropdown Panel** - Full panel UI with daily/weekly meters, reset countdown, error state
- [ ] **Phase 4: Launch Readiness** - Launch at Login, clean quit, adaptive icon behavior

## Phase Details

### Phase 1: Foundation
**Goal**: Users have a running macOS app that reads Claude Code credentials and confirms usage data is retrievable
**Depends on**: Nothing (first phase)
**Requirements**: AUTH-01, AUTH-02, LIFE-01, LIFE-02
**Success Criteria** (what must be TRUE):
  1. App launches with no Dock icon and a placeholder "—%" visible in the menu bar
  2. App reads the Claude Code OAuth token from macOS Keychain without prompting the user for credentials
  3. App falls back to reading `~/.claude/.credentials.json` when the Keychain entry is absent
  4. A test API call to the Anthropic usage endpoint succeeds and returns parseable usage data
  5. Dropdown includes a functional Quit menu item that fully exits the app
**Plans**: 3 plans
**UI hint**: yes

Plans:
- [x] 01-01-PLAN.md — Xcode project scaffold: Info.plist (LSUIElement), entitlements, AppDelegate, StatusBarController with —% and Quit
- [x] 01-02-PLAN.md — Credential reading: KeychainService (claudeAiOauth wrapper), CredentialsService (file fallback), UsageStore (@Observable)
- [x] 01-03-PLAN.md — API verification: UsageResponse Codable models, AnthropicAPIClient, wire fetchUsage into UsageStore

### Phase 2: Live Data
**Goal**: Users see their current Claude Code usage percentage update automatically in the menu bar
**Depends on**: Phase 1
**Requirements**: POLL-01, POLL-02, DISP-01
**Success Criteria** (what must be TRUE):
  1. Menu bar displays the current usage percentage (e.g. "42%") updated from live API data
  2. Usage percentage refreshes every 60 seconds without any user action
  3. Menu bar shows "—" when the API is unreachable or returns an error, and the app does not crash
**Plans**: 1 plan

Plans:
- [x] 02-01-PLAN.md — Polling loop in UsageStore (startPolling/stopPolling), AppDelegate lifecycle wiring, "—" error display

### Phase 3: Dropdown Panel
**Goal**: Users can open the dropdown and see full daily/weekly usage detail with reset timing and error context
**Depends on**: Phase 2
**Requirements**: PANEL-01, PANEL-02, PANEL-03, PANEL-04
**Success Criteria** (what must be TRUE):
  1. Dropdown panel shows daily usage and daily limit with a visible progress bar
  2. Dropdown panel shows weekly usage and weekly limit with a visible progress bar
  3. Dropdown panel shows time remaining until the usage limit resets
  4. Dropdown panel shows a clear error state when the app is offline or authentication has failed
**Plans**: 1 plan

Plans:
- [x] 03-01-PLAN.md — UsagePanelView (SwiftUI daily/weekly meters, reset countdowns, error state, Quit button) wired into NSPopover via NSHostingController

### Phase 4: Launch Readiness
**Goal**: The app behaves correctly as a permanent background utility — starts on login, exits cleanly
**Depends on**: Phase 3
**Requirements**: LIFE-03
**Success Criteria** (what must be TRUE):
  1. User can toggle Launch at Login from within the app and the setting persists across reboots
  2. Quitting the app stops all background polling and the menu bar icon disappears cleanly
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/3 | Complete |  |
| 2. Live Data | 0/1 | In Progress | - |
| 3. Dropdown Panel | 0/1 | Not started | - |
| 4. Launch Readiness | 0/TBD | Not started | - |
