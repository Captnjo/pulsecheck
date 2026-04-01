# Feature Research

**Domain:** macOS menu bar utility app — API usage monitor (Claude Code limits)
**Researched:** 2026-04-02
**Confidence:** HIGH (multiple verified sources including direct competitor analysis)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Usage percentage in menu bar icon/label | The entire value prop — glanceable at all times | LOW | Text label is acceptable; icon with text is standard for this class of app |
| Dropdown panel with daily usage + limit | Users expect to click for more detail | LOW | Standard menu bar popover/menu pattern |
| Dropdown panel with weekly usage + limit | Shows the scoped context beyond daily view | LOW | Map to API response fields directly |
| Limit reset time / countdown | Knowing when limits refresh is critical for planning | LOW | Timestamp or countdown; competitors show both |
| Secure API key storage (Keychain) | Users will not accept plaintext credential storage | MEDIUM | macOS Keychain via `SecItemAdd`; well-trodden pattern |
| First-run setup / onboarding flow | App is useless without API key; must collect it gracefully | MEDIUM | Sheet or window on first launch; must validate key before saving |
| Visual warning when approaching limits | Users need proactive signal before they hit a wall | LOW | Color change (green/yellow/red) is the established convention; see cctray, Claude Usage Tracker |
| "Quit" menu item | Without a Dock icon, users must have another way to quit | LOW | Apple HIG and developer community both flag this as required |
| Launch at Login toggle (opt-in) | Utility apps are expected to survive reboots | LOW | `SMAppService` on macOS 13+; must be opt-in per App Review Guidelines |
| Adaptive icon for light/dark menu bar | Template image auto-tints; colored icon looks broken in dark mode | LOW | Set `isTemplate = true` on NSImage; 16x16pt at 1x/2x |
| No Dock icon (LSUIElement) | Menu bar apps must not appear in Dock or App Switcher | LOW | `LSUIElement = YES` in Info.plist |
| Auto-refresh / polling | Data must stay fresh without manual action | LOW | 60-second interval is the project's stated target; competitors use 30–60s |
| Error state handling | Network errors and API failures must not silently break the display | MEDIUM | Show last-known-good data + timestamp, or explicit error state in label |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Anthropic API as data source (not ccusage CLI) | Competitors (cctray, ccusage-monitor) depend on the ccusage CLI tool being installed — a friction point for non-developers. API-first removes that dependency entirely | MEDIUM | Requires Anthropic API having a usage endpoint; this is the stated approach |
| Distinct daily vs weekly limit panels side by side | Some competitors conflate the two; showing both simultaneously reduces cognitive load | LOW | Layout decision in popover design |
| Last-updated timestamp in dropdown | Users want to know how stale the displayed data is | LOW | Single line below metrics; "Updated 23s ago" pattern |
| Manual refresh action | Power users want to force-poll without waiting 60s | LOW | "Refresh" menu item or keyboard shortcut; ccusage-monitor uses ⌘R |
| Clear threshold configuration | Let the user define when yellow/red warnings trigger | MEDIUM | Preferences panel with percentage sliders; Claude Usage Tracker does this well |
| Native SwiftUI popover (not CLI dependency) | Faster, lighter, works without Homebrew/Node installed | HIGH relative to competitors | This is the architecture advantage of building native; requires direct API integration |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Historical usage charts | "I want to see my usage over time" | Requires local persistence, data modeling, and charting UI — multiplies scope for v1; competitors who added it (Claude Usage Tracker) have significantly more code complexity | Defer to v2; v1 shows current-state only as scoped in PROJECT.md |
| Multi-account / multi-profile support | Power users have multiple Anthropic accounts | Requires credential management, profile switching UI, and separate polling per account — large surface area | Single account for v1; add profiles only if user feedback validates the need |
| Push notifications for threshold breaches | "Alert me when I hit 80%" | macOS notification permissions are a friction point; users often deny them; the glanceable menu bar icon already serves this purpose via color coding | Color-coded icon + optional system notification toggle; don't make it the primary alert mechanism |
| Auto-pause / auto-action on limit | "Stop my Claude Code session when I hit 90%" | Requires process management, shell integration, or AppleScript — well outside scope of a display-only utility | Not applicable; this app is read-only by design |
| WidgetKit / Notification Center widget | Useful secondary surface | Extension sandboxing complicates Keychain access; requires separate target and approval flow | Already scoped out in PROJECT.md; revisit only if menu bar proves insufficient |
| Rotating display metrics | Cycling between cost/burn-rate/time in the menu bar label | Adds visual noise; forces the user to wait for the metric they want to appear | Show most critical metric (percentage) persistently; put secondary metrics in the dropdown |

