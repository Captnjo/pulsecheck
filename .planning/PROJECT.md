# Claude Mac Widget

## What This Is

A macOS menu bar app that displays Claude Code usage data at a glance. Shows a live usage percentage in the menu bar with a dropdown panel containing daily/weekly usage meters with progress bars, limit reset countdowns, and error states. Polls the Anthropic API every 60 seconds for fresh data. Supports Launch at Login for always-on visibility.

## Core Value

Instant visibility into Claude Code usage limits without leaving the desktop.

## Requirements

### Validated

- ✓ App reads Claude Code OAuth token from macOS Keychain on launch — v1.0 (AUTH-01)
- ✓ Menu bar shows current usage percentage as text — v1.0 (DISP-01)
- ✓ App polls Anthropic usage endpoint every 60 seconds — v1.0 (POLL-01)
- ✓ App handles network errors gracefully without crashing — v1.0 (POLL-02)
- ✓ Panel shows daily usage with progress bar — v1.0 (PANEL-01)
- ✓ Panel shows weekly usage with progress bar — v1.0 (PANEL-02)
- ✓ Panel shows time remaining until limit resets — v1.0 (PANEL-03)
- ✓ Panel shows error state when offline or auth fails — v1.0 (PANEL-04)
- ✓ App runs as LSUIElement (no Dock icon) — v1.0 (LIFE-01)
- ✓ Dropdown includes Quit menu item — v1.0 (LIFE-02)
- ✓ Launch at Login via SMAppService — v1.0 (LIFE-03)

### Active

- [ ] Adaptive template icon for light/dark mode
- [ ] Last-updated timestamp in dropdown
- [ ] Manual refresh button in dropdown
- [ ] Auto-refresh expired OAuth tokens (shadow Keychain item)

### Out of Scope

- WidgetKit / Notification Center widget — menu bar app is simpler and more flexible
- Other data sources (weather, calendar, etc.) — single-purpose tool
- iOS / iPad companion — macOS only
- Historical usage charts — v1 is current status only
- Multi-account support — single-purpose tool for personal use
- File-based credential fallback — removed in v1.0 tech debt cleanup; Keychain is the only path

## Current Milestone: v1.1 Polish & Resilience

**Goal:** Adaptive visuals, better UX feedback, and self-healing auth

**Target features:**
- Adaptive template icon for light/dark mode
- Last-updated timestamp in dropdown
- Manual refresh button in dropdown
- Auto-refresh expired OAuth tokens (shadow Keychain item)

## Context

Shipped v1.0 with 535 LOC Swift across 9 source files.
Tech stack: Swift 6.1, SwiftUI, AppKit (NSStatusItem + NSPopover), URLSession async/await.
Uses undocumented Anthropic OAuth endpoint (`/api/oauth/usage`) — may break without notice.
Keychain service name: `Claude Code-credentials` (reads Claude Code's own OAuth token).
App Sandbox enabled with network client entitlement.

## Constraints

- **Platform**: macOS 13.0+ only, SwiftUI + AppKit for menu bar integration
- **API**: Depends on undocumented Anthropic OAuth usage endpoint
- **Polling**: 60-second interval with exponential backoff on 429
- **Distribution**: Run locally, no App Store requirement

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Menu bar app over WidgetKit | Easier to build, more flexible layout, no extension sandboxing | ✓ Good — shipped cleanly |
| NSStatusItem + NSPopover over MenuBarExtra | Programmatic show/hide and title updates require it | ✓ Good — full control over popover behavior |
| Undocumented /api/oauth/usage endpoint | Only viable path for personal Pro/Max accounts; official analytics API is org-admin-only | ⚠ Revisit — fragile, may break |
| Keychain-only credentials (no file fallback) | File fallback silently fails under App Sandbox; Keychain is reliable | ✓ Good — simplified in tech debt cleanup |
| 60-second polling with Task.sleep | Near real-time without excessive API calls; structured concurrency | ✓ Good |
| Single-purpose (Claude only) | Keep it focused and ship fast | ✓ Good |
| fiveHour as primary display metric | API returns fiveHour and sevenDay; fiveHour is the active rate limit | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-02 after v1.1 milestone start*
