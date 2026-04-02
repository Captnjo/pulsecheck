# Pitfalls Research

**Domain:** macOS menu bar app — API-polling utility (Claude Code usage)
**Researched:** 2026-04-02
**Confidence:** HIGH (verified against official docs, multiple sources, and existing apps in this exact niche)

---

## V2.0 Pitfalls — Polish & Resilience Milestone

These pitfalls are specific to the six features being added in v2.0: color-coded menu bar text, adaptive template icon, configurable thresholds, last-updated timestamp, manual refresh, and OAuth token auto-refresh.

---

### V2 Pitfall 1: You Cannot Write Back to Claude Code's Keychain Item

**What goes wrong:**
OAuth token refresh requires writing the new access token and new refresh token back to the Keychain. When PulseCheck calls `SecItemUpdate` on the `Claude Code-credentials` item, it gets `errSecInvalidOwnerEdit` (-25243) or `errSecAuthFailed` (-25293) and the write silently fails. The app falls back to the old (now-invalid) refresh token on the next refresh attempt, which fails server-side. The user ends up in a broken auth loop.

**Why it happens:**
macOS Keychain ACLs are bound to the code signature of the application that created the item. Claude Code created `Claude Code-credentials` — the ACL lists Claude Code's designated requirement, not PulseCheck's. Even though PulseCheck can read the item (using a `kSecMatchLimitOne` query without `kSecAttrAccount`, which reads without an explicit account filter), it cannot modify it. `SecItemUpdate` and `SecItemDelete` are both blocked by this ACL.

This is documented behavior (Apple TN3137). The `errSecInvalidOwnerEdit` error occurs when your app tries to modify a Keychain item it did not create.

**Consequences:**
- Token refresh POST to `https://console.anthropic.com/v1/oauth/token` can succeed server-side (new tokens returned)
- Write-back fails silently (no crash — just an OSStatus error return code)
- The old refresh token is now invalidated by the server (refresh tokens rotate on every use)
- PulseCheck now holds no valid tokens at all
- User must re-run `claude auth login` to recover

**Prevention:**
Do not attempt `SecItemUpdate` on `Claude Code-credentials`. The write will fail and will corrupt credential state by consuming the refresh token without storing the replacement.

Two viable designs:

**Option A — Read-only bridge (recommended):** PulseCheck reads the existing Keychain item to get the current access token. If the access token is expired, PulseCheck shows a UI prompt: "Token expired — open Claude Code to refresh, or run `claude auth login`." This is zero-risk: PulseCheck never touches the Keychain write path. Token freshness is maintained by Claude Code itself; PulseCheck just piggybacks on it.

**Option B — PulseCheck-owned shadow item:** After a successful refresh, store the new tokens in a *separate* Keychain item owned by PulseCheck (e.g., service name `PulseCheck-claude-credentials`). This item IS writable by PulseCheck. On next app launch, prefer the shadow item if it is fresher than the Claude Code item; otherwise use the Claude Code item. This requires careful handling of the case where Claude Code also refreshes concurrently (see Pitfall V2.2 below).

**Detection:**
- `SecItemUpdate` returns `-25243` (errSecInvalidOwnerEdit) or `-25293` (errSecAuthFailed)
- Logs show "token refresh succeeded" followed immediately by "API call failed: Auth expired"
- Occurs on first run of token refresh code, not randomly

**Phase to address:** The phase implementing OAuth token auto-refresh. Decide between Option A and Option B before writing any refresh code.

---

### V2 Pitfall 2: Refresh Token Rotation Race — Consuming the Token Twice

**What goes wrong:**
The polling loop fires exactly as the user triggers a manual refresh. Both code paths detect `isExpired == true`, both call the `/v1/oauth/token` refresh endpoint with the same refresh token. The server accepts the first request and issues new tokens. The second request arrives with the now-invalidated refresh token and the server rejects it — or worse, depending on the OAuth server's policy, it may also invalidate the entire refresh token family (both the old and new tokens become invalid). The user is fully logged out.

**Why it happens:**
The polling loop runs every 60 seconds in a `Task`. A manual refresh creates a second `Task`. Both `Task`s run concurrently on `@MainActor`. Even though `@MainActor` serializes synchronous access to shared state, both tasks can read `credentials.isExpired == true` before either task writes new credentials back — the actor-reentrancy problem. The `await` on the network call suspends the first task, allowing the second to proceed past the expiry check before the first task has updated `self.credentials`.

