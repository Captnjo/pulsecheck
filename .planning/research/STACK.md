# Technology Stack

**Project:** PulseCheck (Claude Mac Widget)
**Researched:** 2026-04-02 (v1.0 base) + 2026-04-02 (v2.0 delta)

---

## v1.0 Base Stack (validated, do not re-research)

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.1 (Xcode 16.3) | Primary language | Native, first-class macOS support; Swift 6 strict concurrency model catches data races at compile time — essential for polling + UI updates |
| SwiftUI | macOS 13.0+ | UI framework | `MenuBarExtra` scene API (introduced macOS 13 Ventura) is the modern, first-party way to build menu bar apps without AppKit boilerplate |
| AppKit (via NSApp) | macOS 13.0+ | App lifecycle helpers | Needed for `NSApp.terminate(nil)` quit button, activation policy, and `LSUIElement` Dock hiding — not avoidable in menu bar apps |
| URLSession | Built-in | API polling | Native async/await support (`let (data, _) = try await URLSession.shared.data(for:)`) — no networking library needed |
| Security framework (Keychain) | Built-in | Token storage | `SecItemAdd` / `SecItemCopyMatching` — first-party, no library needed for a single generic password item |
| Foundation (JSONDecoder) | Built-in | API response parsing | Codable structs + JSONDecoder is the standard zero-dependency approach |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-async-algorithms | 1.1.3 | `AsyncTimerSequence` for clean polling loop | Optional — use if you want a declarative `for await tick in AsyncTimerSequence(...)` poll loop instead of `Task.sleep` in a manual loop. Requires `.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")` |

**Verdict on third-party libraries:** For this project's scope, no third-party dependencies are required. The Security framework handles Keychain, URLSession handles networking, and a `Task { while true { ... try await Task.sleep(...) } }` loop handles polling. Add swift-async-algorithms only if the poll loop grows complex.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16.3 | IDE, compiler, signing | Minimum for Swift 6.1; macOS 15.2 required to run Xcode 16.3 |
| Swift Package Manager | Dependency management | Built into Xcode; no CocoaPods or Carthage needed for this project |
| Instruments (Time Profiler) | Performance | Verify 60s polling does not wake CPU excessively; use Timer coalescing |

## Installation

This project is a native Swift app with no npm/pip/cargo. All core dependencies are system frameworks. If using swift-async-algorithms:

```swift
// Package.swift (if structuring as SPM package) or add via Xcode File > Add Package Dependencies
.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
```

No other packages to install. The project should stay as lean as possible.

## API Authentication: Critical Design Decision

The Anthropic `GET https://api.anthropic.com/api/oauth/usage` endpoint requires **OAuth bearer token authentication**, not a simple API key. This changes the auth story significantly.

**What Claude Code stores on macOS:** OAuth credentials in macOS Keychain under service name `Claude Code-credentials` (with possible suffix variants). The token format is:

```json
{
  "accessToken": "sk-ant-oat01-...",
  "refreshToken": "...",
  "expiresAt": <timestamp_ms>
}
```

**Required request headers:**
```
Authorization: Bearer <accessToken>
anthropic-beta: oauth-2025-04-20
```

**Token lifecycle:** Access tokens are short-lived (~1 hour). The app must detect expiry via `expiresAt` and use the refresh flow before each poll. Refresh tokens are one-time use — save the new refresh token immediately after each refresh call.

**Known issue (as of March 2026):** The `/api/oauth/usage` endpoint returns persistent HTTP 429 with `retry-after: 0` for some Claude Max users. The workaround is token refresh on 429, not retry with the same token. Track this issue: https://github.com/anthropics/claude-code/issues/30930

**Response structure:**
```json
{
  "five_hour": { "utilization": 0.45, "resets_at": "2026-04-02T18:00:00Z" },
  "seven_day": { "utilization": 0.12, "resets_at": "2026-04-09T00:00:00Z" },
  "seven_day_oauth_apps": null,
  "seven_day_opus": { "utilization": 0.08, "resets_at": "2026-04-09T00:00:00Z" },
  "iguana_necktie": null
}
```

