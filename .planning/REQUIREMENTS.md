# Requirements: Claude Mac Widget

**Defined:** 2026-04-02
**Milestone:** v1.1 Polish & Resilience
**Core Value:** Instant visibility into Claude Code usage limits without leaving the desktop

## v1.1 Requirements

### Visual Polish

- [x] **DISP-11**: Menu bar uses adaptive template icon that auto-tints for light/dark mode

### UX Improvements

- [x] **PANEL-10**: Panel shows "Last updated X minutes ago" relative timestamp that auto-refreshes
- [x] **PANEL-11**: Panel has a manual refresh button that triggers an immediate poll

### Auth Resilience

- [x] **AUTH-10**: App refreshes expired OAuth tokens using refresh_token grant when Claude Code hasn't already refreshed them, storing refreshed tokens in a PulseCheck-owned shadow Keychain item

## Future Requirements

### Display Enhancements

- **DISP-10**: Color-coded menu bar text (green/yellow/red based on usage thresholds)
- **DISP-12**: Configurable warning thresholds

## Out of Scope

| Feature | Reason |
|---------|--------|
| Color-coded menu bar text | Deferred — not needed for v1.1 |
| Configurable thresholds | Depends on color-coded text |
| WidgetKit integration | Menu bar app is simpler and more flexible |
| Historical usage charts | Current status only |
| Multi-account support | Single-purpose tool for personal use |
| Settings window | SettingsLink broken in NSPopover on macOS Tahoe; inline settings if needed |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISP-11 | Phase 5 | Complete |
| PANEL-10 | Phase 6 | Complete |
| PANEL-11 | Phase 6 | Complete |
| AUTH-10 | Phase 7 | Complete |

**Coverage:**
- v1.1 requirements: 4 total
- Mapped to phases: 4
- Unmapped: 0

---
*Requirements defined: 2026-04-02*
