# Phase 1: Foundation - Research

**Researched:** 2026-04-02
**Domain:** macOS menu bar app — Xcode project scaffold, NSStatusItem, Keychain credential read, OAuth API verification
**Confidence:** HIGH (API endpoint empirically verified, Keychain structure confirmed on target machine, stack is native Apple frameworks)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**App Structure**
- Xcode project (not SPM) — standard for macOS apps, needed for Info.plist and entitlements
- Minimum deployment target: macOS 14 (Sonoma) — enables @Observable and modern Swift concurrency
- App name: ClaudeUsage, bundle ID: com.jo.ClaudeUsage
- NSStatusItem + NSPopover architecture (not MenuBarExtra) — research confirms MenuBarExtra can't update title text dynamically

**Credential Reading**
- Keychain service name: "Claude Code-credentials" — this is the entry Claude Code uses
- Fallback path: ~/.claude/.credentials.json
- When no credentials found: show "No credentials" in menu bar text, log to console
- No UserDefaults state in Phase 1 — credentials in Keychain only

**API Verification**
- Try `GET /api/oauth/usage` with `anthropic-beta: oauth-2025-04-20` header first
- Build thin abstraction layer — parse response into typed Swift models, easy to swap endpoint later
- If endpoint doesn't work: log raw response, show "API unavailable" in menu bar — fail gracefully

### Claude's Discretion

- Internal code organization (file/folder structure within Xcode project)
- Error logging approach (OSLog vs print)
- Exact Codable model field names (discover from actual API response)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | App reads Claude Code OAuth token from macOS Keychain on launch | Keychain entry confirmed present; service name "Claude Code-credentials", account "jo", class genp; token is nested under key `claudeAiOauth` as a JSON blob |
| AUTH-02 | App falls back to reading `~/.claude/.credentials.json` if Keychain entry not found | File is absent on this machine (normal — macOS Keychain is primary); fallback code must handle missing file gracefully |
| LIFE-01 | App runs as LSUIElement (no Dock icon) | Requires `LSUIElement = YES` in Info.plist; confirmed required pattern for NSStatusItem apps |
| LIFE-02 | Dropdown includes Quit menu item | NSMenu item calling `NSApp.terminate(nil)`; essential because no Dock icon means no Force Quit access |
</phase_requirements>

---

## Summary

Phase 1 delivers an Xcode project that launches with no Dock icon, shows "—%" in the menu bar, reads Claude Code credentials from Keychain, and makes one confirmed-working API call to `GET https://api.anthropic.com/api/oauth/usage`. The API endpoint was empirically verified on this machine and returns a 200 with real usage data.

The critical empirical finding is the Keychain token structure. The Keychain item at service name `Claude Code-credentials` stores a JSON object with a single top-level key `claudeAiOauth`, which contains `accessToken`, `refreshToken`, `expiresAt`, `scopes`, `subscriptionType`, and `rateLimitTier`. Prior research assumed a flat structure — the actual structure has one nesting level (`claudeAiOauth`). This directly affects `KeychainService` implementation.

The API response shape has also been confirmed empirically. The `utilization` field returns a percentage as a float (e.g., `51.0` for 51%, not `0.51`). The `resets_at` field is an ISO 8601 string with timezone offset. Nullable fields (`seven_day_oauth_apps`, `seven_day_opus`, `iguana_necktie`, `seven_day_cowork`) must be modeled as optionals. A new `extra_usage` object appeared in the live response that was not documented in prior research.

The development environment is Xcode 26.4 / Swift 6.3 on macOS 26.2 (Tahoe). The deployment target of macOS 14 is supported — Xcode builds with the macOS 26.4 SDK and can target older OS versions. `@Observable` requires macOS 14, which aligns with the locked deployment target.

**Primary recommendation:** Build in this order — (1) Info.plist + entitlements to establish LSUIElement and network sandbox entitlement, (2) AppDelegate + StatusBarController with hardcoded "—%", (3) KeychainService reading the `claudeAiOauth` nested object, (4) typed Swift models matching the empirically confirmed response shape, (5) a single non-polling API call to verify credentials round-trip.

---

## Standard Stack

