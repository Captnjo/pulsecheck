# Feature Landscape: v2.0 Polish & Resilience

**Domain:** macOS menu bar utility — Claude Code usage monitor
**Milestone:** v2.0 (visual polish, configurability, token resilience)
**Researched:** 2026-04-02
**Overall confidence:** HIGH (most features are well-understood AppKit/Swift patterns; OAuth token behavior verified from issue threads and direct endpoint documentation)

---

## Context: What Already Exists (v1.0)

These are BUILT and should not be re-researched:

- Menu bar text label showing usage percentage (`NSStatusItem` + `NSAttributedString` title)
- Dropdown panel with daily/weekly progress bars and reset countdowns (`NSPopover` + SwiftUI)
- Error states for offline/auth failure
- 60-second polling loop (`Task.sleep` in a `@MainActor` actor)
- Launch at Login (`SMAppService`)
- Keychain read of Claude Code's OAuth token (`SecItemCopyMatching`)

---

## Table Stakes (v2.0 Edition)

These are now expected by users of v1.0. Missing them makes the app feel unfinished relative to its own prior state.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Color-coded menu bar text | v1 FEATURES.md listed this as P1 and a table-stakes expectation for the category. Users of cctray and Claude Usage Tracker take it for granted. | LOW | `NSAttributedString` with `.foregroundColor` on `statusItem.button?.attributedTitle`. Use semantic `NSColor.systemGreen/systemYellow/systemRed` — they auto-adapt to light/dark. Hardcode defaults: green < 75%, yellow 75–90%, red > 90%. |
| Adaptive template icon | Without `isTemplate = true` the icon looks broken in dark mode — this is a quality signal Apple and users both notice immediately. | LOW | `statusItem.button?.image?.isTemplate = true`. Image must be monochrome mask-style. 16pt at 1x and 2x. Template approach is the only correct pattern per Apple HIG. |
| Auto-refresh expired OAuth tokens | v1 fails silently when the access token expires (~8 hours; sooner under rate-limit refresh). Requires zero user action — "it just works". | MEDIUM | See OAuth Refresh section below for full complexity breakdown. |

## Differentiators (v2.0 Edition)

Features that raise perceived quality and differentiate from competitors — not strictly required, but valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Configurable warning thresholds | Power users have different workflows. A developer who maxes Claude every day wants yellow at 85%, not 75%. | MEDIUM | Store as two `Double` values in `UserDefaults` via `@AppStorage`. Present in a simple settings panel (NSPanel or NSWindowController). No SwiftUI `Settings` scene — see pitfall below. Defaults: warn=0.75, critical=0.90. |
| Last-updated timestamp | "How stale is this?" is a common first thought when opening the popover. Eliminates uncertainty. | LOW | Store `Date?` in `@Published` on the model; format as "Updated 23s ago" using `RelativeDateTimeFormatter`. Update on every successful poll and on manual refresh. |
| Manual refresh button | Power users want to see fresh data immediately after finishing a heavy Claude session. ccusage-monitor uses `⌘R`; this is the established pattern. | LOW | Add a "Refresh" `Button` in the popover footer. Calls the same async polling function already used by the timer. Disable the button while a fetch is in-flight to prevent double-fire. |

## Anti-Features (Do Not Build)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| System notifications on threshold breach | macOS notification permissions are friction. Users who already have color-coded text in front of them do not need a second alert. Competitors that added this got mixed reviews. | Color-coded label + optional future toggle if user research shows demand |
| Settings window as a dedicated app window with Dock icon activation | Requires toggling `NSApplication.activationPolicy` between `.accessory` and `.regular`, with timing hacks that break on macOS Tahoe (26). Adds Dock visibility briefly — jarring. | Embed threshold controls inline in the popover panel under a collapsible "Settings" section, or use a plain `NSPanel` that does not require activation policy changes. |
| Rotating token as a workaround for rate limits | Refreshing the token aggressively to reset the per-token `/api/oauth/usage` rate limit window is explicitly fragile. The rate-limit-per-token behavior is an undocumented API side effect, not a contract. | Back off on 429 with exponential delay. Do not abuse token rotation. |
| `SettingsLink` inside NSPopover/MenuBarExtra | Documented Apple bug as of 2025 — `SettingsLink` does not work reliably inside menu bar extras or popovers. Wastes implementation time. | See threshold configuration approach above. |