**Consequences:**
- Anthropic's OAuth server implements strict single-use rotation: each refresh token can only be used once
- The GitHub issue #34785 (claude-code) documents that scope loss also occurs on duplicate refreshes
- Recovery requires `claude auth login` — cannot self-heal

**Prevention:**
Gate all token refresh behind a serialization lock using a stored `Task` handle. Check for an in-flight refresh before starting a new one:

```swift
// In your token manager (actor or @MainActor class)
private var refreshTask: Task<ClaudeOAuthCredentials, Error>?

func refreshIfNeeded() async throws -> ClaudeOAuthCredentials {
    // If a refresh is already in flight, await it — don't start another
    if let existingTask = refreshTask {
        return try await existingTask.value
    }
    let task = Task<ClaudeOAuthCredentials, Error> {
        defer { self.refreshTask = nil }
        return try await performRefresh()
    }
    refreshTask = task
    return try await task.value
}
```

Multiple concurrent callers await the same Task and get the same result. Only one network request goes out.

**Detection:**
- API logs show two nearly-simultaneous POST requests to the refresh endpoint
- Second request returns 400 "invalid_grant" or 401
- Reproducible by: triggering manual refresh while a poll is 0–2 seconds away from firing

**Phase to address:** The phase implementing OAuth token auto-refresh, before or alongside the manual refresh button.

---

### V2 Pitfall 3: NSAttributedString Color in NSStatusItem Breaks on Highlight and Loses Vertical Alignment

**What goes wrong:**
You set `button.attributedTitle` with red/yellow/green `NSColor` to color-code the usage percentage. Three things break:

1. When the user clicks the status item and it highlights (blue selection), the colored text is drawn on top of the blue background at full opacity — the red/green becomes unreadable.
2. The `attributedTitle` property is documented but known to not position text correctly in the status bar — vertical centering is off by 1 pixel, with 11px above and 13px below (asymmetric) vs. the 12/12 split used by system items.
3. The text color does not adapt to the system's light/dark mode automatically. `NSColor.red` looks fine in light mode and invisible in dark mode with some themes.

**Why it happens:**
`NSStatusBarButton` does not override its highlight drawing to respect custom attributed string colors. The system highlight composites on top of whatever color the app set. This is a documented open Apple feedback (FB7037487). The vertical centering asymmetry is also a long-standing Apple bug.

`NSColor` with fixed color values (`.red`, `.systemYellow`) do not adapt to appearance. Only semantic colors (`.labelColor`, `.secondaryLabelColor`) adapt — but those are monochrome, defeating the purpose.

**Prevention:**
Use `NSColor.systemRed`, `NSColor.systemYellow`, `NSColor.systemGreen` (dynamic system colors, not raw red/green/blue). These adapt across light/dark mode and retain reasonable contrast in both themes.

For highlight safety, set the foreground color conditionally based on `button.isHighlighted`. Override via subclassing `NSStatusBarButton` or by observing the button's highlighted state and updating `attributedTitle` accordingly:

```swift
// Update color based on highlight state
NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, ...) { ... }
// Or use KVO on button.isHighlighted
```

Alternatively, render color as a visual indicator *next to* the text (a colored SF Symbol dot) rather than *in* the text color itself. This sidesteps all three issues.

For vertical centering, apply `NSAttributedString.Key.baselineOffset` with value `1.0` (macOS 13+) when using `attributedTitle`. The correct value varies by macOS version and is not reliably fixable — treat it as cosmetic.

**Detection:**
- Highlight state shows garbled colored text on blue background
- Green text invisible in dark mode
- Vertical alignment slightly off compared to system clock

**Phase to address:** The phase implementing color-coded menu bar text (first v2.0 feature).

---

### V2 Pitfall 4: Template Icon and Colored Text Cannot Coexist Using `imagePosition`

