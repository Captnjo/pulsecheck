# Pitfalls Research

**Domain:** macOS menu bar app — API-polling utility (Claude Code usage)
**Researched:** 2026-04-02
**Confidence:** HIGH (verified against official docs, multiple sources, and existing apps in this exact niche)

---

## Critical Pitfalls

### Pitfall 1: The Official Analytics API Is Organization-Only

**What goes wrong:**
The PROJECT.md says "Depends on Anthropic API having a usage/limits endpoint." That endpoint exists — but it only works for organizations with an admin API key (`sk-ant-admin...`). It is explicitly documented: "The Admin API is unavailable for individual accounts." A personal Pro or Max subscription cannot call `/v1/organizations/usage_report/claude_code` at all. If you build the app assuming a standard API key works, you hit 401 errors on first run and have no fallback.

**Why it happens:**
The Anthropic API docs have a clear, prominent analytics API page. It looks like exactly the right thing. Developers read it, plan around it, and only discover the individual-account restriction after implementation begins.

**How to avoid:**
Before writing any polling code, confirm which endpoint you can actually call. The two realistic alternatives are:
1. Read Claude Code's OAuth token from the macOS Keychain (the same credential Claude Code itself uses) and call the same internal endpoints that power `claude.ai/settings/usage` — this is what `rjwalters/claude-monitor` does.
2. Target API pay-as-you-go users with a standard API key and use the `/v1/usage` or cost API endpoints — but this does not cover subscription limits (daily/weekly caps).

If the app is for personal subscription users, option 1 is the only viable path. This is an undocumented internal API with no stability guarantees.

**Warning signs:**
- You are testing with a personal `sk-ant-api03-...` key and getting 403/401 responses from `/v1/organizations/...`
- The README says "requires an Admin API key" in a tip callout
- Other open-source tools in this space (claude-usage-bar, claude-monitor, burnrate) all avoid the official analytics endpoint entirely

**Phase to address:**
Phase 1 (Foundation / API discovery) — verify the exact endpoint and authentication approach before any other code is written.

---

### Pitfall 2: NSStatusItem Gets Garbage Collected, Menu Disappears

**What goes wrong:**
You create an `NSStatusItem`, it appears in the menu bar, you test it... and then it vanishes. Sometimes immediately, sometimes after a navigation. This is not a bug in your logic — the status item was deallocated because it was held in a local variable rather than a property with app-level lifetime.

**Why it happens:**
`NSStatusItem` behaves like any Swift reference type: it lives as long as something holds a strong reference to it. If you create it inside a function without assigning it to a persistent property, Swift's ARC releases it when the function returns. In SwiftUI app lifecycle code, it's easy to accidentally scope the status item inside an `init` block or a `@main` struct body without a stored property.

**How to avoid:**
Store the `NSStatusItem` (or the SwiftUI `MenuBarExtra`) as a property on a class with app-level lifetime — typically `AppDelegate` or a dedicated `AppState` singleton held by `@StateObject` in the `@main` App struct. Never create it in a local scope.

```swift
// Wrong — local variable, will be released
func applicationDidFinishLaunching(_ n: Notification) {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    // item deallocated here
}

// Correct — stored property
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
}
```

**Warning signs:**
- Menu bar icon appears briefly then disappears
- Works in first build, disappears after minor refactor that moves initialization code
- No crash, no error — silent disappearance

**Phase to address:**
Phase 1 (App shell / menu bar scaffolding).

---

### Pitfall 3: Timer Creates a Retain Cycle, App Leaks Memory Indefinitely

**What goes wrong:**
The polling timer (60-second interval) captures `self` strongly in its closure. `self` holds a strong reference to the timer. Neither is ever released. The app's memory footprint grows continuously. On a personal machine running 24/7, this becomes noticeable within hours.

**Why it happens:**
`Timer.scheduledTimer(withTimeInterval:repeats:block:)` keeps the closure alive for the entire repeat cycle. If the closure captures `self` strongly, and `self` holds the timer as an instance variable, neither can be deallocated — a classic Swift reference cycle.

**How to avoid:**
Always use `[weak self]` in timer closures. Always call `timer.invalidate()` in `deinit` or before reassignment. Prefer structured concurrency (`Task` + `try await Task.sleep(for:)`) over `Timer` — it participates in Swift's cooperative cancellation model and avoids the retain cycle entirely.

```swift
// Problematic
timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
    self.fetchUsage() // strong capture
}

// Correct with Timer
timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
    self?.fetchUsage()
}

// Preferred: structured concurrency
func startPolling() {
    Task {
        while !Task.isCancelled {
            await fetchUsage()
            try await Task.sleep(for: .seconds(60))
        }
    }
}
```