## Feature Dependencies

```
[Keychain API Key Storage]
    └──requires──> [First-Run Setup Flow]
                       └──required by──> [All Data Display Features]

[Usage Percentage Display]
    └──requires──> [Anthropic API Polling]
                       └──requires──> [Keychain API Key Storage]

[Warning Color Change]
    └──enhances──> [Usage Percentage Display]

[Threshold Configuration] ──enhances──> [Warning Color Change]

[Last-Updated Timestamp] ──enhances──> [Usage Percentage Display]

[Manual Refresh] ──enhances──> [Auto-Polling]

[Launch at Login] ──independent of──> [All Data Display Features]
```

### Dependency Notes

- **All display features require Keychain storage:** Without a stored API key, no API calls can be made. First-run setup is the unblocking step for everything downstream.
- **Warning color change enhances display:** Color thresholds are additive — the base percentage display works without them, but the user experience is meaningfully better with them.
- **Threshold configuration enhances warnings:** The color warning is useful with hardcoded defaults (e.g., 75% = yellow, 90% = red); making it configurable is a v1.x enhancement, not a v1 blocker.
- **Launch at Login is independent:** Can be added any time; no data dependencies.

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] Menu bar label showing usage percentage — core value prop
- [ ] Dropdown panel: daily usage / daily limit, weekly usage / weekly limit, reset time — reason to open the app
- [ ] Anthropic API polling every 60 seconds — keeps data fresh
- [ ] Keychain storage for API key — security non-negotiable
- [ ] First-run setup flow — app cannot function without it
- [ ] Green / yellow / red color coding on percentage label — proactive signal without notifications
- [ ] Adaptive template icon / label (light + dark mode) — polish that marks the app as native
- [ ] LSUIElement (no Dock icon) — correct menu bar app behavior
- [ ] Quit menu item — users must be able to exit
- [ ] Error state in label (e.g., "--" or "ERR") — graceful degradation on API failure
- [ ] Launch at Login toggle in preferences — expected by all utility app users

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Last-updated timestamp in dropdown — add when users report uncertainty about data freshness
- [ ] Manual refresh action (⌘R or menu item) — add when users report wanting immediate refresh
- [ ] Configurable warning thresholds — add when users report the defaults don't fit their workflow
- [ ] System notification on threshold breach — add if color coding alone proves insufficient

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Usage history charts — significant persistence + UI work; defer until users explicitly request trend data
- [ ] Multi-account / profile support — defer; single-account covers the vast majority of users
- [ ] Keyboard shortcut to open panel — nice for power users; not blocking
- [ ] CSV/JSON export — only relevant after history tracking exists

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Usage percentage in menu bar | HIGH | LOW | P1 |
| Daily + weekly usage in dropdown | HIGH | LOW | P1 |
| Reset time display | HIGH | LOW | P1 |
| Keychain API key storage | HIGH | MEDIUM | P1 |
| First-run setup flow | HIGH | MEDIUM | P1 |
| Color-coded warning (green/yellow/red) | HIGH | LOW | P1 |
| Adaptive icon (template image) | MEDIUM | LOW | P1 |
| LSUIElement / no Dock icon | MEDIUM | LOW | P1 |
| Quit menu item | MEDIUM | LOW | P1 |
| Launch at Login toggle | MEDIUM | LOW | P1 |
| Error state display | MEDIUM | MEDIUM | P1 |
| Last-updated timestamp | MEDIUM | LOW | P2 |
| Manual refresh | MEDIUM | LOW | P2 |
| Configurable thresholds | MEDIUM | MEDIUM | P2 |
| System notifications | LOW | MEDIUM | P2 |
| Usage history charts | LOW | HIGH | P3 |
| Multi-account support | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

