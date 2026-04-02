# Roadmap: Claude Mac Widget

## Overview

macOS menu bar app showing Claude Code usage at a glance — live percentage, daily/weekly meters, reset countdowns.

## Milestones

- ✅ **v1.0 MVP** — Phases 1-4 (shipped 2026-04-02)
- **v1.1 Polish & Resilience** — Phases 5-7 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-4) — SHIPPED 2026-04-02</summary>

- [x] **Phase 1: Foundation** — Working app shell, Keychain credential read, API endpoint verified (3/3 plans)
- [x] **Phase 2: Live Data** — 60-second polling engine, live usage percentage in menu bar (1/1 plans)
- [x] **Phase 3: Dropdown Panel** — Full panel UI with daily/weekly meters, reset countdown, error state (1/1 plans)
- [x] **Phase 4: Launch Readiness** — Launch at Login, clean quit, adaptive icon behavior (1/1 plans)

See: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md) for full details.

</details>

### v1.1 Polish & Resilience

- [ ] **Phase 5: Visual Polish** — Adaptive template icon that works correctly in light and dark mode
- [ ] **Phase 6: UX Improvements** — Last-updated timestamp and manual refresh button in the dropdown panel
- [ ] **Phase 7: Auth Resilience** — Automatic OAuth token refresh using shadow Keychain item

## Phase Details

### Phase 5: Visual Polish
**Goal**: The menu bar icon looks correct in both light and dark mode without user configuration
**Depends on**: Nothing (additive change to StatusBarController only)
**Requirements**: DISP-11
**Success Criteria** (what must be TRUE):
  1. Menu bar icon appears as a dark symbol on a light menu bar and a light symbol on a dark menu bar
  2. Icon appearance updates immediately when the user switches between light and dark mode without relaunching the app
  3. Icon does not appear tinted or colored when the popover is closed
**Plans**: 1 plan
Plans:
- [x] 05-01-PLAN.md — Add isTemplate flag and verify light/dark mode rendering
**UI hint**: yes

### Phase 6: UX Improvements
**Goal**: Users can see how stale the panel data is and trigger an immediate refresh on demand
**Depends on**: Phase 5
**Requirements**: PANEL-10, PANEL-11
**Success Criteria** (what must be TRUE):
  1. Panel shows a relative "Updated X minutes ago" timestamp that updates automatically without user interaction
  2. Timestamp reflects the most recent successful API fetch, not the app launch time
  3. Panel has a Refresh button that triggers an immediate API fetch when tapped
  4. Tapping Refresh while a fetch is already in progress does not trigger a second concurrent request
  5. After a manual refresh completes, the 60-second polling countdown restarts from zero
**Plans**: TBD
**UI hint**: yes

### Phase 7: Auth Resilience
**Goal**: The app continues fetching usage data beyond the ~8-hour access token lifetime without requiring the user to re-authenticate
**Depends on**: Phase 6
**Requirements**: AUTH-10
**Success Criteria** (what must be TRUE):
  1. App silently obtains a new access token when the current token has expired, with no visible error to the user
  2. Refreshed tokens are stored in a PulseCheck-owned Keychain item and used for subsequent requests; Claude Code's Keychain item is never modified
  3. If two refresh attempts happen concurrently (polling loop + manual refresh), only one network request goes out and both callers receive the same result
  4. If token refresh fails, the app shows an auth error state rather than silently returning stale data
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-04-02 |
| 2. Live Data | v1.0 | 1/1 | Complete | 2026-04-02 |
| 3. Dropdown Panel | v1.0 | 1/1 | Complete | 2026-04-02 |
| 4. Launch Readiness | v1.0 | 1/1 | Complete | 2026-04-02 |
| 5. Visual Polish | v1.1 | 0/1 | Not started | - |
| 6. UX Improvements | v1.1 | 0/? | Not started | - |
| 7. Auth Resilience | v1.1 | 0/? | Not started | - |