**Warning signs:**
- Memory in Activity Monitor grows slowly but never drops
- Instruments shows heap growing with `Timer` or closure objects
- App behaves normally otherwise — this is a silent leak

**Phase to address:**
Phase 2 (Polling engine implementation).

---

### Pitfall 4: Settings Window Cannot Be Opened From a Menu Bar App Without AppKit Surgery

**What goes wrong:**
You use `SettingsLink` or `openSettings` to show a settings/API key configuration window. It either does nothing, opens behind all other windows, or silently fails depending on macOS version. On macOS Sequoia 15.5+, `openSettings()` fails silently unless a hidden window is declared before the Settings scene in the App body.

**Why it happens:**
Menu bar apps use `.accessory` activation policy — no Dock icon, no App Switcher entry. macOS's window management model is designed for regular foreground apps and does not reliably bring windows to the front for accessory-policy apps. `SettingsLink` is documented but explicitly does not work reliably inside `MenuBarExtra`. This was described as a "5-hour journey" by a seasoned macOS developer in 2025 and remains unfixed.

**How to avoid:**
Use one of these patterns instead of `SettingsLink`:
1. Temporarily switch activation policy to `.regular` before opening the settings window, then back to `.accessory` after it closes.
2. Use `NSWorkspace.shared.open(settingsURL)` with a custom URL scheme.
3. For a simple first-run setup (API key entry), show the setup UI directly in the popover/dropdown panel — avoid a separate window entirely.

For this app specifically, option 3 is the lowest-risk path: show API key entry inside the menu panel itself rather than opening a secondary settings window.

**Warning signs:**
- Settings window appears but sits behind Finder
- `openSettings()` call returns without showing anything
- Works in Simulator or Debug build, fails after notarization/distribution
- macOS version in test differs from target user machine

**Phase to address:**
Phase 1 or 2 (first-run / API key setup flow).

---

### Pitfall 5: SwiftUI MenuBarExtra Has No `.onAppear` for Its Menu Content

**What goes wrong:**
You put data-fetching logic in `.onAppear` on a view inside `MenuBarExtra`. That callback is never called when the menu opens. The displayed data is always stale — it reflects the state from the last time the app polled in the background, not a fresh fetch triggered by opening the menu.

**Why it happens:**
`MenuBarExtra` with `.menu` style does not call `.onAppear` on child views when the menu drops down. This is a known SwiftUI limitation with no first-party workaround as of 2025. The `FB13683950` feedback report explicitly requests an event for when the menu opens.

**How to avoid:**
For this app, rely entirely on the background polling timer rather than trying to fetch on menu open. Since the poll interval is 60 seconds, data will be at most 60 seconds old — acceptable for usage monitoring. If on-open freshness is required later, use `NSStatusItem` directly (bypassing `MenuBarExtra`) and hook into the menu's delegate callbacks.

**Warning signs:**
- Data in dropdown never updates even though background polling is running
- Adding `print("appeared")` to a view inside `MenuBarExtra` never fires
- Tests confirm polling works but UI always shows initial values

**Phase to address:**
Phase 2 (data refresh / UI update architecture).

---

### Pitfall 6: Storing API Key or OAuth Token in UserDefaults

**What goes wrong:**
You store the Anthropic API key (or OAuth token) in `UserDefaults` because it's easy. Any other app on the system can read `UserDefaults` for your bundle ID with sufficient access. On macOS, plist files backing `UserDefaults` are stored in plaintext at `~/Library/Preferences/`.

**Why it happens:**
`UserDefaults` is the obvious persistence mechanism for small values in SwiftUI (`@AppStorage`). The path from "I need to save this key" to `@AppStorage("apiKey") var apiKey = ""` is two seconds of typing. The security implication is not surfaced until a security review.

**How to avoid:**
Use the macOS Keychain via `SecItemAdd` / `SecItemCopyMatching`. For OAuth tokens (if using the internal API path), the token already lives in the Keychain — read it from there rather than duplicating it. Use a wrapper library like `KeychainAccess` to reduce boilerplate and avoid common attribute-dictionary mistakes.

Never store credentials in:
- `UserDefaults` / `@AppStorage`
- `Info.plist`
- Any file in `~/Library/Preferences/`
- Environment variables embedded in the built binary

**Warning signs:**
- API key is accessible via `defaults read com.yourapp.name`
- App uses `@AppStorage("anthropicKey")` anywhere in the codebase
- First-run setup saves to `UserDefaults` "temporarily until I add Keychain"

