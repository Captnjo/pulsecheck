# Architecture: v2.0 Feature Integration

**Domain:** macOS menu bar utility — visual polish, configurability, token resilience
**Researched:** 2026-04-02
**Confidence:** HIGH — based on direct reading of all 9 source files (535 LOC)

---

## Existing Architecture (as-built)

```
PulseCheckApp (@main)
    └── AppDelegate (NSApplicationDelegate, @MainActor)
            ├── UsageStore (@Observable, @MainActor)  ← single source of truth
            │       ├── credentials: ClaudeOAuthCredentials?
            │       ├── usageResponse: UsageResponse?
            │       ├── menuBarTitle: String  (didSet → onTitleChanged callback)
            │       ├── credentialError / usageError: AppError?
            │       ├── backoffSeconds: Int
            │       ├── pollingTask: Task<Void, Never>?
            │       └── onTitleChanged: ((String) -> Void)?
            │
            ├── StatusBarController (@MainActor)
            │       ├── statusItem: NSStatusItem
            │       ├── popover: NSPopover  → NSHostingController<UsagePanelView>
            │       └── updateTitle(_:) — sets button.title
            │
            └── Services (stateless structs)
                    ├── CredentialsService → KeychainService.readClaudeCredentials()
                    └── AnthropicAPIClient.fetchUsage(accessToken:)

Models:
    UsageResponse → UsagePeriod (utilization: Double, resetsAt: String)
    ClaudeOAuthCredentials (accessToken, refreshToken, expiresAt, scopes)
    AppError (keychainItemNotFound, apiUnauthorized, apiError, networkError, …)
```

**Key wiring facts:**
- `onTitleChanged` callback bridges `UsageStore` → `StatusBarController` (AppKit cannot observe `@Observable` natively)
- `menuBarTitle` is a plain `String`; color is not carried — only text reaches `StatusBarController`
- `CredentialsService` is `loadCredentials()` only — no refresh path exists
- `KeychainService` is `readClaudeCredentials()` only — no write path exists
- `UsageStore.fetchUsage()` calls `apiClient.fetchUsage(accessToken:)` directly — no retry/refresh branch
- `pollingTask` is a `Task`-based loop, not a `Timer`; `startPolling()` / `stopPolling()` are public

---

## Feature-by-Feature Integration Analysis

### Feature 1: Color-Coded Menu Bar Text

**What it needs:** The menu bar text "51%" should appear in green/yellow/red based on thresholds.

**Constraint:** `NSStatusItem.button.title` is plain `String`. Color requires `attributedTitle` (`NSAttributedString`).

**Integration point:** `StatusBarController.updateTitle(_:)` — currently sets `button.title`. Must be changed to set `button.attributedTitle` instead.

**Data needed:** The current utilization value (already in `UsageStore.usageResponse`) and threshold configuration (new — see Feature 3).

**Changes required:**

| Component | Change Type | What Changes |
|-----------|-------------|--------------|
| `StatusBarController` | Modify | `updateTitle(_:)` → `updateTitle(_:color:)` or accepts `NSAttributedString` |
| `UsageStore` | Modify | `onTitleChanged` callback must carry color information, or `menuBarTitle` becomes a computed property pairing text + color |
| `AppDelegate` | Modify | Callback wiring must forward color alongside title |

**Recommended approach:** Replace the `onTitleChanged: ((String) -> Void)?` callback with `onTitleChanged: ((String, NSColor) -> Void)?`. `UsageStore` computes the color from utilization + thresholds before firing the callback. `StatusBarController.updateTitle(_:color:)` builds the `NSAttributedString`.