---

## Feature-by-Feature Technical Detail

### 1. Color-Coded Menu Bar Text

**How it works in macOS menu bar apps:**

`NSStatusItem.button` is an `NSButton`. `NSButton` exposes `attributedTitle: NSAttributedString` (in addition to plain `title: String`). Setting an `NSAttributedString` with `.foregroundColor` overrides the default system appearance color.

**Dark mode caveat (IMPORTANT):** Hard-coded `NSColor(red:green:blue:)` values will be invisible or wrong in dark mode. The correct approach is semantic system colors:
- `NSColor.systemGreen` — adapts to dark mode automatically
- `NSColor.systemYellow` — same
- `NSColor.systemRed` — same

These are not the same as `NSColor.green` (which is a fixed sRGB value). `systemGreen` is vibrant and readable on both light and dark menu bars.

**Width impact:** Colored text is slightly wider than the monochrome default because Swift renders the full attributed width. At three characters ("57%") this is negligible. Test at "100%" to ensure the label does not crowd adjacent status items.

**Threshold evaluation:** Evaluate against `fiveHourUsage / fiveHourLimit` (the field already used by v1 as the primary metric). `sevenDayUsage / sevenDayLimit` is secondary — color should reflect the most urgent of the two.

**Confidence:** HIGH — `NSButton.attributedTitle` is a stable AppKit API since macOS 10.0.

---

### 2. Adaptive Template Icon

**How it works:**

```swift
let image = NSImage(named: "MenuBarIcon")  // or NSImage(systemSymbolName:...)
image?.isTemplate = true
statusItem.button?.image = image
statusItem.button?.imagePosition = .imageLeft  // or .imageOnly
```

Setting `isTemplate = true` tells macOS to treat the image as a monochrome mask. The system fills it with the appropriate color for the current appearance (dark gray in light mode, white in dark mode, white when highlighted). This is the only pattern that passes Apple's HIG check for menu bar icons.

**SF Symbols as icon source:** `NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)` returns an SF Symbol as an `NSImage`. SF Symbols are inherently template images — `isTemplate` is already `true`. This eliminates the need for a bundled PNG asset.

**Coexistence with colored text:** If showing both an icon AND colored text, only the icon uses template rendering. The text uses `attributedTitle`. They do not interfere. Keep icon position as `.imageLeft` and set a left inset if the two crowd each other.

**Confidence:** HIGH — `NSImage.isTemplate` is documented Apple API; SF Symbols as NSImage is macOS 11+, confirmed stable.

---

### 3. Configurable Warning Thresholds

**How it works in the ecosystem:**

Standard pattern: `@AppStorage("warnThreshold") var warnThreshold: Double = 0.75`. `@AppStorage` is `UserDefaults`-backed, persists across launches, and binds directly to SwiftUI controls (Slider, TextField).

**Settings UI architecture for NSStatusItem + NSPopover apps:**

The `SwiftUI.Settings` scene is designed for `@main App`-style apps. This project uses `NSStatusItem` + `NSPopover` without a `@main App` struct — the Settings scene is not available in this architecture without restructuring the app entry point.

The practical options, from lowest complexity to highest:

1. **Inline in popover** — Add a collapsible "Thresholds" section at the bottom of the existing `NSPopover` content view. Use two `Slider` controls bound to `@AppStorage`. No separate window needed. Suitable for 2–3 settings.

2. **NSPanel via NSWindowController** — Create a plain `NSPanel` (floating panel, no title bar chrome) hosted in a dedicated `NSWindowController`. Open it from a "Preferences..." menu item. SwiftUI content inside the panel via `NSHostingController`. This is the standard AppKit pattern for menu-bar-only apps and does not require activation policy changes.

3. **SwiftUI Settings scene with hidden WindowGroup** — Requires restructuring the app as a `@main App` with a hidden `WindowGroup`. Possible but introduces the activation policy juggling problem documented by Steinberger (2025). Not recommended for this project's architecture.

**Recommendation:** Option 1 (inline) for v2.0. Two sliders for `warnThreshold` and `criticalThreshold`, inline in the popover below the existing metrics. Fast to build, no new windows, no architecture change.

**Confidence:** HIGH for UserDefaults/AppStorage; MEDIUM for the Settings scene caveat (based on 2025 blog posts, not official docs).