**What goes wrong:**
The existing `StatusBarController` sets both `button.image` and `button.title`. Adding a colored `attributedTitle` while keeping the template icon causes the template icon to also render in color (template images are re-tinted by AppKit using the button's `contentTintColor`). If you set `contentTintColor` for colored text rendering, it tints the icon too. If you leave `contentTintColor` nil and use `attributedTitle` for color, the icon may render incorrectly in dark mode.

**Why it happens:**
`NSStatusBarButton` has a single tint color that applies to all composited content — both the image and the text. It does not support independent coloring of image vs. text. Setting `.isTemplate = true` on the icon means AppKit handles icon tinting; setting `contentTintColor` on the button overrides that tinting.

**Prevention:**
Decouple icon and text rendering. Two patterns:

1. Use template icon only (no colored text in `attributedTitle`). Express usage state via the icon (e.g., a different SF Symbol per threshold state), not text color. Simplest and most reliable.
2. Drop the template icon when displaying color-coded text. Set `button.image = nil` and use only `button.attributedTitle` with colored text. Accept that the item is text-only in the color-coded state.
3. Render both icon and colored text into a single `NSImage` using `NSGraphicsContext` offscreen drawing. Set that composite image as `button.image` with `isTemplate = false`. This gives full control but requires custom drawing code and must be re-rendered on every state change and on appearance change.

For this app, option 1 (threshold-state SF Symbol icon) or option 2 (text-only colored) is recommended. Option 3 is disproportionate effort.

**Detection:**
- Template icon renders in wrong color after setting `contentTintColor`
- Icon disappears or turns solid black in dark mode
- Icon and text fight over tint color

**Phase to address:** Adaptive icon phase and color-coded text phase — plan the interaction between them before implementing either.

---

### V2 Pitfall 5: Manual Refresh Does Not Reset the Polling Countdown

**What goes wrong:**
The user clicks "Refresh Now" and the app fetches fresh data. 3 seconds later, the polling loop fires its scheduled cycle and fetches again — a duplicate request. At the worst case, if the manual refresh triggered right before a poll cycle, the app makes two API calls within seconds. With the 60-second poll interval and existing backoff logic, a manual refresh at second 59 of the cycle means two requests hit the server in rapid succession.

**Why it happens:**
The current polling loop is:
```swift
while !Task.isCancelled {
    await fetchUsage()
    try await Task.sleep(for: .seconds(backoffSeconds))
}
```
A manual `fetchUsage()` call is additive — it does not interact with the sleeping poll task. The poll task wakes independently after its sleep duration, regardless of whether a manual fetch happened during the sleep.

**Prevention:**
Reset the polling timer after a manual refresh. One clean approach: cancel and restart the polling task after a manual fetch:

```swift
func manualRefresh() async {
    await fetchUsage()
    startPolling()  // cancels existing pollingTask, starts fresh with full 60s sleep
}
```

This means after a manual refresh the next automatic poll is always 60 seconds away — no burst.

Alternatively, use a channel/continuation pattern where the poll loop can be "poked" to skip its sleep and fetch immediately, then reset the countdown. This is more complex but avoids restarting the task:

```swift
private var refreshSignal = AsyncStream<Void>.makeStream()

// In poll loop:
for await _ in AsyncStream.merge(timerTicks, refreshSignal.stream) {
    await fetchUsage()
}
```

For this app, the simpler `startPolling()` restart is appropriate.

**Detection:**
- Two API requests visible in Instruments/Charles within 1-5 seconds after manual refresh
- Occurs when manual refresh is triggered in the last few seconds of a poll cycle
- `backoffSeconds` doubles unexpectedly (two requests hit a 429, both back off)

**Phase to address:** Manual refresh button phase.

---

### V2 Pitfall 6: AppStorage/@UserDefaults Keys Collide Between App Versions or Debug Builds

**What goes wrong:**
You use `@AppStorage("warningThreshold")` to persist configurable thresholds. A later refactor changes the default value or type. Old persisted values from a previous run cause unexpected behavior — e.g., a threshold of `0.75` stored as a `Double` is now expected as an `Int` (`75`), causing a silent type mismatch. UserDefaults reads the wrong type and returns the default, discarding the user's saved preference.

A second scenario: Debug builds share the same `UserDefaults` domain as Release builds (same bundle ID unless you use a separate debug bundle ID). A developer testing with `warningThreshold = 0.01` in debug mode will find that preference persisted after switching to release.

**Why it happens:**
`UserDefaults` is not type-safe. Storing a `Double` under `"warningThreshold"` and reading it back as an `Int` returns 0 (the `Int` default) without error. Swift's `@AppStorage` adds type safety at the call site but cannot detect a stored value of the wrong type — it silently returns the default.

**Prevention:**
- Use explicit, namespaced keys: `"com.jo.PulseCheck.warningThreshold.v1"` — includes version suffix in the key name for any value whose type or semantics might change.
- Migration: on first launch after update, detect old key presence and migrate value explicitly before reading.
- For debug builds: use a different suite name for `UserDefaults` so debug preferences are isolated: `UserDefaults(suiteName: "com.jo.PulseCheck.debug")`.
- Store thresholds as `Double` (0.0–1.0 fraction) consistently — do not flip between fraction and percentage representations across features.

**Detection:**
- User-configured thresholds reset to default after app update
- Threshold value behaves as if no setting was saved, despite the user having configured it

**Phase to address:** Configurable thresholds phase.

---

### V2 Pitfall 7: OAuth Token Refresh Produces Missing Scopes, Causing 403 Not 401

**What goes wrong:**
PulseCheck refreshes the OAuth token successfully (HTTP 200 from Anthropic's token endpoint). The new access token is stored. The next API call to `/api/oauth/usage` returns HTTP 403 with `"OAuth token does not meet scope requirement user:profile"`. The existing error handler treats 403 as a generic API error, not an auth error, so it does not retry or re-authenticate — the app enters a permanent error state.

**Why it happens:**
This is a documented server-side bug in Anthropic's token refresh flow (GitHub issue #34785 in the anthropics/claude-code repo). On some refresh cycles, the new access token is missing required scopes (`user:profile` specifically). The token is valid (passes expiry check, 200 on refresh) but unauthorized for the specific API call. The `isExpired` check returns `false` for this token, so the standard "detect expired token" guard does not fire.

**Consequences:**
- App displays permanent error state
- User must run `claude auth login` manually to recover
- Not detectable with `isExpired` — requires checking the actual 403 response body

**Prevention:**
Add 403 handling to `AnthropicAPIClient.fetchUsage`. When a 403 response contains scope-related error text, treat it as an auth failure and trigger the same recovery path as a 401:

```swift
case 403:
    let body = String(data: data.prefix(500), encoding: .utf8) ?? ""
    if body.contains("scope") || body.contains("user:profile") {
        return .failure(.apiUnauthorized)  // Treat as auth failure, not generic error
    }
    return .failure(.apiError(403, body))
```

This ensures the app recovers (re-reads fresh credentials from Keychain, or shows "re-auth needed" UI) rather than entering a silent error loop.

**Detection:**
- API returns 200 on the refresh endpoint but 403 on the usage endpoint
- Error body contains "scope requirement" or "user:profile"
- Occurs specifically after a token refresh cycle, not on first launch

**Phase to address:** OAuth token auto-refresh phase.

---

### V2 Pitfall 8: Appearance Change Notification Not Received When App Is Accessory Policy

**What goes wrong:**
You implement light/dark mode icon switching by observing `NSApp.effectiveAppearance` changes. The observer fires in Debug builds but not when the app runs with `.accessory` activation policy at login (via `SMAppService`). The icon is stuck on the appearance from app launch.

**Why it happens:**
Accessory-policy apps do not receive `NSApplicationDidChangeOcclusionStateNotification` and may not receive `NSAppearanceDidChange` in all contexts because they are not "active" in the system's sense. The notification is delivered to the active foreground app. Apps that launched at login and never came to the foreground miss the delivery window.

**Prevention:**
Rather than observing `NSApp.effectiveAppearance` changes via `NSWorkspace` notifications, use a system-aware color or template image that AppKit handles automatically:

- For the icon: set `.isTemplate = true` on the `NSImage`. AppKit automatically re-renders template images in the correct color for the current appearance. No observer needed.
- For colored attributed text: use `NSColor.systemRed` / `.systemGreen` / `.systemYellow` — these adapt automatically without any notification observer.

If you must handle appearance changes manually (e.g., for the composite image approach in Pitfall V2.4), use `DistributedNotificationCenter` with name `"AppleInterfaceThemeChangedNotification"` — this fires system-wide regardless of app activation state.

```swift
DistributedNotificationCenter.default().addObserver(
    forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
    object: nil, queue: .main
) { [weak self] _ in
    self?.updateStatusItemAppearance()
}
```

**Detection:**
- Icon appearance correct after manual relaunch, wrong after system sleeps or appearance auto-switch
- Reproducible only when app launches via SMAppService at login, not when launched from Xcode

**Phase to address:** Adaptive template icon phase.

---

## Phase-Specific Warning Summary (V2.0)

| Feature | Pitfall | Severity | Phase |
|---------|---------|----------|-------|
| OAuth token auto-refresh | Cannot write back to Claude Code's Keychain item (ACL blocks it) | CRITICAL | Token refresh |
| OAuth token auto-refresh | Refresh token consumed twice in race condition | CRITICAL | Token refresh |
| OAuth token auto-refresh | 403 scope-loss after refresh not handled as auth error | HIGH | Token refresh |
| Color-coded text | Colored text unreadable when button highlighted | HIGH | Visual polish |
| Color-coded text + template icon | `contentTintColor` tints both text and icon simultaneously | HIGH | Visual polish |
| Manual refresh | Does not reset polling countdown — burst of two requests | MEDIUM | Manual refresh |
| User preferences | `@AppStorage` type collision between versions | MEDIUM | Configurable thresholds |
| Adaptive icon | Appearance change notification not received under `.accessory` policy | MEDIUM | Adaptive icon |

---

## V1.0 Pitfalls (Original Research — Preserved)

---

### Pitfall 1: The Official Analytics API Is Organization-Only

**What goes wrong:**
The Anthropic Analytics API only works for organizations with an admin API key (`sk-ant-admin...`). Personal Pro/Max subscriptions cannot call `/v1/organizations/usage_report/claude_code`. Using a standard API key returns 401.

**How to avoid:**
Use the OAuth token from the Keychain (the same credential Claude Code itself uses) and call the internal OAuth usage endpoint. This is the only viable path for personal subscription users.

**Phase to address:** Phase 1 (Foundation / API discovery).

---

### Pitfall 2: NSStatusItem Gets Garbage Collected, Menu Disappears

**What goes wrong:**
An `NSStatusItem` created in a local variable and not stored in a persistent property gets deallocated when the function returns. The menu bar icon silently disappears.

**How to avoid:**
Store `NSStatusItem` as a property on a class with app-level lifetime (e.g., `AppDelegate`). Never create it in a local scope.

**Phase to address:** Phase 1 (App shell / menu bar scaffolding).

---

### Pitfall 3: Timer Creates a Retain Cycle, App Leaks Memory Indefinitely

**What goes wrong:**
`Timer.scheduledTimer` closure captures `self` strongly; `self` holds the timer. Neither is ever released.

**How to avoid:**
Use `[weak self]` in timer closures, or preferably use structured concurrency (`Task` + `Task.sleep(for:)`) which participates in Swift's cooperative cancellation model.

**Phase to address:** Phase 2 (Polling engine).

---

### Pitfall 4: Settings Window Cannot Be Opened From a Menu Bar App Without AppKit Surgery

**What goes wrong:**
`SettingsLink` and `openSettings()` do not work reliably inside `MenuBarExtra`. On macOS 26, `openSettings()` fails silently unless a hidden window is declared before the Settings scene.

**How to avoid:**
Temporarily switch activation policy to `.regular` before opening settings, then back to `.accessory`, plus a 1x1 hidden window to provide SwiftUI environment context. Or display settings inline in the popover panel to avoid a separate window entirely.

**Phase to address:** Phase 1–2 (first-run setup flow).

---

### Pitfall 5: SwiftUI MenuBarExtra Has No `.onAppear` for Its Menu Content

**What goes wrong:**
`.onAppear` on views inside `MenuBarExtra` never fires when the menu opens. Data does not refresh on open.

**How to avoid:**
Rely on background polling rather than on-open fetch. Use NSStatusItem directly (not MenuBarExtra) if on-open freshness is required.

**Phase to address:** Phase 2 (data refresh / UI update architecture).

---

### Pitfall 6: Storing API Key or OAuth Token in UserDefaults

**What goes wrong:**
`UserDefaults` stores values in plaintext plist at `~/Library/Preferences/`. Any process can read them.

**How to avoid:**
Store credentials only in the macOS Keychain via `SecItemAdd` / `SecItemCopyMatching`.

**Phase to address:** Phase 1 (Keychain storage).

---

### Pitfall 7: Polling Interval Below Rate Limit Floor Causes Self-Rate-Limiting

**What goes wrong:**
Polling faster than 60-second intervals triggers 429 responses. Immediate retry on 429 makes it worse.

**How to avoid:**
Keep 60-second minimum interval. Implement exponential backoff for 429 (60 → 120 → 240 → cap at 600 seconds).

**Phase to address:** Phase 2 (polling engine, error handling).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `UserDefaults` for API key | Zero boilerplate | Security vulnerability | Never |
| `Timer` without `[weak self]` | Simpler closure | Memory leak, growing RSS | Never |
| Hardcoded 60s interval with no backoff | Simple implementation | Self-rate-limiting on errors | Never |
| Internal API endpoint with no versioning guard | Works today | Breaks silently on Anthropic backend changes | MVP only, add version check |
| Single-threaded URLSession on main queue | No concurrency management | UI freezes on slow network | Never |
| Writing back to Claude Code's Keychain item | Fresher tokens | ACL error, token consumed, user locked out | Never |
| Starting second refresh Task without checking in-flight Task | Simple code | Consumes single-use refresh token twice | Never |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Anthropic Analytics API | Using standard API key for personal subscription | Use OAuth token from Keychain (internal API) |
| macOS Keychain | `kSecAttrService` inconsistent across read/write calls | Use a constant for the service name |
| macOS Keychain | Writing to Keychain item owned by another app | Use your own Keychain item; read Claude Code's but write to PulseCheck's |
| URLSession | Creating a new `URLSession` per poll | Use a single shared or configured session instance |
| OAuth token refresh | Starting a new refresh while one is in flight | Serialize with stored Task handle; all callers await same Task |
| OAuth token refresh | Treating 403 as non-auth error | Check 403 body for scope language; handle as `apiUnauthorized` |
| NSStatusItem color | Using raw `NSColor.red` — invisible in dark mode | Use `NSColor.systemRed` (adaptive semantic color) |
| NSStatusItem color + template icon | Setting `contentTintColor` for text — tints icon too | Decouple: template icon OR colored text, not both on same button |

---

## Sources

- Anthropic Claude Code Analytics API (official docs): https://platform.claude.com/docs/en/api/claude-code-analytics-api — confirmed org/admin-only
- Peter Steinberger, "Showing Settings from macOS Menu Bar Items: A 5-Hour Journey" (2025): https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
- GitHub issue #34785 (anthropics/claude-code) — OAuth refresh produces tokens with missing scopes: https://github.com/anthropics/claude-code/issues/34785
- GitHub issue #19456 (anthropics/claude-code) — OAuth Keychain permission errors (errSecInvalidOwnerEdit): https://github.com/anthropics/claude-code/issues/19456
- Donny Wals, "Building a token refresh flow using async await and Swift concurrency": https://www.donnywals.com/building-a-token-refresh-flow-with-async-await-and-swift-concurrency/
- Nango blog, "Concurrency with OAuth token refreshes": https://nango.dev/blog/concurrency-with-oauth-token-refreshes
- Jesse Squires, "Workaround for highlight bug in NSStatusItem": https://www.jessesquires.com/blog/2019/08/16/workaround-highlight-bug-nsstatusitem/
- Apple Developer Forums — "FB7037487: The text in NSStatusBarButton is not perfectly vertically centered": https://github.com/feedback-assistant/reports/issues/36
- Multi.app blog — "Pushing the limits of NSStatusItem": https://multi.app/blog/pushing-the-limits-nsstatusitem
- Apple TN3137 — On Mac keychain APIs: https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains
- Apple Developer Forums — errSecInvalidOwnerEdit: https://developer.apple.com/forums/thread/69841
- Square Engineering — "Uncovering Inconsistent Keychain Behavior": https://developer.squareup.com/blog/uncovering-inconsistent-keychain-behavior-while-fixing-a-valet-ios-bug/
- Apple Developer Forums — NSAppearance not updating with dark mode toggle: https://cloudstack.ninja/lukas-wurzburger/nsappearance-is-not-updating-when-toggling-dark-mode/

---
*Pitfalls research for: macOS menu bar app — v2.0 Polish & Resilience Milestone*
*Researched: 2026-04-02*