Do NOT store `NSColor` or `NSAttributedString` inside `UsageStore` — those are AppKit types and violate the clean boundary between the store and the view layer. The color decision belongs in `UsageStore` (it's business logic based on thresholds), but the `NSColor` value is fine to pass as a parameter since it's a value type.

---

### Feature 2: Adaptive Template Icon

**What it needs:** A template image that macOS tints automatically for light/dark mode and menu bar color schemes.

**Constraint:** `NSImage` rendered as a template image automatically adapts. The image must be added to `Assets.xcassets` with template rendering mode, OR set `button.image?.isTemplate = true` in code.

**Integration point:** `StatusBarController.init()` — the line `button.image = NSImage(named: "PulseCheckIcon")` already exists. Add `button.image?.isTemplate = true` immediately after.

**Changes required:**

| Component | Change Type | What Changes |
|-----------|-------------|--------------|
| `StatusBarController.init()` | Modify | Add `.isTemplate = true` to the existing image assignment |
| `Assets.xcassets` | Modify | Optionally set rendering mode to Template in asset catalog (removes need for code flag) |

This is the simplest feature — a one-liner change plus an asset catalog update. No data flow changes needed.

---

### Feature 3: Configurable Warning Thresholds

**What it needs:** User-configurable thresholds for green/yellow/red breakpoints (e.g., yellow at 70%, red at 90%). Persisted across launches.

**Storage:** `UserDefaults` is appropriate here — these are UI preferences, not secrets. Use `UserDefaults.standard` with a typed wrapper.

**New component required:** `ThresholdSettings` — a struct or `@Observable` class that wraps `UserDefaults` reads/writes.

```swift
// New file: Models/ThresholdSettings.swift
struct ThresholdSettings {
    static let defaultYellow: Double = 70.0
    static let defaultRed: Double = 90.0

    var yellowThreshold: Double {
        get { UserDefaults.standard.double(forKey: "thresholdYellow").nonZero ?? Self.defaultYellow }
        set { UserDefaults.standard.set(newValue, forKey: "thresholdYellow") }
    }
    var redThreshold: Double {
        get { UserDefaults.standard.double(forKey: "thresholdRed").nonZero ?? Self.defaultRed }
        set { UserDefaults.standard.set(newValue, forKey: "thresholdRed") }
    }
}
```

**Integration into UsageStore:** `UsageStore` holds a `ThresholdSettings` instance. Color computation in Feature 1 uses it. `UsagePanelView` binds to the same `ThresholdSettings` values for the settings UI.

**UI:** A small settings row in `UsagePanelView` with two sliders or text fields — or a dedicated settings section at the bottom of the panel. Avoid a separate window; it complicates focus management for a menu bar app.

**Changes required:**

| Component | Change Type | What Changes |
|-----------|-------------|--------------|
| `Models/ThresholdSettings.swift` | New | UserDefaults-backed settings struct |
| `UsageStore` | Modify | Add `var thresholds = ThresholdSettings()` |
| `UsagePanelView` | Modify | Add threshold configuration row |

---

### Feature 4: Last-Updated Timestamp

**What it needs:** Show "Updated 30s ago" or "Updated just now" in the panel, updating as time passes.

**Data needed:** Timestamp of the last successful API response. Currently absent from `UsageStore`.

**New state in UsageStore:**
```swift
var lastFetchedAt: Date? = nil  // set in fetchUsage() on .success
```

**UI rendering:** `UsagePanelView` displays a relative time string. The string must update dynamically (not only when the store changes). Use a `TimelineView(.periodic(from: .now, by: 10))` in SwiftUI to re-render every 10 seconds — no timer management needed in the store.

```swift
// In UsagePanelView, inside normalState(response:)
TimelineView(.periodic(from: .now, by: 10)) { context in
    if let lastFetched = store.lastFetchedAt {
        Text(relativeTimeString(from: lastFetched, to: context.date))
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}
```

**Changes required:**

| Component | Change Type | What Changes |
|-----------|-------------|--------------|
| `UsageStore` | Modify | Add `var lastFetchedAt: Date?`; set in `fetchUsage()` success branch |
| `UsagePanelView` | Modify | Add `TimelineView`-wrapped timestamp display |

---

### Feature 5: Manual Refresh Button

**What it needs:** A "Refresh" button in the panel that triggers an immediate `fetchUsage()` call.

**Integration point:** `UsageStore.fetchUsage()` is already `async` and `public`. The button just calls it.

**Constraint:** Must show a loading/in-progress state to prevent double-taps. Add `var isFetching: Bool = false` to `UsageStore`.

```swift
// In UsageStore
var isFetching: Bool = false

func fetchUsage() async {
    guard !isFetching else { return }
    isFetching = true
    defer { isFetching = false }
    // ... existing fetch logic
}
```

**UI placement:** Add to `bottomRow()` in `UsagePanelView` alongside the Quit button, or as a standalone row near the timestamp. A `ProgressView` appears when `store.isFetching == true`.

**Changes required:**

| Component | Change Type | What Changes |
|-----------|-------------|--------------|
| `UsageStore` | Modify | Add `var isFetching: Bool`; guard against re-entry in `fetchUsage()` |
| `UsagePanelView` | Modify | Add refresh `Button` with `ProgressView` conditional on `store.isFetching` |

**Note:** The polling loop calls `fetchUsage()` every 60 seconds — the `isFetching` guard prevents a manual refresh from racing with a scheduled poll.

---

### Feature 6: OAuth Token Refresh

**What it needs:** When the access token is expired (or a 401 is returned), attempt to refresh using the stored `refreshToken` before showing an auth error.

**This is the most architecturally significant feature.** It touches every layer.

**Refresh protocol facts (from existing codebase / CLAUDE.md):**
- `ClaudeOAuthCredentials` already stores `refreshToken: String` and `expiresAt: Int64`
- `isExpired: Bool` computed property already exists on `ClaudeOAuthCredentials`
- Refresh endpoint: `POST https://console.anthropic.com/v1/oauth/token`
- Payload: `grant_type: refresh_token`, `refresh_token: <token>`, `client_id: 9d1c250a-e61b-44d9-88ed-5944d1962f5e`
- Refresh tokens rotate on use — must save both new `accessToken` AND new `refreshToken` back to Keychain
- Current `KeychainService` has NO write path — this must be added

**New component required:** `OAuthRefreshService`

```swift
// New file: Services/OAuthRefreshService.swift
struct OAuthRefreshService {
    private static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    func refresh(using refreshToken: String) async -> Result<ClaudeOAuthCredentials, AppError>
}
```

**KeychainService write path required:**

```swift
// Add to KeychainService.swift
func writeClaudeCredentials(_ credentials: ClaudeOAuthCredentials) throws
```

The write path uses `SecItemUpdate` if the item exists, `SecItemAdd` if not. The JSON structure must match what Claude Code writes: `{ "claudeAiOauth": { ... } }` (the `KeychainWrapper` struct already models this).

**Refresh trigger locations — two places:**

1. **Proactive (on load):** `UsageStore.loadCredentials()` already checks `creds.isExpired` and sets `credentialError = .apiUnauthorized`. Change this branch to attempt refresh before giving up.

2. **Reactive (on 401):** `UsageStore.fetchUsage()` handles `.apiUnauthorized` by setting `menuBarTitle = "Auth expired"`. Change this branch to call refresh, then retry the original `fetchUsage()` call once (with a flag to prevent infinite loops).

**Refresh flow:**

```
fetchUsage() receives 401
    ↓
refreshAttempted == false?  (guard against loop)
    ↓ YES
OAuthRefreshService.refresh(using: credentials.refreshToken)
    ├── .success(newCreds)
    │       ↓
    │   KeychainService.writeClaudeCredentials(newCreds)
    │       ↓
    │   self.credentials = newCreds
    │   refreshAttempted = true
    │       ↓
    │   retry fetchUsage()  (will use new token)
    │       ↓
    │   refreshAttempted = false  (reset after retry completes)
    │
    └── .failure
            ↓
        credentials = nil
        credentialError = .apiUnauthorized
        menuBarTitle = "Auth expired"
```

**Changes required:**

| Component | Change Type | What Changes |
|-----------|-------------|--------------|
| `Services/OAuthRefreshService.swift` | New | POST to token endpoint, decode response, return new credentials |
| `KeychainService` | Modify | Add `writeClaudeCredentials(_:)` using `SecItemAdd` / `SecItemUpdate` |
| `CredentialsService` | Modify | Call `OAuthRefreshService` when loaded credentials are expired |
| `UsageStore` | Modify | Handle 401 → refresh → retry; add `private var refreshAttempted: Bool` flag |
| `AppError` | Modify | Add `.tokenRefreshFailed` case for failed refresh attempts |

---

## New Components Summary

| File | Type | Purpose |
|------|------|---------|
| `Models/ThresholdSettings.swift` | New | UserDefaults-backed threshold configuration |
| `Services/OAuthRefreshService.swift` | New | POST refresh token, decode new credentials |

## Modified Components Summary

| File | Features | Changes |
|------|----------|---------|
| `StatusBarController` | 1, 2 | `updateTitle(_:color:)` with `NSAttributedString`; `.isTemplate = true` on icon |
| `UsageStore` | 1, 4, 5, 6 | `onTitleChanged` carries color; `lastFetchedAt`; `isFetching`; refresh-retry flow; `ThresholdSettings` instance |
| `AppDelegate` | 1 | Callback wiring updated for `(String, NSColor)` |
| `UsagePanelView` | 3, 4, 5 | Threshold UI, timestamp `TimelineView`, refresh button |
| `KeychainService` | 6 | Add `writeClaudeCredentials(_:)` |
| `CredentialsService` | 6 | Proactive refresh on expired token |
| `AppError` | 6 | Add `.tokenRefreshFailed` |

---

## Data Flow Changes

### Color Flow (Features 1 + 3)

```
Before:
UsageStore.fetchUsage() → menuBarTitle: String → onTitleChanged(String) → StatusBarController.updateTitle(String) → button.title

After:
UsageStore.fetchUsage() → menuBarTitle: String + color(from: thresholds, utilization) → onTitleChanged(String, NSColor) → StatusBarController.updateTitle(String, NSColor) → button.attributedTitle
```

### Refresh Flow (Feature 6)

```
Before:
fetchUsage() 401 → credentialError = .apiUnauthorized → stop

After:
fetchUsage() 401 → OAuthRefreshService.refresh() → KeychainService.write() → credentials updated → fetchUsage() retry (once)
```

### Timestamp Flow (Feature 4)

```
After:
fetchUsage() .success → lastFetchedAt = Date() → TimelineView in UsagePanelView re-renders every 10s → relative string
```

---

## Suggested Build Order

Dependencies drive this order. Each step is independently testable before the next begins.

### Step 1: Template Icon (Feature 2)
**Why first:** One-line change to `StatusBarController.init()` plus asset catalog update. Zero risk, zero dependencies. Validates the icon rendering pipeline before touching anything else.

**Files:** `StatusBarController.swift`, `Assets.xcassets`

### Step 2: ThresholdSettings + UserDefaults persistence (Feature 3, data layer only)
**Why second:** `ThresholdSettings` struct has no dependencies. Adding it to `UsageStore` is additive. The UI for configuring thresholds can come later. Building the model first means Feature 1's color logic has something to read from.

**Files:** `Models/ThresholdSettings.swift` (new), `UsageStore.swift`

### Step 3: Color-coded menu bar text (Feature 1)
**Why third:** Depends on Step 2 (needs `ThresholdSettings`). Requires changing the `onTitleChanged` callback signature — do this once, not twice.

**Files:** `UsageStore.swift`, `AppDelegate.swift`, `StatusBarController.swift`

### Step 4: Last-updated timestamp + manual refresh (Features 4 + 5)
**Why together:** Both are additive changes to `UsageStore` (`lastFetchedAt`, `isFetching`) and both only affect `UsagePanelView`. Doing them in one pass avoids opening the same two files twice. Neither has risky side effects.

**Files:** `UsageStore.swift`, `Views/UsagePanelView.swift`

### Step 5: Threshold configuration UI (Feature 3, UI layer)
**Why fifth:** The data model (Step 2) is already in place. Adding the UI row to `UsagePanelView` is isolated. This step also validates the threshold persists correctly across popover open/close.

**Files:** `Views/UsagePanelView.swift`

### Step 6: OAuth token refresh (Feature 6)
**Why last:** Highest risk and most files touched. Requires a new service, Keychain write path, two new trigger points in `UsageStore`, and a new error case. Build this after all visual features are stable so a regression is immediately distinguishable from a pre-existing issue. Test by manually expiring a token (temporarily adjust `expiresAt` to a past epoch).

**Files:** `Services/OAuthRefreshService.swift` (new), `Services/KeychainService.swift`, `Services/CredentialsService.swift`, `Store/UsageStore.swift`, `Models/AppError.swift`

---

## Integration Risks

| Risk | Feature | Severity | Mitigation |
|------|---------|----------|------------|
| `attributedTitle` width wider than `title` — menu bar shifts | 1 | Low | Match font to current title font (`NSFont.menuBarFont(ofSize: 0)`); measure in practice |
| Refresh token rotation — must write BOTH tokens or next refresh fails | 6 | High | Write entire `ClaudeOAuthCredentials` struct (not just access token); log what was written |
| `SecItemUpdate` vs `SecItemAdd` on Keychain write — wrong call causes `errSecDuplicateItem` | 6 | Medium | Try `SecItemUpdate` first; if `errSecItemNotFound`, fall through to `SecItemAdd` |
| `isFetching` guard blocks manual refresh while poll is mid-flight | 5 | Low | Acceptable UX — button shows spinner; user retries when poll finishes |
| `TimelineView` periodic redraws while popover is hidden | 4 | Low | SwiftUI pauses updates for off-screen views; not a real concern |
| Infinite refresh loop if new access token also returns 401 | 6 | High | `refreshAttempted: Bool` flag strictly prevents second refresh attempt in same fetch call |

---

## What Does NOT Need to Change

- `PulseCheckApp.swift` — no changes needed
- `Models/UsageResponse.swift` — no changes needed
- `Models/AppError.swift` — additive only (new case), no existing cases change
- The 60-second polling loop structure — no changes needed
- `KeychainWrapper` / `ClaudeOAuthCredentials` struct shape — already has `refreshToken`

---

*Architecture research for: v2.0 feature integration*
*Based on: direct source reading of all 9 files (535 LOC)*
*Researched: 2026-04-02*