This endpoint is **undocumented and unofficial** — it is scraped from Claude Code's internal tooling. Field names like `iguana_necktie` confirm it was not designed for public consumption. Plan for breakage.

## Minimum Deployment Target

**macOS 13.0 (Ventura)** — required for `MenuBarExtra` scene API. This is the lowest viable target for the modern SwiftUI approach. macOS 13 was released October 2022 and covers the overwhelming majority of active Macs in 2026.

Do not target macOS 12 or lower: `MenuBarExtra` does not exist, and you would fall back to a fully AppKit-based `NSStatusItem` implementation that adds significant complexity.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftUI `MenuBarExtra` (.window style) | AppKit `NSStatusItem` + `NSMenu` | Only if targeting macOS 12 or earlier, or needing pixel-perfect control over menu item layout that SwiftUI can't provide |
| First-party Keychain (Security framework) | KeychainAccess (kishikawakatsuki) | If you need to read/write multiple Keychain items across many services; for a single token, the wrapper adds more complexity than it saves |
| `Task.sleep` polling loop | `Timer` (RunLoop-based) | Legacy `Timer` requires RunLoop management; use `Timer` only in AppKit/UIKit contexts |
| Manual JSON `Codable` structs | `Alamofire` / `Apollo` | Never add a full networking library for a single endpoint poll — URLSession + Codable is 20 lines |
| Swift / Xcode project | Electron / Tauri / web wrapper | Cross-platform is irrelevant here; native macOS provides Keychain access, proper menu bar integration, and lower resource use |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `@main App` with `WindowGroup` as root | Causes Dock icon to appear; menu-bar-only apps must suppress this | Set `LSUIElement = YES` in Info.plist; use `MenuBarExtra` as the only scene |
| `SettingsLink` inside `MenuBarExtra` | Documented to not work reliably inside menu bar extras (Apple bug, 2025) | Open Settings window manually with `NSApp.sendAction(Selector("showSettingsWindow:"), ...)` or use a custom window |
| CocoaPods | Deprecated workflow; no new macOS-only projects should use it | Swift Package Manager |
| Third-party HTTP libraries (Alamofire, etc.) | Adds a dependency for functionality URLSession + async/await covers natively | URLSession async/await |
| UserDefaults for token storage | Not encrypted; readable by any process with the same bundle ID | Security framework Keychain (`kSecClassGenericPassword`) |
| `DispatchQueue` + `Timer` polling | Race-prone; superseded by Swift structured concurrency | `async/await` + `Task.sleep(for: .seconds(60))` in a `@MainActor`-isolated polling loop |

## Stack Patterns by Variant

**If reading existing Claude Code token from macOS Keychain (no separate login):**
- Read service `Claude Code-credentials` from the system Keychain using `SecItemCopyMatching`
- Parse JSON `accessToken` / `refreshToken` / `expiresAt` fields
- No API key setup UI needed; piggyback on the user's existing Claude Code login
- This is the preferred UX: zero friction for existing Claude Code users

**If the Claude Code Keychain entry is inaccessible or missing (user not logged into Claude Code):**
- Fall back to reading `~/.claude/.credentials.json` (the Linux/SSH fallback that Claude Code also writes)
- Show a first-run setup screen directing user to run `claude auth login`

