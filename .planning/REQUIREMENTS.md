# Requirements: Claude Mac Widget

**Defined:** 2026-04-02
**Core Value:** Instant visibility into Claude Code usage limits without leaving the desktop

## v1 Requirements

### Authentication

- [x] **AUTH-01**: App reads Claude Code OAuth token from macOS Keychain on launch
- [x] **AUTH-02**: App falls back to reading `~/.claude/.credentials.json` if Keychain entry not found

### Menu Bar Display

- [x] **DISP-01**: Menu bar shows icon with current usage percentage as text

### Dropdown Panel

- [ ] **PANEL-01**: Panel shows daily usage out of daily limit with progress bar
- [ ] **PANEL-02**: Panel shows weekly usage out of weekly limit with progress bar
- [ ] **PANEL-03**: Panel shows time remaining until limit resets
- [ ] **PANEL-04**: Panel shows error state when offline or auth fails

### Polling

- [x] **POLL-01**: App polls Anthropic usage endpoint every 60 seconds in background
- [x] **POLL-02**: App handles network errors gracefully without crashing

### App Lifecycle

- [ ] **LIFE-01**: App runs as LSUIElement (no Dock icon)
- [ ] **LIFE-02**: Dropdown includes Quit menu item
- [ ] **LIFE-03**: App supports Launch at Login via SMAppService

## v2 Requirements

### Display Enhancements

- **DISP-10**: Color-coded menu bar text (green/yellow/red based on usage thresholds)
- **DISP-11**: Adaptive template icon for light/dark mode
- **DISP-12**: Configurable warning thresholds

### Panel Enhancements

- **PANEL-10**: Last-updated timestamp in dropdown
- **PANEL-11**: Manual refresh button in dropdown

### Authentication Enhancements

- **AUTH-10**: Auto-refresh expired OAuth tokens

## Out of Scope

| Feature | Reason |
|---------|--------|
| Historical usage charts | Complexity; v1 is current status only |
| Multi-account support | Single-purpose tool for personal use |
| WidgetKit integration | Menu bar app is simpler and more flexible |
| Rotating metrics in menu bar | Unnecessary complexity for single data source |
| Separate API key entry | Zero-config by reading Claude Code's own credentials |
| iOS / iPad companion | macOS only |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Complete |
| AUTH-02 | Phase 1 | Complete |
| LIFE-01 | Phase 1 | Pending |
| LIFE-02 | Phase 1 | Pending |
| POLL-01 | Phase 2 | Complete |
| POLL-02 | Phase 2 | Complete |
| DISP-01 | Phase 2 | Complete |
| PANEL-01 | Phase 3 | Pending |
| PANEL-02 | Phase 3 | Pending |
| PANEL-03 | Phase 3 | Pending |
| PANEL-04 | Phase 3 | Pending |
| LIFE-03 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-04-02*
*Last updated: 2026-04-02 after roadmap creation*
