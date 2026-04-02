# Claude Mac Widget

## What This Is

A macOS menu bar app that displays Claude Code usage data at a glance. Shows a usage percentage in the menu bar with a dropdown panel containing daily limit, weekly limit, and limit reset time. Polls the Anthropic API every minute for fresh data.

## Core Value

Instant visibility into Claude Code usage limits without leaving the desktop.

## Requirements

### Validated

- ✓ Secure API key storage (macOS Keychain) — Phase 1
- ✓ Menu bar icon with usage percentage text — Phase 1 (single fetch on launch)

### Active

- [ ] Dropdown panel showing daily usage / daily limit
- [ ] Dropdown panel showing weekly usage / weekly limit
- [ ] Dropdown panel showing limit reset time (countdown or timestamp)
- [ ] Polls Anthropic API every 60 seconds for usage data
- [ ] Visual indicator when approaching limits (color change or warning)

### Out of Scope

- WidgetKit / Notification Center widget — menu bar app is simpler and more flexible
- Other data sources (weather, calendar, etc.) — single-purpose tool
- iOS / iPad companion — macOS only
- Historical usage charts — v1 is current status only

## Context

- Inspired by the Waveshare ePaper dashboard project (czuryk/Waveshare-ePaper-10.85-dashboard) which includes a Claude Code usage widget among other data sources
- Built as a native macOS app using Swift/SwiftUI
- Data comes from the Anthropic API usage endpoint
- Must handle API auth securely — Keychain for token storage
- Menu bar apps are a well-established macOS pattern (e.g., iStat Menus, Bartender)

## Constraints

- **Platform**: macOS only, SwiftUI + AppKit for menu bar integration
- **API**: Depends on Anthropic API having a usage/limits endpoint
- **Polling**: 60-second interval, must handle rate limits and network errors gracefully
- **Distribution**: Run locally, no App Store requirement for v1

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Menu bar app over WidgetKit | Easier to build, more flexible layout, no extension sandboxing | — Pending |
| Anthropic API for data | Direct, reliable, structured data vs scraping | — Pending |
| 60-second polling interval | Near real-time without excessive API calls | — Pending |
| Single-purpose (Claude only) | Keep it focused and ship fast | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-02 after Phase 1 completion*