**If OAuth token is expired:**
- POST to `https://console.anthropic.com/v1/oauth/token` with `grant_type: refresh_token`
- Client ID: `9d1c250a-e61b-44d9-88ed-5944d1962f5e` (Claude Code's public client ID)
- Save both new `accessToken` AND new `refreshToken` — refresh tokens rotate on each use

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| SwiftUI `MenuBarExtra` | macOS 13.0+ | Not available on macOS 12; do not use availability guards as a workaround — just require macOS 13 |
| Swift 6 strict concurrency | Xcode 16.0+ | Can adopt incrementally: enable per-module, not project-wide, during migration |
| swift-async-algorithms 1.1.3 | Swift 5.5+, Xcode 14+ | Compatible with Swift 6; requires macOS 12+ (Foundation Clock types) |
| `Security` Keychain API | macOS 10.9+ | Fully stable; no version concerns |
| `/api/oauth/usage` endpoint | Undated | Unofficial; track Claude Code GitHub issues for breakage |

---

## v2.0 Delta Stack Research

**Scope:** Features for v2.0 milestone only. No new dependencies added — all capabilities are already in the SDK stack.

**Overall verdict:** Zero new dependencies. Every v2.0 feature is implementable with AppKit, Foundation, Security framework, and SwiftUI — all already imported in the project.

### Feature 1: Color-coded NSStatusItem Text

**Mechanism:** `NSAttributedString` with `NSAttributedString.Key.foregroundColor` assigned to `statusItem.button?.attributedTitle`.

**Current code:** `StatusBarController.updateTitle(_:)` sets `statusItem.button?.title` (plain String). Swap to `attributedTitle`.

**Color values:**
```swift
// Use system semantic colors — they adapt to accessibility settings
NSColor.systemGreen   // < warning threshold
NSColor.systemYellow  // warning zone
NSColor.systemRed     // critical zone
```

**Known pitfall — highlight inversion:** When the popover is open, macOS draws the status button with a highlighted (dark) background. A hardcoded colored `NSAttributedString` does not invert automatically and may become hard to read. The practical mitigation for v2.0: this condition is transient (popover is open, text briefly hard to see), acceptable for a personal tool. If color legibility during highlight must be guaranteed, add a KVO observer on `statusItem.button?.isHighlighted` and swap the attributed string to `NSColor.selectedMenuItemTextColor` when highlighted.

**Font matching system menu bar:**
```swift
NSFont.menuBarFont(ofSize: 0)  // 0 = system-default menu bar size
```

**No new imports required.** `AppKit` already imported in `StatusBarController.swift`.

**Confidence:** HIGH

### Feature 2: Adaptive Template Icon (light/dark mode)

**Mechanism:** Set `isTemplate = true` on the `NSImage` used for `statusItem.button?.image`. macOS automatically renders the icon as dark gray in light mode, white in dark mode, and white when highlighted. This is the system-standard behavior for all built-in menu bar icons.

**Simplest implementation — asset catalog change only:**

Open `PulseCheckIcon` in the Xcode asset catalog. Set **Render As → Template Image**. Done. No code change needed.

Belt-and-suspenders in code (for robustness):
```swift
if let img = NSImage(named: "PulseCheckIcon") {
    img.isTemplate = true
    button.image = img
}
```

**Alternative — SF Symbol (zero asset dependency):**
```swift
button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "PulseCheck")
// SF Symbols are always template by default
```

**Interaction with colored text:** Template image and colored `attributedTitle` coexist on the same button without conflict. The image adapts independently of the title color.

**Confidence:** HIGH

### Feature 3: Configurable Warning Thresholds

**Mechanism:** `@AppStorage` property wrapper backed by `UserDefaults`. Thresholds are `Double` values (0.0–1.0); `AppStorage` serializes these natively.

**Correct storage for thresholds:** UserDefaults (not Keychain). Thresholds are not sensitive — plain preferences.

**Recommended pattern:**
```swift
// Declare in any SwiftUI view or @Observable class:
@AppStorage("warningThreshold") var warningThreshold: Double = 0.75
@AppStorage("criticalThreshold") var criticalThreshold: Double = 0.90
```

**Where to place the settings UI:** The `SettingsLink` API is unreliable inside NSPopover contexts (documented Apple bug, confirmed 2025). For v2.0, embed threshold sliders directly in `UsagePanelView` (collapsible section or dedicated Settings tab). This avoids the settings window complexity entirely.

**No new imports required.** SwiftUI already imported.

**Confidence:** HIGH

### Feature 4: OAuth Token Refresh

**Mechanism:** POST to the Anthropic OAuth token endpoint. Use a Swift `actor` to serialize concurrent refresh calls (prevents duplicate refresh race conditions).

**Verified endpoint details** (MEDIUM confidence — third-party reverse-engineering from opencode project; client_id matches CLAUDE.md v1.0 validated research):

| Parameter | Value |
|-----------|-------|
| URL | `https://console.anthropic.com/v1/oauth/token` |
| Method | POST |
| Content-Type | `application/json` |
| `grant_type` | `"refresh_token"` |
| `refresh_token` | Value from `ClaudeOAuthCredentials.refreshToken` |
| `client_id` | `"9d1c250a-e61b-44d9-88ed-5944d1962f5e"` |

**Response fields:** `access_token`, `refresh_token` (rotates — MUST save), `expires_in` (seconds, relative), `token_type: "Bearer"`.

**CRITICAL:** Refresh tokens rotate. After success, immediately write both new `accessToken` and `refreshToken` to Keychain.

**Actor pattern (prevents duplicate refresh under concurrent callers):**
```swift
actor TokenRefreshActor {
    private var inflightTask: Task<ClaudeOAuthCredentials, Error>?

    func refresh(using credentials: ClaudeOAuthCredentials) async throws -> ClaudeOAuthCredentials {
        if let task = inflightTask {
            return try await task.value  // coalesce callers onto the same refresh
        }
        let task = Task<ClaudeOAuthCredentials, Error> {
            defer { self.inflightTask = nil }
            return try await TokenRefreshService().refresh(refreshToken: credentials.refreshToken)
        }
        inflightTask = task
        return try await task.value
    }
}
```

**Keychain write-back:** `KeychainService` currently only reads. Add `writeClaudeCredentials(_:)` using `SecItemUpdate` (item already exists from Claude Code's login). The query must match by `kSecAttrService: "Claude Code-credentials"`.

**Integration point:** In `UsageStore.fetchUsage()`, on `.failure(.apiUnauthorized)`, call the refresh actor before giving up, then retry the fetch once. Also check `credentials.isExpired` proactively at the start of each poll cycle.

**App Sandbox:** No entitlement changes needed. The existing `network.client` entitlement covers outbound to `console.anthropic.com`.

**New files needed:**
- `Services/TokenRefreshService.swift` — URLSession POST, ~40 lines
- `Services/TokenRefreshActor.swift` — actor wrapper, ~20 lines

`KeychainService.swift` needs a write method added (not a new file).

**Confidence:** MEDIUM (endpoint URL and client_id from third-party sources; functional architecture from well-established Swift async patterns)

### Feature 5: Last-Updated Timestamp

**Mechanism:** Add `var lastFetchedAt: Date?` to `UsageStore`. Set on successful fetch. Display in `UsagePanelView` using SwiftUI's `Text(_:style:)` with `.relative` style.

```swift
// In UsageStore.fetchUsage(), on .success:
self.lastFetchedAt = Date()

// In UsagePanelView:
if let date = store.lastFetchedAt {
    Text(date, style: .relative)  // Renders: "2 minutes ago", auto-refreshes
}
```

`Text(_:style: .relative)` auto-refreshes its display as time passes with no timer or polling overhead — the SwiftUI runtime handles it.

**No new imports required.**

**Confidence:** HIGH

### Feature 6: Manual Refresh Button

**Mechanism:** A `Button` in `UsagePanelView` calling `store.fetchUsage()`. Add `var isRefreshing: Bool` to `UsageStore` to prevent button spam.

```swift
// In UsageStore:
var isRefreshing: Bool = false

func fetchUsage() async {
    isRefreshing = true
    defer { isRefreshing = false }
    // ... existing fetch logic
}

// In UsagePanelView:
Button {
    Task { await store.fetchUsage() }
} label: {
    Label("Refresh", systemImage: "arrow.clockwise")
}
.disabled(store.isRefreshing)
```

The `defer { isRefreshing = false }` pattern ensures the flag resets even if the fetch throws or returns early.

**No new imports required.**

**Confidence:** HIGH

---

## v2.0 New Files Summary

| File | Purpose | Lines (est.) |
|------|---------|-------------|
| `Services/TokenRefreshService.swift` | URLSession POST to Anthropic OAuth refresh endpoint | ~45 |
| `Services/TokenRefreshActor.swift` | Actor serializing concurrent refresh calls | ~25 |

Files modified (not new): `StatusBarController.swift`, `KeychainService.swift`, `UsageStore.swift`, `UsagePanelView` (and related), `PulseCheckIcon` asset.

---

## v2.0 What NOT to Add

| Library | Why Not |
|---------|---------|
| `KeychainAccess` (kishikawakatsuki) | `SecItemUpdate` for a single item is ~15 lines; a wrapper adds a dependency for no gain |
| `Alamofire` or any HTTP library | URLSession async/await handles one new POST cleanly |
| `Combine` | `@Observable` + `@AppStorage` + `Text(.., style: .relative)` cover all reactivity needs |
| `swift-async-algorithms` | Still not needed; `Task.sleep` polling loop is sufficient |
| Any OAuth library (`p2/OAuth2`, etc.) | The refresh is a single POST — a full OAuth library is massively over-engineered |

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| NSAttributedString colored title | HIGH | Standard AppKit API, widely documented and used |
| Template icon (`isTemplate = true`) | HIGH | Official Apple HIG recommendation, unchanged since macOS 10.10 |
| `@AppStorage` for thresholds | HIGH | Official SwiftUI docs, macOS 12+ |
| OAuth refresh endpoint | MEDIUM | URL and client_id from third-party opencode project reverse engineering; client_id matches CLAUDE.md v1.0 research |
| Keychain write-back (`SecItemUpdate`) | HIGH | Stable Security framework API, well-documented |
| Swift actor for refresh serialization | HIGH | Official Swift concurrency pattern, verified in Donny Wals article |
| `Text(.., style: .relative)` | HIGH | Official SwiftUI API, macOS 12+ |
| Manual refresh / `isRefreshing` flag | HIGH | Standard SwiftUI boolean gate pattern |

---

## Sources

**v1.0 sources (from original research):**
- https://sarunw.com/posts/swiftui-menu-bar-app/ — MenuBarExtra scene API patterns (MEDIUM — 2022, API confirmed stable to 2025)
- https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ — `.window` style, LSUIElement, Dock hiding (MEDIUM)
- https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — SettingsLink bug in MenuBarExtra (HIGH — 2025)
- https://github.com/anthropics/claude-code/issues/30930 — OAuth usage endpoint 429 bug, token structure, refresh flow (MEDIUM)
- https://github.com/apple/swift-async-algorithms — swift-async-algorithms 1.1.3 (March 2026), AsyncTimerSequence (HIGH)
- https://developer.apple.com/documentation/security/storing-keys-in-the-keychain — Keychain API (HIGH)
- https://github.com/griffinmartin/opencode-claude-auth — Claude Code Keychain service name pattern, credentials JSON structure (MEDIUM)
- https://www.theregister.com/2026/03/31/anthropic_claude_code_limits/ — Claude Code quota issues context (LOW for API details)
- https://medium.com/better-programming/create-menu-bar-apps-for-macos-ventura-or-higher-4c05a5b28e31 — macOS 13 minimum confirmed for MenuBarExtra (MEDIUM)

**v2.0 sources:**
- https://developer.apple.com/documentation/appkit/nsstatusitem/attributedtitle — `attributedTitle` API reference (HIGH)
- https://developer.apple.com/documentation/appkit/nsstatusitem — button image, isTemplate (HIGH)
- https://multi.app/blog/pushing-the-limits-nsstatusitem — real-world NSStatusItem colored title patterns (MEDIUM)
- https://developer.apple.com/documentation/swiftui/appstorage — AppStorage persistence wrapper (HIGH)
- https://deepwiki.com/anomalyco/opencode-anthropic-auth/3.3-token-lifecycle-management — refresh endpoint URL, fields, client_id (MEDIUM)
- https://www.donnywals.com/building-a-token-refresh-flow-with-async-await-and-swift-concurrency/ — Swift actor pattern for concurrent refresh serialization (HIGH)
- https://indiestack.com/2018/10/supporting-dark-mode-adapting-images/ — isTemplate image behavior (MEDIUM — 2018, API unchanged)
- https://www.jessesquires.com/blog/2019/08/16/workaround-highlight-bug-nsstatusitem/ — highlight state behavior (MEDIUM — 2019, behavior unchanged)

---
*v1.0 researched: 2026-04-02 | v2.0 delta researched: 2026-04-02*
