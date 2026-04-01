# Architecture Research

**Domain:** macOS menu bar utility app (SwiftUI + AppKit hybrid)
**Researched:** 2026-04-02
**Confidence:** HIGH — patterns are well-documented across official Apple docs and multiple production apps

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        App Entry Point                           │
│  ClaudeMacWidgetApp (@main, App protocol)                        │
│  Info.plist: LSUIElement = YES  (no Dock icon)                   │
└────────────────────────────┬────────────────────────────────────┘
                             │ owns
┌────────────────────────────▼────────────────────────────────────┐
│                    Menu Bar Controller                            │
│  NSStatusBar.system.statusItem                                   │
│  NSStatusItem.button  ← title: "42%"  (live text update)        │
│  NSStatusItem.button.action → togglePanel()                      │
└────────────────────────────┬────────────────────────────────────┘
                             │ presents
┌────────────────────────────▼────────────────────────────────────┐
│                    Panel / Popover Layer                          │
│  NSPopover  ←→  NSHostingController<PanelView>                   │
│  PanelView (SwiftUI):                                            │
│    - UsageMeter (daily)                                          │
│    - UsageMeter (weekly)                                         │
│    - ResetCountdown                                              │
│    - SetupPrompt (if no API key)                                 │
└────────────────────────────┬────────────────────────────────────┘
                             │ observes
┌────────────────────────────▼────────────────────────────────────┐
│                    App State (@Observable)                        │
│  UsageStore                                                      │
│    - dailyUsed: Int                                              │
│    - dailyLimit: Int                                             │
│    - weeklyUsed: Int                                             │
│    - weeklyLimit: Int                                            │
│    - resetAt: Date?                                              │
│    - lastFetched: Date?                                          │
│    - error: AppError?                                            │
│    - hasAPIKey: Bool                                             │
└──────────────┬──────────────────────────┬───────────────────────┘
               │ drives                   │ reads/writes
┌──────────────▼──────────┐  ┌────────────▼───────────────────────┐
│    Polling Service       │  │       Keychain Service              │
│  Timer (60s interval)    │  │  SecItemAdd / SecItemCopyMatching   │
│  Task { await fetch() }  │  │  kSecClassGenericPassword           │
│  URLSession              │  │  service: "com.app.anthropic-key"   │
│  AnthropicAPIClient      │  └────────────────────────────────────┘
└──────────────┬───────────┘
               │ calls
┌──────────────▼──────────────────────────────────────────────────┐
│                 External: Anthropic API                           │
│  GET /v1/usage  (or equivalent usage/limits endpoint)            │
│  Authorization: Bearer <key>                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|----------------|----------------|
| `ClaudeMacWidgetApp` | Entry point; wires all components together; sets `.accessory` activation policy | `@main struct`, `App` protocol |
| `StatusBarController` | Owns `NSStatusItem`; updates button title with usage %; handles click → show/hide panel | AppKit class, `@MainActor` |
| `UsageStore` | Single source of truth for all usage data; observed by both StatusBarController and SwiftUI views | `@Observable` class |
| `PollingService` | Fires a 60-second `Timer`; calls API; writes results to `UsageStore`; handles errors/retries | Swift actor or class |
| `AnthropicAPIClient` | HTTP request construction, auth header injection, JSON decoding | `struct`, uses `URLSession` |
| `KeychainService` | Read/write API key to macOS Keychain via `SecItem` API | `struct` with static helpers |
| `PanelView` | SwiftUI root view inside the popover; routes to `SetupView` or `UsageView` based on state | `View` struct |
| `SetupView` | First-run API key entry and Keychain save flow | `View` struct |
| `UsageView` | Shows daily/weekly meters and reset countdown | `View` struct |

## Recommended Project Structure