**Phase to address:**
Phase 1 (Keychain storage, first-run setup).

---

### Pitfall 7: Polling Interval Shorter Than Rate Limit Window Causes Self-Rate-Limiting

**What goes wrong:**
You decide 60 seconds is too slow and reduce the interval to 10-15 seconds "to feel more real-time." Anthropic enforces rate limits at sub-minute granularity — a 60 RPM limit can be enforced as 1 request per second. Your app starts getting 429 responses. Error handling retries immediately, making it worse. The app bricks itself.

**Why it happens:**
Rate limits feel like a distant concern during development because the Anthropic API is responsive and fast. The token bucket algorithm means you can burst initially, which masks the problem until the bucket empties.

**How to avoid:**
Keep the 60-second interval as the minimum. Implement exponential backoff for 429 responses — do not retry immediately. Back off to 2 minutes, 4 minutes, 8 minutes, cap at 30 minutes. Display a visual indicator when in backoff state rather than silently failing.

**Warning signs:**
- Console shows 429 responses during normal operation
- App polling interval was recently reduced
- Error handler calls the same endpoint again immediately on failure

**Phase to address:**
Phase 2 (polling engine, error handling).

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `UserDefaults` for API key | Zero boilerplate | Security vulnerability | Never |
| `Timer` without `[weak self]` | Simpler closure | Memory leak, growing RSS | Never |
| Hardcoded 60s interval with no backoff | Simple implementation | Self-rate-limiting on errors | Never |
| Internal API endpoint with no versioning guard | Works today | Breaks silently on Anthropic backend changes | MVP only, add version check in Phase 2 |
| Single-threaded URLSession on main queue | No concurrency management | UI freezes on slow network | Never |
| Polling even when no network is available | Simpler code | Wasted battery, pointless errors | Never |
| No error state in UI | Cleaner UI | Users think stale data is current | MVP only, add in Phase 2 |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Anthropic Analytics API | Using standard API key for personal subscription | Either use OAuth token from Keychain (internal API) or accept org-only limitation |
| macOS Keychain | Using `kSecAttrService` inconsistently across read/write calls | Use a constant for the service name; mismatched attributes cause "item not found" errors even when the item exists |
| macOS Keychain | Calling Keychain APIs on a background thread without `kSecUseDataProtectionKeychain` | Specify `kSecUseDataProtectionKeychain: true` for reliable cross-thread access |
| URLSession | Creating a new `URLSession` per poll | Use a single shared or configured session instance; new sessions allocate socket pools |
| OAuth token refresh | Assuming the token read from Keychain is always valid | Tokens expire; implement retry with re-read from Keychain on 401 responses |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Timer retain cycle | RSS grows ~1MB/hour, never GC'd | `[weak self]` + structured concurrency | Immediately, visible in 4-8 hours |
| Polling on main thread | UI stutters every 60 seconds during network call | Dispatch network work to background queue / async Task | Every poll cycle |
| Recreating NSMenu on every poll | CPU spike every 60s, fan spins | Only update changed UI elements, not rebuild entire menu | Every poll cycle |
| No network reachability check | Pointless API calls when offline, battery drain | Check `NWPathMonitor` before polling, pause when offline | Any time Wi-Fi drops |
| Decoding full response JSON every poll | Marginal but unnecessary work | Cache last response, only update UI on delta | Not a real threshold — just wasteful |

---

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| API key in `UserDefaults` / `@AppStorage` | Any app on system can read it via plist | macOS Keychain with `kSecClassGenericPassword` |
| API key logged to Console | Exposed in log streams accessible by other apps | Never log key material; log "API key present: true/false" |
| OAuth token stored in file at `0600` | Better than UserDefaults but still readable by privileged processes | Keychain only; the token already lives there from Claude Code's own login |
| No certificate pinning | MITM on corporate network could intercept usage data | Accept this risk for v1 (personal tool, non-sensitive data); URLSession default TLS is sufficient |
| Entitlement `com.apple.security.network.client` missing | App silently fails all network requests under sandbox | Ensure entitlement is present in `.entitlements` file |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No quit option in menu | App is "trapped" — no Dock icon, no way to close | Always include a "Quit" menu item; NSApp.terminate() |
| Stale data with no staleness indicator | User thinks 2-hour-old number is current | Show "Updated X minutes ago" timestamp in dropdown |
| Error state shows nothing / crashes | User thinks app is broken, uninstalls | Show a clear error row: "Could not fetch — tap to retry" |
| Blocking first-run API key prompt | User must complete setup before seeing any UI | Allow dismissal; show placeholder state while setup is pending |
| Threshold color change with no explanation | User sees red icon, doesn't know why | Tooltip or label: "89% of daily limit used" |
| Percentage truncated to integer | "100%" when actually 99.7% — limit not quite hit | Show one decimal place when above 95% |