---

### 4. Last-Updated Timestamp

**How it works:**

Store a `Date?` on the view model (`@Published var lastUpdated: Date? = nil`). Set it to `Date()` on every successful API response. In the popover SwiftUI view, display it using `RelativeDateTimeFormatter`:

```swift
RelativeDateTimeFormatter().localizedString(for: lastUpdated, relativeTo: Date())
// → "23 seconds ago", "2 minutes ago"
```

For sub-minute freshness, display "Just updated" or a static "Updated X seconds ago" with a 10-second UI refresh timer inside the popover. The popover does not need to stay in sync when closed — only render when visible.

**Conventions from competitor analysis:** Claude Usage Tracker and ccusage-monitor both show a timestamp or "Updated X ago" line at the bottom of the dropdown. This is the established location — bottom of popover, below the metrics, above Quit.

**Confidence:** HIGH — `RelativeDateTimeFormatter` is stable Foundation API (macOS 10.15+).

---

### 5. Manual Refresh Button

**How it works:**

The v1 polling loop is a `Task` running `Task.sleep(for: .seconds(60))`. The cleanest manual-refresh approach depends on how the polling loop is structured. Two common patterns:

**Pattern A — Cancel and restart the Task:**
Call `pollingTask?.cancel()` and immediately call the fetch function, then restart the timer. Simple but restarts the 60-second clock.

**Pattern B — Shared fetch function called independently:**
The polling loop calls `fetchUsage()`. The Refresh button also calls `fetchUsage()` directly. The timer is not affected. This is the better pattern — no cancel/restart, no clock reset.

**In-flight guard:** Add `@Published var isRefreshing: Bool = false`. Set it to `true` at the start of `fetchUsage()`, `false` on completion. Bind the Refresh button's `.disabled` modifier to `isRefreshing` to prevent double-tap.

**Keyboard shortcut:** `⌘R` is the established shortcut in this category (ccusage-monitor uses it). `Button("Refresh", action: refresh).keyboardShortcut("r", modifiers: .command)` inside a SwiftUI popover.

**Confidence:** HIGH — standard SwiftUI/Swift concurrency pattern.

---

### 6. Auto-Refresh Expired OAuth Tokens

**This is the most complex feature in v2.0.** It has real correctness constraints.

**Token lifecycle facts (verified):**

- Access token expires in ~8 hours (`expires_in: 28800` seconds)
- Refresh token is one-time use — each refresh issues a NEW refresh token (rotation)
- The old refresh token becomes invalid immediately on use
- Refresh endpoint: `POST https://console.anthropic.com/v1/oauth/token`
- Body: `{ "grant_type": "refresh_token", "refresh_token": "<token>", "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e" }`
- Response fields: `access_token`, `refresh_token`, `expires_in`, `token_type`, `scope`

**The concurrency risk:** If two polling iterations fire concurrently and both detect an expired token, they will both attempt a refresh. The second call will use the already-rotated (now invalid) refresh token and fail, logging the user out.

**Standard solution — Swift actor with in-flight guard:**

```swift
actor TokenManager {
    private var refreshTask: Task<String, Error>?

    func validAccessToken() async throws -> String {
        // 1. Return current token if not expired
        // 2. If expired and no refresh in flight: start one, store the Task
        // 3. If expired and refresh in flight: await the existing Task
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task { try await performRefresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }
}
```

This actor pattern ensures exactly one refresh fires even if multiple callers race.

**Keychain write after refresh:** After a successful token refresh, BOTH the new `accessToken` AND the new `refreshToken` must be written back to Keychain (`SecItemUpdate` or delete+add). If only the access token is saved, the next refresh will fail because the old refresh token is invalid.

**Proactive vs reactive refresh:**

- Proactive: Check `expiresAt` stored in Keychain before each API call. Refresh if within a buffer (e.g., 60 seconds before expiry). Avoids ever hitting a 401.
- Reactive: On 401 response, refresh once and retry. Simpler to implement but requires one failed API call before recovering.

**Recommendation:** Implement proactive check using stored `expiresAt`. Fall back to reactive (retry on 401) as a safety net. This is exactly how Claude Code itself handles it per the issue thread research.