```
ClaudeMacWidget/
├── App/
│   ├── ClaudeMacWidgetApp.swift     # @main, App protocol, scene wiring
│   └── Info.plist                   # LSUIElement = YES
├── StatusBar/
│   ├── StatusBarController.swift    # NSStatusItem, click handling, title update
│   └── AppDelegate.swift            # applicationDidFinishLaunching (if using AppKit lifecycle)
├── Panel/
│   ├── PanelView.swift              # Root SwiftUI view shown in popover
│   ├── UsageView.swift              # Daily/weekly meters, reset countdown
│   └── SetupView.swift              # First-run API key entry
├── Services/
│   ├── UsageStore.swift             # @Observable state container
│   ├── PollingService.swift         # Timer + fetch loop
│   ├── AnthropicAPIClient.swift     # API calls, decoding
│   └── KeychainService.swift        # SecItem read/write
└── Models/
    ├── UsageResponse.swift          # Decodable API response shapes
    └── AppError.swift               # Typed error enum
```

### Structure Rationale

- **App/**: Entry point separated from feature code; makes activation policy and lifecycle wiring explicit.
- **StatusBar/**: AppKit integration isolated here; nothing outside this folder touches `NSStatusItem`.
- **Panel/**: All SwiftUI panel views together; no AppKit dependencies inside.
- **Services/**: Business logic with no UI dependencies; unit-testable in isolation.
- **Models/**: Pure data types; no behavior, no imports except Foundation.

## Architectural Patterns

### Pattern 1: AppKit Shell + SwiftUI Interior

**What:** `NSStatusItem` and `NSPopover` are the AppKit shell. Everything inside the popover is pure SwiftUI. The shell uses `NSHostingController` to bridge.

**When to use:** Always for menu bar apps. Apple's own HIG says to show a menu (or popover) from the status item, and SwiftUI `MenuBarExtra` has too many limitations for a data-display utility (no programmatic show/hide, restricted button customization, lacks right-click support as of 2025).

**Trade-offs:** ~30% AppKit code, but it is contained in one file (`StatusBarController`). The rest of the app is pure Swift/SwiftUI.

**Example:**
```swift
// StatusBarController.swift
class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover = NSPopover()

    init(store: UsageStore) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "—%"
        statusItem.button?.action = #selector(togglePopover)
        popover.contentViewController = NSHostingController(rootView: PanelView(store: store))
        popover.behavior = .transient  // dismisses on outside click
    }
}
```

### Pattern 2: @Observable State Container (UsageStore)

**What:** A single `@Observable` class holds all runtime state. Both the AppKit layer and SwiftUI views observe it. No `NotificationCenter`, no Combine pipelines in the view layer.

**When to use:** Swift 5.9+ / macOS 14+. If macOS 13 support is needed, fall back to `@ObservableObject` + `@Published`.

**Trade-offs:** Clean unidirectional data flow; requires iOS 17 / macOS 14 minimum for `@Observable` macro. For this app (menu bar utility, not App Store), targeting macOS 14+ is reasonable.

**Example:**
```swift
// UsageStore.swift
@Observable
final class UsageStore {
    var dailyUsed: Int = 0
    var dailyLimit: Int = 0
    var weeklyUsed: Int = 0
    var weeklyLimit: Int = 0
    var resetAt: Date? = nil
    var error: AppError? = nil
    var hasAPIKey: Bool = false

    var dailyPercent: Double {
        guard dailyLimit > 0 else { return 0 }
        return Double(dailyUsed) / Double(dailyLimit)
    }
}
```

### Pattern 3: Timer-Driven Polling with Swift Concurrency

**What:** A `Timer.scheduledTimer` (or `AsyncStream` via `Timer.publish`) fires every 60 seconds. Each tick launches a Swift `Task` that `await`s the API call and writes results back on `@MainActor`.

**When to use:** For periodic background work that must update UI. Prefer `Task { @MainActor in }` over `DispatchQueue.main.async` in Swift 6 codebases.

**Trade-offs:** Timer is simple but not backoff-aware. Add exponential backoff on consecutive errors to avoid hammering the API when auth fails.

**Example:**
```swift
// PollingService.swift
@MainActor
class PollingService {
    private var timer: Timer?
    private let client: AnthropicAPIClient
    private let store: UsageStore

    func start() {
        fetch()  // immediate first fetch
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.fetch() }
        }
    }

    private func fetch() async {
        do {
            let result = try await client.fetchUsage()
            store.dailyUsed = result.daily.used
            store.dailyLimit = result.daily.limit
            // ... update rest
            store.error = nil
        } catch {
            store.error = .network(error)
        }
    }
}
```

## Data Flow

### Startup Flow

```
App launch
    ↓
ClaudeMacWidgetApp.init()
    ↓ creates
UsageStore + KeychainService + AnthropicAPIClient + PollingService
    ↓ creates
StatusBarController(store:)  →  NSStatusItem appears in menu bar
    ↓
KeychainService.readAPIKey()
    ├── key found → PollingService.start()  →  first fetch fires immediately
    └── key missing → store.hasAPIKey = false  →  PanelView shows SetupView
```

### User Click Flow

```
User clicks menu bar item
    ↓
StatusBarController.togglePopover()
    ↓
NSPopover.show(relativeTo: button)
    ↓
PanelView renders from UsageStore state
    ├── hasAPIKey == false  →  SetupView
    └── hasAPIKey == true   →  UsageView (daily, weekly, countdown)
```

### Polling Flow

```
Timer fires (every 60s)
    ↓
PollingService.fetch()
    ↓
AnthropicAPIClient.fetchUsage()
    ↓  (URLSession async/await)
Anthropic API  →  JSON response
    ↓
Decode to UsageResponse
    ↓
@MainActor: UsageStore fields updated
    ↓ (@Observable triggers redraw)
StatusBarController reads store.dailyPercent → updates NSStatusItem.button.title
PanelView re-renders if visible
```

### First-Run / API Key Flow

```
SetupView: user types API key → taps Save
    ↓
KeychainService.saveAPIKey(key)
    ↓
store.hasAPIKey = true
PollingService.start()
    ↓
First fetch fires → store populated → UsageView shown
```

### Key Data Flows Summary

1. **Inbound (API → UI):** Anthropic API → `AnthropicAPIClient` → `UsageStore` → SwiftUI views + status bar title
2. **Outbound (user → storage):** `SetupView` → `KeychainService` → Keychain; side-effect: `PollingService.start()`
3. **Timer → fetch:** `PollingService` owns the timer; `AnthropicAPIClient` is stateless; all state lives in `UsageStore`

## Scaling Considerations

This is a single-user local app. "Scaling" means complexity growth, not load:

| Concern | Current scope | If features expand |
|---------|---------------|-------------------|
| Multiple API keys / accounts | Not needed v1 | Add account list to Keychain, `UsageStore` keyed by account |
| Historical charts | Out of scope v1 | Add SQLite via GRDB or CoreData; PollingService writes to DB |
| Notifications (threshold alerts) | Simple v1 (color change) | `UNUserNotificationCenter` in `PollingService` when threshold crossed |
| Multiple menu bar items | Not needed | `StatusBarController` can manage array of `NSStatusItem` |

## Anti-Patterns

### Anti-Pattern 1: Using SwiftUI MenuBarExtra for a Data-Display Utility

**What people do:** Use `MenuBarExtra` scene because it looks simpler in tutorials.

**Why it's wrong:** `MenuBarExtra` does not expose the underlying `NSStatusItem`, has no programmatic show/hide API, and cannot display arbitrary text (only image or image+label with tight constraints). For a usage percentage display that needs to update every 60 seconds, you need direct `NSStatusItem.button.title` access.

**Do this instead:** Use `NSStatusItem` directly in `StatusBarController`. Keep SwiftUI for the popover content only. The overhead is one extra file.

### Anti-Pattern 2: Storing the API Key in UserDefaults

**What people do:** `UserDefaults.standard.set(apiKey, forKey: "anthropicKey")` — it's one line.

**Why it's wrong:** `UserDefaults` is plain text on disk, readable by any process with the same bundle ID or by anyone with disk access. API keys stored this way have leaked in crash reports, backups, and log files.

**Do this instead:** `KeychainService.save(key, service: "com.yourapp.anthropic-key")` using `SecItemAdd`. The macOS Keychain encrypts at rest and is access-controlled per-app.

### Anti-Pattern 3: Updating UI from Background Thread

**What people do:** Call `store.dailyUsed = result` directly inside a `URLSession` completion handler without dispatching to main.

**Why it's wrong:** `@Observable` (and `@ObservableObject`) are not thread-safe. Mutating them off the main actor causes data races and undefined behavior; Swift 6 strict concurrency will flag this as a compiler error.

**Do this instead:** Mark `PollingService` as `@MainActor`, or use `Task { @MainActor in store.dailyUsed = result }` to cross actor boundaries explicitly.

### Anti-Pattern 4: Polling Without Error Backoff

**What people do:** Fixed 60-second timer that retries unconditionally on every failure.

**Why it's wrong:** If the API key is invalid or revoked, the app will hammer the Anthropic API 1440 times/day generating noise in audit logs and burning rate limit quota.

**Do this instead:** Track consecutive error count in `PollingService`. After 3 consecutive failures, show a persistent error in `UsageStore.error` and stop the timer until the user dismisses the error or re-enters the key.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Anthropic API | `URLSession` async/await, `Bearer` token in `Authorization` header | Verify the exact usage endpoint path before coding; not yet confirmed as public |
| macOS Keychain | `SecItemAdd` / `SecItemCopyMatching` with `kSecClassGenericPassword` | Requires no special entitlements for non-App Store distribution |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `StatusBarController` ↔ `UsageStore` | Direct observation via `@Observable`; `StatusBarController` polls `store.dailyPercent` in a `withObservationTracking` loop or re-subscribes on update | AppKit does not natively observe `@Observable`; may need Combine bridge or explicit callback |
| `PollingService` ↔ `AnthropicAPIClient` | Direct method call (`await client.fetchUsage()`) | `AnthropicAPIClient` is a stateless struct; injected into `PollingService` for testability |
| `PanelView` ↔ `UsageStore` | SwiftUI `@Bindable` or environment injection | Standard SwiftUI observation |
| `SetupView` ↔ `KeychainService` | Direct call on button action | `KeychainService` throws on failure; surface error inline in `SetupView` |

## Build Order Implications

Dependencies between components determine phase sequence:

1. **Foundation first:** `UsageStore` + `AppError` + `Models` — everything else depends on these types.
2. **Keychain second:** `KeychainService` — needed before polling can start; blocks first-run flow.
3. **App entry + StatusBar third:** `ClaudeMacWidgetApp` + `StatusBarController` — establishes the menu bar presence; can show placeholder "—%" initially.
4. **Panel views fourth:** `SetupView` + `UsageView` — wired to `UsageStore`; can be built and iterated independently once store exists.
5. **Polling last:** `AnthropicAPIClient` + `PollingService` — plugs into existing store; brings real data in.

This order means the UI shell is testable manually before any API code is written.

## Sources

- [A menu bar only macOS app using AppKit — polpiella.dev](https://www.polpiella.dev/a-menu-bar-only-macos-app-using-appkit/)
- [What I Learned Building a Native macOS Menu Bar App — DEV Community](https://dev.to/heocoi/what-i-learned-building-a-native-macos-menu-bar-app-4im6)
- [Hands-on: building a Menu Bar experience with SwiftUI — Cindori](https://cindori.com/developer/hands-on-menu-bar)
- [Pushing the limits of NSStatusItem — Multi.app](https://multi.app/blog/pushing-the-limits-nsstatusitem)
- [The Mac Menubar and SwiftUI — TrozWare (2025)](https://troz.net/post/2025/mac_menu_data/)
- [Build a macOS menu bar utility in SwiftUI — nilcoalescing.com](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)
- [NSStatusItem — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nsstatusitem)
- [Storing Keys in the Keychain — Apple Developer Documentation](https://developer.apple.com/documentation/security/storing-keys-in-the-keychain)
- [MenuBarExtraAccess — orchetect/MenuBarExtraAccess (GitHub)](https://github.com/orchetect/MenuBarExtraAccess) (documents MenuBarExtra limitations)

---
*Architecture research for: macOS menu bar utility (Claude Code usage display)*
*Researched: 2026-04-02*