---

## "Looks Done But Isn't" Checklist

- [ ] **Polling engine:** Timer is running — but is it running on app launch, not just after first menu open? Verify timer starts in `applicationDidFinishLaunching` or equivalent.
- [ ] **Keychain storage:** Key saves and loads in the same build — but does it survive app deletion and reinstall? (It should not, to avoid orphaned credentials.)
- [ ] **Error handling:** 404 and 500 responses are handled — but are 429 (rate limit) and network timeout handled separately with backoff?
- [ ] **Quit behavior:** App quits via menu item — but does it also properly invalidate the timer and cancel any in-flight URLSession tasks?
- [ ] **Menu bar icon text:** Percentage displays correctly — but is it truncated when > 3 characters? Does "100%" fit without overlapping adjacent menu bar icons?
- [ ] **First run:** API key entry flow completes — but what happens if the user dismisses it without entering a key? Is there a way to re-trigger setup?
- [ ] **macOS version compatibility:** App runs on Sonoma — but does it run on Ventura? `MenuBarExtra` requires macOS 13+; verify minimum deployment target.
- [ ] **Background refresh:** Timer fires every 60 seconds — but does it respect macOS App Nap? Menu bar apps are usually exempt, but verify `NSProcessInfo.processInfo.beginActivity` is called if needed.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Built around org-only Analytics API | HIGH | Pivot to OAuth Keychain approach; requires complete API layer rewrite; existing UI is reusable |
| NSStatusItem GC'd / menu disappears | LOW | Move declaration to app-level stored property; 10-minute fix |
| Timer retain cycle discovered late | MEDIUM | Refactor to structured concurrency Task; test memory profile; ~2 hours |
| Settings window unusable | MEDIUM | Replace settings window with in-panel setup UI; ~1 day redesign |
| API key leaked via UserDefaults | HIGH | Force-migrate all users to Keychain on next launch; delete UserDefaults value; communicate security notice |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Analytics API org-only restriction | Phase 1 — API research & authentication | Manually call endpoint with personal API key; confirm 401; document chosen alternative |
| NSStatusItem garbage collected | Phase 1 — App shell scaffolding | Menu bar icon persists after 5 minutes of background running |
| Timer retain cycle | Phase 2 — Polling engine | Instruments Leaks shows zero growth after 10 poll cycles |
| Settings window inaccessible | Phase 1 or 2 — First-run setup | First-run API key entry works on clean install without Dock icon |
| `.onAppear` not called in MenuBarExtra | Phase 2 — Data refresh architecture | UI updates visible on second menu open without on-open fetch |
| API key in UserDefaults | Phase 1 — Keychain storage | `defaults read <bundle-id>` shows no key material |
| Polling below rate limit floor | Phase 2 — Polling engine | 429 response triggers backoff, not immediate retry |

---

## Sources

- Anthropic Claude Code Analytics API (official docs): https://platform.claude.com/docs/en/api/claude-code-analytics-api — confirmed org/admin-only
- Peter Steinberger, "Showing Settings from macOS Menu Bar Items: A 5-Hour Journey" (2025): https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
- orchetect/MenuBarExtraAccess GitHub discussions — `MenuBarExtra` API limitations: https://github.com/orchetect/MenuBarExtraAccess/discussions/1
- Apple Developer Forums — "SwiftUI Timer not working inside Menu bar extra": https://developer.apple.com/forums/thread/726369
- Apple Developer Forums — "FB7539293: SwiftUI view used as custom view in NSMenuItem is never released": https://github.com/feedback-assistant/reports/issues/84
- Multi.app blog — "Pushing the limits of NSStatusItem": https://multi.app/blog/pushing-the-limits-nsstatusitem
- Blimp-Labs/claude-usage-bar (reference implementation): https://github.com/Blimp-Labs/claude-usage-bar
- rjwalters/claude-monitor (OAuth Keychain approach): https://github.com/rjwalters/claude-monitor
- Apple TN3137 — On Mac keychain APIs: https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains
- Anthropic rate limits documentation: https://platform.claude.com/docs/en/api/rate-limits

---
*Pitfalls research for: macOS menu bar app polling Anthropic API for Claude Code usage*
*Researched: 2026-04-02*