**The rate-limit/refresh interaction:** GitHub issue #30930 documented that `/api/oauth/usage` has a very low per-token rate limit (~5 requests). Refreshing the token resets the rate limit window because the new access token has its own quota. This is an undocumented side effect — do NOT rely on it as a strategy. Use exponential backoff on 429 independently of token refresh.

**Confidence:** MEDIUM — token structure and endpoint verified from GitHub issue #30930 and third-party reverse engineering (alif.web.id). Rotation behavior confirmed. Exact Keychain field names (`accessToken`, `refreshToken`, `expiresAt`) are from third-party analysis, not official Anthropic docs.

---

## Feature Dependencies

```
[Color-Coded Text]
    └──requires──> [Usage data from existing polling] (already built)
    └──reads──> [warnThreshold, criticalThreshold from UserDefaults]
                    └──written by──> [Configurable Thresholds UI]

[Adaptive Template Icon]
    └──independent of all other v2 features
    └──requires only──> [NSStatusItem.button.image already set in v1]

[Configurable Thresholds UI]
    └──persisted via──> [@AppStorage / UserDefaults]
    └──consumed by──> [Color-Coded Text]

[Last-Updated Timestamp]
    └──requires──> [lastUpdated: Date? on the existing view model]
    └──updated by──> [existing fetchUsage() function]
    └──also updated by──> [Manual Refresh]

[Manual Refresh Button]
    └──calls──> [existing fetchUsage() function directly]
    └──updates──> [Last-Updated Timestamp as a side effect]

[Auto-Refresh OAuth Tokens]
    └──wraps──> [existing Keychain read in v1 (SecItemCopyMatching)]
    └──adds──> [TokenManager actor]
    └──writes back to──> [Keychain (SecItemUpdate)]
    └──called by──> [fetchUsage() before each API request]
```

### Dependency Summary

- **Color-coded text + adaptive icon** are independent of each other and of the OAuth refresh work. They can be shipped first with no risk.
- **Thresholds UI** must exist before color-coded text uses configurable values (color-coding with hardcoded defaults can ship first).
- **Last-updated timestamp** and **manual refresh** share the same `fetchUsage()` entry point — implement them together in one pass.
- **OAuth token refresh** is the only feature with cross-cutting risk. It touches the authentication path that all API calls depend on. Implement and test it in isolation before integrating with the polling loop.

---

## Implementation Order (Recommended)

1. **Adaptive template icon** — 30 min, zero risk, immediate visible improvement
2. **Color-coded menu bar text** (hardcoded thresholds) — 1 hour, builds on existing label
3. **Last-updated timestamp + manual refresh** — half day, share one model change
4. **Configurable thresholds UI** — half day, adds the slider panel to the popover
5. **OAuth token auto-refresh** — full day, write `TokenManager` actor + Keychain write-back, test thoroughly

---

## Sources

- [NSButton.attributedTitle — Apple Developer Docs](https://developer.apple.com/documentation/appkit/nsbutton/1524640-attributedtitle)
- [NSColor.systemGreen / systemRed / systemYellow — Apple Developer Docs](https://developer.apple.com/documentation/appkit/nscolor)
- [NSImage.isTemplate — Apple Developer Docs](https://developer.apple.com/documentation/appkit/nsimage/istemplate)
- [Building a token refresh flow with async/await — Donny Wals (July 2025)](https://www.donnywals.com/building-a-token-refresh-flow-with-async-await-and-swift-concurrency/)
- [Showing Settings from macOS Menu Bar Items — Peter Steinberger (2025)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items)
- [Claude Code OAuth token / usage endpoint — GitHub Issue #30930 (anthropics/claude-code)](https://github.com/anthropics/claude-code/issues/30930)
- [OAuth token expiry fix — opencode Issue #9121](https://github.com/anomalyco/opencode/issues/9121)
- [Unlock Claude API from Claude Pro/Max — alif.web.id (token structure reference)](https://www.alif.web.id/posts/claude-oauth-api-key)
- [UserDefaults @AppStorage — SwiftLee](https://www.avanderlee.com/swift/user-defaults-preferences/)
- [Refreshing iOS access tokens using mutual exclusivity — Jacob Chan (Medium)](https://medium.com/@therealjacobchan/refreshing-your-ios-access-tokens-using-mutual-exclusivity-3fb814b0d58e)

---

*Feature research for: v2.0 Polish & Resilience milestone*
*Researched: 2026-04-02*