### Core (all system frameworks — no third-party dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift | 6.3 (Xcode 26.4) | Primary language | Installed, verified. Strict concurrency prevents data-race bugs in polling + UI path |
| AppKit (NSStatusItem, NSPopover) | macOS 14+ | Menu bar shell | Required for programmatic title updates and show/hide control; MenuBarExtra cannot do this |
| SwiftUI | macOS 14+ | Panel interior views | SwiftUI inside NSHostingController; not used for the status bar chrome itself |
| Security framework | macOS 10.9+ | Keychain read | `SecItemCopyMatching` with `kSecClassGenericPassword`; reads existing Claude Code token |
| Foundation (URLSession, JSONDecoder) | Built-in | API call + JSON parsing | Async/await URLSession; Codable structs with JSONDecoder |
| Observation (@Observable) | macOS 14+ | State container | `@Observable` replaces `@Published`/ObservableObject in Swift 5.9+; macOS 14 minimum aligns with deployment target |
| OSLog | macOS 11+ | Structured logging | Preferred over `print()` — messages appear in Console.app with subsystem filtering |

### No Third-Party Dependencies in Phase 1

This phase uses only system frameworks. Do not add any Swift packages in Phase 1.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSStatusItem + NSPopover | MenuBarExtra (.window) | MenuBarExtra cannot update `button.title` dynamically from code; NSStatusItem is required for live percentage display |
| @Observable | ObservableObject + @Published | @Observable has less boilerplate; macOS 14 minimum makes it safe |
| OSLog | print() | OSLog is structured, filterable in Console.app, redacts sensitive data; print is acceptable for phase 1 if simpler |

**No installation step** — all stack components are system frameworks bundled with macOS/Xcode.

---

## Architecture Patterns

### Recommended Project Structure

```
ClaudeUsage/
├── ClaudeUsageApp.swift      # @main, AppDelegate hookup, StatusBarController lifetime
├── AppDelegate.swift         # applicationDidFinishLaunching, StatusBarController stored prop
├── StatusBarController.swift # NSStatusItem, NSPopover, click handler, title update
├── Models/
│   ├── UsageResponse.swift   # Codable; all API response fields including nullables
│   └── AppError.swift        # Typed error enum for Keychain + API failures
├── Services/
│   ├── KeychainService.swift # SecItemCopyMatching; reads claudeAiOauth nested object
│   └── CredentialsService.swift  # Orchestrates Keychain → file fallback → missing
├── Store/
│   └── UsageStore.swift      # @Observable; single source of truth; holds credentials + API result
└── Resources/
    ├── Info.plist            # LSUIElement = YES, CFBundleIdentifier = com.jo.ClaudeUsage
    └── ClaudeUsage.entitlements  # com.apple.security.network.client = YES
```

### Pattern 1: NSStatusItem with App-Level Lifetime

**What:** `NSStatusItem` must be stored as an instance property on a class with app-level lifetime. ARC will deallocate it if stored in a local variable.

**When to use:** Always. This is the only correct pattern.

```swift
// Source: Apple Developer Documentation — NSStatusItem
class AppDelegate: NSObject, NSApplicationDelegate {
    // Stored property — survives for app lifetime
    var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
    }
}
```

### Pattern 2: LSUIElement — No Dock Icon

**What:** Info.plist key that prevents the app from appearing in the Dock or App Switcher.

**When to use:** All menu bar utility apps without a main window.

```xml
<!-- Info.plist -->
<key>LSUIElement</key>
<true/>
```

Combined with `NSApp.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching` for Belt-and-suspenders coverage.

### Pattern 3: Keychain Read — Nested claudeAiOauth Structure

**What:** The Claude Code Keychain item stores a JSON blob. The outer key is `claudeAiOauth`. This nesting was confirmed empirically on this machine.

**When to use:** AUTH-01 implementation.

```swift
// Source: empirical verification on this machine + Apple TN3137
func readClaudeCredentials() throws -> ClaudeOAuthCredentials {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "Claude Code-credentials",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
        throw AppError.keychainReadFailed(status)
    }
    // Outer wrapper: { "claudeAiOauth": { ... } }
    let wrapper = try JSONDecoder().decode(KeychainWrapper.self, from: data)
    return wrapper.claudeAiOauth
}

struct KeychainWrapper: Decodable {
    let claudeAiOauth: ClaudeOAuthCredentials
}

struct ClaudeOAuthCredentials: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64        // milliseconds since epoch
    let scopes: [String]
    let subscriptionType: String?
    let rateLimitTier: String?
}
```