Three direct competitors were identified during research — all are open source and Claude-specific:

| Feature | cctray (goniszewski) | Claude Usage Tracker (hamed-elfayome) | ccusage-monitor (joachimBrindeau) | Our Approach |
|---------|---------------------|---------------------------------------|-----------------------------------|--------------|
| Data source | ccusage CLI (Node.js) | Anthropic API direct | ccusage CLI (Node.js) | Anthropic API direct |
| Menu bar display | Circular progress + rotating metrics | 5 icon style options (battery, bar, %) | Percentage + time remaining | Percentage text label |
| Dropdown detail | Progress bars, trend arrows, sparklines | Session/weekly/Opus breakdown | Tokens, time, cost | Daily + weekly + reset time |
| Color coding | Green/yellow/red thresholds | 3 color modes + 6-tier pace system | Not explicitly mentioned | Green/yellow/red thresholds |
| Launch at login | Yes | Yes | Yes (default on) | Yes (default off per Apple guidelines) |
| Preferences window | Yes, 4-tab | Yes | Minimal | Yes, focused |
| Notifications | Toggle critical alerts | Threshold-based + customizable % | Not mentioned | Color coding primary, notification optional |
| Keychain storage | Not mentioned | Yes | Not mentioned | Yes |
| Multi-account | No | Yes (unlimited) | No | No (v1) |
| History / charts | Sparklines (recent) | Full history + JSON/CSV export | No | No (v1) |
| Language | Swift | Swift/SwiftUI | Swift 5.5 / Cocoa | Swift/SwiftUI |
| CLI dependency | Yes (Node.js + ccusage) | No | Yes (ccusage) | No |
| Code-signed | Not mentioned | Yes | Not mentioned | Yes (local distribution) |

**Key differentiation opportunity:** Two of three competitors require the ccusage CLI (Node.js + Homebrew). Our Anthropic-API-direct approach eliminates that friction entirely. This is a meaningful installation advantage for users who are not developers or who manage a clean system environment.

## Sources

- [cctray — macOS menu bar app for Claude Code usage (GitHub)](https://github.com/goniszewski/cctray)
- [Claude Usage Tracker — native macOS menu bar app (GitHub)](https://github.com/hamed-elfayome/Claude-Usage-Tracker)
- [ccusage-monitor — ultra-minimal Claude API monitor (GitHub)](https://github.com/joachimBrindeau/ccusage-monitor)
- [What I Learned Building a Native macOS Menu Bar App (Medium, Jan 2026)](https://medium.com/@p_anhphong/what-i-learned-building-a-native-macos-menu-bar-app-eacbc16c2e14)
- [DEV Community: What I Learned Building a Native macOS Menu Bar App](https://dev.to/heocoi/what-i-learned-building-a-native-macos-menu-bar-app-4im6)
- [Designing macOS menu bar extras — Bjango](https://bjango.com/articles/designingmenubarextras/)
- [Add launch at login setting to a macOS app — nilcoalescing.com](https://nilcoalescing.com/blog/LaunchAtLoginSetting/)
- [Apple Human Interface Guidelines: The Menu Bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
- [iStat Menus — Bjango (reference for mature menu bar utility patterns)](https://bjango.com/mac/istatmenus/)

---
*Feature research for: macOS menu bar utility — Claude Code usage monitor*
*Researched: 2026-04-02*