### Pattern 4: File Fallback — AUTH-02

**What:** If Keychain read fails (item absent or access denied), try `~/.claude/.credentials.json`. This file is absent on this machine (macOS Keychain is primary), so the code path must be tested with a mocked missing file.

**When to use:** AUTH-02 — only when Keychain returns `errSecItemNotFound`.

```swift
// Source: CONTEXT.md decision; file path documented in project research
func readCredentialsFromFile() throws -> ClaudeOAuthCredentials {
    let path = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/.credentials.json")
    let data = try Data(contentsOf: path)
    // Credentials JSON may have the same claudeAiOauth wrapper or flat structure
    // Parse defensively — try wrapper first, fall back to flat
    if let wrapper = try? JSONDecoder().decode(KeychainWrapper.self, from: data) {
        return wrapper.claudeAiOauth
    }
    return try JSONDecoder().decode(ClaudeOAuthCredentials.self, from: data)
}
```

**Note:** The `~/.claude/.credentials.json` file does not exist on this machine. Its exact structure is unverified. The fallback should parse both wrapper and flat structures defensively.

### Pattern 5: API Call — Confirmed Working Request

**What:** The exact headers and URL confirmed empirically to return 200 with usage data.

**When to use:** API verification in Phase 1; basis for AnthropicAPIClient in Phase 2.

```swift
// Source: empirical verification — 200 response confirmed on this machine
var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
request.setValue("application/json", forHTTPHeaderField: "Accept")

let (data, response) = try await URLSession.shared.data(for: request)
let httpResponse = response as! HTTPURLResponse
// httpResponse.statusCode == 200 confirmed
let usage = try JSONDecoder().decode(UsageResponse.self, from: data)
```

### Pattern 6: UsageResponse Codable Model — Confirmed Response Shape

**What:** The exact fields confirmed from live API call on this machine.

```swift
// Source: empirical — live API response 2026-04-02
struct UsageResponse: Decodable {
    let fiveHour: UsagePeriod?
    let sevenDay: UsagePeriod?
    let sevenDayOauthApps: UsagePeriod?
    let sevenDayOpus: UsagePeriod?
    let sevenDaySonnet: UsagePeriod?
    let sevenDayCowork: UsagePeriod?
    let iguanaNecktie: UsagePeriod?     // internal codename field; keep as optional
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayCowork = "seven_day_cowork"
        case iguanaNecktie = "iguana_necktie"
        case extraUsage = "extra_usage"
    }
}

struct UsagePeriod: Decodable {
    let utilization: Double     // PERCENTAGE 0–100, NOT decimal 0–1. Confirmed: 51.0 = 51%
    let resetsAt: String        // ISO 8601 with timezone offset e.g. "2026-04-02T09:00:00.823692+00:00"

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct ExtraUsage: Decodable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }
}
```

**Critical:** `utilization` is already a percentage (0–100). Do not multiply by 100 when displaying.

### Pattern 7: Network Sandbox Entitlement

**What:** macOS sandboxed apps require explicit entitlement to make outbound network connections. Without this the URLSession call silently fails.

**When to use:** Required in the `.entitlements` file for all macOS apps that make network requests.

```xml
<!-- ClaudeUsage.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### Anti-Patterns to Avoid

- **Storing NSStatusItem in a local variable:** Silent deallocation, icon vanishes. Always store on a class property with app-level lifetime.
- **Decoding the Keychain JSON as a flat ClaudeOAuthCredentials struct:** The actual JSON has a `claudeAiOauth` wrapper object. Flat decode will fail.
- **Treating `utilization` as a 0-1 decimal:** The field is already a percentage (0-100). `51.0` means 51%, not 5100%.
- **Omitting the `com.apple.security.network.client` entitlement:** URLSession calls will silently fail under sandbox without it.
- **Using MenuBarExtra for the status bar:** Cannot update `button.title` dynamically. NSStatusItem is required.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keychain credential storage/read | Custom file encryption or UserDefaults | Security framework `SecItemCopyMatching` | UserDefaults is readable by any process; Keychain is hardware-backed encryption |
| JSON decoding | Custom string parsing | `JSONDecoder` + `Codable` | Edge cases in ISO 8601 dates, optional fields, null vs missing |
| Network requests | Custom URLConnection or CFSocket | `URLSession` async/await | URLSession handles TLS, redirects, timeout — one-liner with async/await |
| Menu bar lifecycle | Manually managing NSRunLoop | AppKit + NSApplication lifecycle | ARC + app delegate is the established pattern; manual RunLoop management is fragile |

**Key insight:** This phase is entirely first-party Apple frameworks. Any third-party dependency would add supply chain risk (per CLAUDE.md security requirements) without functional benefit.

---

## Common Pitfalls

### Pitfall 1: Keychain JSON Has a Wrapper Object (claudeAiOauth)

**What goes wrong:** Code decodes the Keychain data directly as `ClaudeOAuthCredentials`. Fails with "keyNotFound" because the actual JSON is `{ "claudeAiOauth": { ... } }`.

**Why it happens:** Prior research described the token as having `accessToken`, `refreshToken`, `expiresAt` at the top level. The actual Keychain item has one nesting level.

**How to avoid:** Always decode through `KeychainWrapper` first. Use the struct in Pattern 3 above.

**Warning signs:** `keyNotFound("accessToken")` error during Keychain decode.

### Pitfall 2: utilization Is a Percentage (0-100), Not a Decimal (0-1)

**What goes wrong:** Code multiplies `utilization` by 100 before display, showing "5100%" for a 51% usage value.

**Why it happens:** Common API convention is to return 0-1 decimals for ratios. This API uses 0-100 percentages.

**How to avoid:** Use `utilization` directly for display. Confirmed from live response: value `51.0` corresponds to 51%.

**Warning signs:** Menu bar shows values over 100%.

### Pitfall 3: Missing network.client Entitlement Silently Blocks URLSession

**What goes wrong:** URLSession calls return `NSURLErrorCannotConnectToHost` or time out silently. No permission dialog appears. The API call simply fails.

**Why it happens:** macOS app sandbox requires explicit `com.apple.security.network.client` entitlement for outbound TCP. Without it, the sandbox blocks the connection at the kernel level with no user-visible prompt.

**How to avoid:** Add `com.apple.security.network.client = YES` to the `.entitlements` file before writing any network code.

**Warning signs:** URLSession errors on what should be a simple GET request; works in a command-line tool (unsandboxed) but not the app.

### Pitfall 4: NSStatusItem Garbage Collected (Menu Bar Icon Vanishes)

**What goes wrong:** Menu bar icon appears briefly then disappears silently. No error.

**Why it happens:** NSStatusItem stored in a local variable is deallocated when the function returns.

**How to avoid:** Store `NSStatusItem` as an instance property on `StatusBarController`, which is itself stored as a property on `AppDelegate`. The `AppDelegate` instance lives for the app's lifetime.

**Warning signs:** Icon appears then disappears; works after adding a breakpoint (which delays deallocation timing).

### Pitfall 5: App Shows Dock Icon Despite LSUIElement

**What goes wrong:** App appears in Dock and App Switcher, behaving like a regular app.

**Why it happens:** `LSUIElement` set in Info.plist is the required mechanism, but SwiftUI `@main App` structs may override this. Additionally, any `WindowGroup` scene causes Dock icon appearance.

**How to avoid:** Set `LSUIElement = YES` in Info.plist AND call `NSApp.setActivationPolicy(.accessory)` in `applicationDidFinishLaunching`. Do not use `WindowGroup` scene.

**Warning signs:** Dock icon appears; app shows in Cmd-Tab switcher.

### Pitfall 6: expiresAt Is Milliseconds, Not Seconds

**What goes wrong:** Token appears to expire in 1970 (or the year 55000+) because the code treats the millisecond timestamp as seconds.

**Why it happens:** The `expiresAt` field in the Keychain JSON is `1775132637626` — a Unix timestamp in **milliseconds**. Standard `Date(timeIntervalSince1970:)` expects seconds.

**How to avoid:** Divide by 1000 before constructing `Date`.

```swift
let expiryDate = Date(timeIntervalSince1970: TimeInterval(credentials.expiresAt) / 1000.0)
let isExpired = expiryDate < Date()
```

**Warning signs:** Token always appears expired; expiry date shows as Jan 1970 or year 57000+.

---

## Code Examples

### Full Keychain Read Flow

```swift
// Source: empirical verification on this machine; Apple TN3137
// Service name confirmed: "Claude Code-credentials"
// Account name confirmed: "jo" (matches local username — do NOT hardcode account name)
// Token structure confirmed: { "claudeAiOauth": { accessToken, refreshToken, expiresAt, scopes, ... } }

struct KeychainService {
    static let serviceName = "Claude Code-credentials"

    func readClaudeCredentials() throws -> ClaudeOAuthCredentials {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw AppError.keychainDataMalformed
            }
            let wrapper = try JSONDecoder().decode(KeychainWrapper.self, from: data)
            return wrapper.claudeAiOauth
        case errSecItemNotFound:
            throw AppError.keychainItemNotFound
        default:
            throw AppError.keychainReadFailed(status)
        }
    }
}
```

### StatusBarController Shell

```swift
// Source: Apple NSStatusBar documentation + PITFALLS.md pattern
// Owned by AppDelegate as a stored property — prevents GC
class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        if let button = statusItem.button {
            button.title = "—%"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    func updateTitle(_ text: String) {
        statusItem.button?.title = text
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

### Minimal NSMenu with Quit Item

```swift
// Source: Apple NSMenu documentation (LIFE-02 requirement)
// Called from StatusBarController init
private func buildMenu() -> NSMenu {
    let menu = NSMenu()
    let quitItem = NSMenuItem(
        title: "Quit ClaudeUsage",
        action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"
    )
    menu.addItem(quitItem)
    return menu
}
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build system | YES | 26.4 (Swift 6.3) | — |
| macOS | Deployment target | YES | 26.2 (Tahoe) | — |
| Claude Code Keychain entry | AUTH-01 | YES | service="Claude Code-credentials" present | File fallback (AUTH-02) |
| ~/.claude/.credentials.json | AUTH-02 | NO (absent on this machine) | — | Code path must be tested with missing-file mock |
| api.anthropic.com/api/oauth/usage | API verification | YES (confirmed 200) | — | Show "API unavailable" in menu bar |

**Missing dependencies with no fallback:** None — all required items are present.

**Missing dependencies with fallback:**
- `~/.claude/.credentials.json` is absent on this machine; the Keychain path works. File fallback code must handle `fileNotFound` gracefully without crashing.

---

## Empirically Confirmed Facts

These were verified by running actual commands on this machine on 2026-04-02:

| Fact | Verified Value | How Verified |
|------|---------------|--------------|
| Keychain service name | `Claude Code-credentials` | `security find-generic-password -s "Claude Code-credentials"` — item found |
| Keychain account name | `jo` (local username — do not hardcode) | `security find-generic-password` attribute output |
| Keychain JSON top-level key | `claudeAiOauth` | Decoded via Python: `list(d.keys()) == ['claudeAiOauth']` |
| Token sub-keys | `accessToken`, `refreshToken`, `expiresAt`, `scopes`, `subscriptionType`, `rateLimitTier` | Decoded via Python |
| expiresAt format | Milliseconds since epoch (e.g., `1775132637626`) | Confirmed: value > 1e12, divided by 1000 = valid 2026 date |
| Credentials file | Absent at `~/.claude/.credentials.json` | `ls ~/.claude/.credentials.json` — no such file |
| API endpoint | `GET https://api.anthropic.com/api/oauth/usage` | curl returned HTTP 200 |
| Required header | `anthropic-beta: oauth-2025-04-20` | Part of successful curl call |
| utilization semantics | Percentage 0-100 (e.g., `51.0` = 51%) | Live response: `five_hour.utilization = 51.0` |
| Response top-level keys | `five_hour`, `seven_day`, `seven_day_oauth_apps`, `seven_day_opus`, `seven_day_sonnet`, `seven_day_cowork`, `iguana_necktie`, `extra_usage` | Live JSON response |
| Nullable fields | `seven_day_oauth_apps`, `seven_day_opus`, `seven_day_cowork`, `iguana_necktie` were null | Live JSON response |
| extra_usage structure | `{ is_enabled, monthly_limit, used_credits, utilization }` all nullable | Live JSON response |
| OAuth client ID in binary | `9d1c250a-e61b-44d9-88ed-5944d1962f5e` | `grep` matched in Claude binary at `/Users/jo/.local/bin/claude` |
| Xcode version | 26.4 (build 17E192) | `xcodebuild -version` |
| Swift version | 6.3 | `swift --version` |
| macOS version | 26.2 (Tahoe) — NOT Sonoma/Sequoia | `sw_vers` |

**Note on macOS version:** The development machine runs macOS 26.2 (Tahoe), not macOS 14 (Sonoma) as stated in CONTEXT.md. The locked deployment target of macOS 14 remains valid — Xcode builds with the macOS 26.4 SDK and can target earlier OS versions. No change needed to the deployment target decision.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@Published` + `ObservableObject` | `@Observable` macro | Swift 5.9 / macOS 14 | Less boilerplate; no need to wrap in `@StateObject` or `@ObservedObject` everywhere |
| `MenuBarExtra` as menu bar solution | `NSStatusItem` for dynamic text | Always — MenuBarExtra never supported dynamic title | NSStatusItem is older but more capable for this use case |
| `SecItemAdd` for writing new tokens | Read-only from existing Claude Code entry | N/A (Phase 1 scope) | Phase 1 only reads; never writes to Keychain |

**Deprecated/outdated in scope:**
- `ObservableObject` + `@Published`: Still works, but `@Observable` is the modern pattern on macOS 14+.
- CocoaPods: Not applicable to this project; SPM is the only dependency manager needed.

---

## Open Questions

1. **Exact structure of `~/.claude/.credentials.json`**
   - What we know: File is absent on this machine; CONTEXT.md specifies it as the fallback path
   - What's unclear: Whether it uses the same `claudeAiOauth` wrapper or a flat structure
   - Recommendation: Parse defensively — try wrapper struct first, fall back to flat struct. Log which path succeeded.

2. **Keychain account name (`kSecAttrAccount`) requirement**
   - What we know: Account on this machine is `"jo"` (local username). The `security` CLI found the item without specifying account.
   - What's unclear: Whether `SecItemCopyMatching` without `kSecAttrAccount` returns the right item if multiple Claude Code users are on the same machine
   - Recommendation: Do NOT specify `kSecAttrAccount` in the query. Let the Keychain return the first matching item for the service name. This is what other tools do and avoids hardcoding a username.

3. **Token expiry handling in Phase 1**
   - What we know: CONTEXT.md says Phase 1 should not implement token refresh (that is a v2 requirement)
   - What's unclear: What to do if the token is already expired when Phase 1 reads it
   - Recommendation: Check `expiresAt` after read. If expired, log it and proceed with the API call anyway. If the API returns 401, display "Auth expired — rerun claude auth login" in the menu bar. Do not implement refresh in Phase 1.

---

## Sources

### Primary (HIGH confidence)
- Empirical: `security find-generic-password -s "Claude Code-credentials"` + Python decode — Keychain structure verified on target machine
- Empirical: `curl -H "Authorization: Bearer ..." -H "anthropic-beta: oauth-2025-04-20" https://api.anthropic.com/api/oauth/usage` — HTTP 200 with live usage data
- Apple Developer Documentation: NSStatusItem — https://developer.apple.com/documentation/appkit/nsstatusitem
- Apple Developer Documentation: SecItemCopyMatching / Keychain — https://developer.apple.com/documentation/security/secitemcopymatching(_:_:)
- Apple TN3137: On Mac Keychain APIs — https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains
- Apple Developer Documentation: LSUIElement — https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement

### Secondary (MEDIUM confidence)
- .planning/research/STACK.md — prior stack research for this project (2026-04-02)
- .planning/research/PITFALLS.md — prior pitfalls research for this project (2026-04-02)
- .planning/research/SUMMARY.md — prior synthesis of all research domains (2026-04-02)
- github.com/anthropics/claude-code/issues/30930 — OAuth usage endpoint 429 bug, token refresh workaround

### Tertiary (LOW confidence)
- github.com/griffinmartin/opencode-claude-auth — Keychain service name pattern (superseded by empirical verification)

---

## Metadata

**Confidence breakdown:**
- Keychain structure: HIGH — verified empirically on target machine
- API endpoint + response shape: HIGH — live 200 response with actual data captured
- NSStatusItem patterns: HIGH — Apple official docs + established community practice
- LSUIElement + entitlements: HIGH — Apple official docs
- File fallback structure (~/.credentials.json): LOW — file absent on target machine, structure unverified

**Research date:** 2026-04-02
**Valid until:** 2026-07-01 (90 days — stable Apple frameworks; API endpoint is undocumented and may change without notice)
