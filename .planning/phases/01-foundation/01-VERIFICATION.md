---
phase: 01-foundation
verified: 2026-04-02T00:00:00Z
status: passed
score: 10/10 must-haves verified
re_verification: false
---

# Phase 1: Foundation Verification Report

**Phase Goal:** Users have a running macOS app that reads Claude Code credentials and confirms usage data is retrievable
**Verified:** 2026-04-02
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| #  | Truth | Status | Evidence |
|----|-------|--------|----------|
| 1  | App launches with no Dock icon and no App Switcher entry | ✓ VERIFIED | `LSUIElement = <true/>` in Info.plist line 24; `NSApp.setActivationPolicy(.accessory)` in AppDelegate.swift line 9 |
| 2  | Menu bar shows —% placeholder on launch | ✓ VERIFIED | `button.title = "—%"` in StatusBarController.swift line 15; `var menuBarTitle: String = "—%"` in UsageStore.swift |
| 3  | Clicking Quit ClaudeUsage fully exits the app | ✓ VERIFIED | `NSApplication.terminate(_:)` wired in StatusBarController.swift line 42 |
| 4  | App reads Claude Code OAuth token from Keychain on launch without user prompt | ✓ VERIFIED | KeychainService.readClaudeCredentials() uses SecItemCopyMatching with service "Claude Code-credentials"; no kSecAttrAccount hardcoded; called from AppDelegate launch Task |
| 5  | App falls back to ~/.claude/.credentials.json when Keychain absent | ✓ VERIFIED | CredentialsService.readCredentialsFromFile() at lines 36-49; path `.claude/.credentials.json` explicit; both wrapper and flat JSON structures handled |
| 6  | When no credentials exist, menu bar shows "No credentials" | ✓ VERIFIED | UsageStore.loadCredentials() sets `menuBarTitle = "No credentials"` on failure case |
| 7  | accessToken is available downstream via UsageStore | ✓ VERIFIED | `var credentials: ClaudeOAuthCredentials?` on UsageStore; AppDelegate calls `usageStore.fetchUsage()` gated on `usageStore.credentials != nil` |
| 8  | App makes GET /api/oauth/usage call on launch using accessToken | ✓ VERIFIED | AnthropicAPIClient.fetchUsage() uses `URLRequest` to `api.anthropic.com/api/oauth/usage` with Bearer token; called from AppDelegate.applicationDidFinishLaunching |
| 9  | Menu bar updates from —% to real percentage after successful API call | ✓ VERIFIED | UsageStore.fetchUsage() sets `menuBarTitle = fiveHour.displayString`; AppDelegate calls `statusBarController.updateTitle(usageStore.menuBarTitle)` after fetchUsage |
| 10 | API error states (401, unexpected) handled without crashing | ✓ VERIFIED | AnthropicAPIClient handles 401 → `.apiUnauthorized`; default → `.apiError`; UsageStore maps these to "Auth expired" / "API unavailable" menu bar strings |

**Score:** 10/10 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ClaudeUsage/Resources/Info.plist` | LSUIElement=YES, bundle ID | ✓ VERIFIED | Contains `<key>LSUIElement</key><true/>` and `com.jo.ClaudeUsage` |
| `ClaudeUsage/Resources/ClaudeUsage.entitlements` | Network sandbox entitlement | ✓ VERIFIED | Contains `com.apple.security.network.client = true` |
| `ClaudeUsage/ClaudeUsageApp.swift` | @main entry, AppDelegate adaptor | ✓ VERIFIED | `@NSApplicationDelegateAdaptor(AppDelegate.self)` present; Settings scene with EmptyView avoids WindowGroup Dock icon |
| `ClaudeUsage/AppDelegate.swift` | AppDelegate with StatusBarController + UsageStore | ✓ VERIFIED | `var statusBarController: StatusBarController!`; `var usageStore = UsageStore()`; full launch Task sequence present |
| `ClaudeUsage/StatusBarController.swift` | NSStatusItem, updateTitle, Quit menu | ✓ VERIFIED | `private var statusItem: NSStatusItem` stored property; `func updateTitle(_:)` present; NSPopover; NSMenu with Quit item |
| `ClaudeUsage/Models/AppError.swift` | Typed error enum | ✓ VERIFIED | `enum AppError: Error, LocalizedError` with all 8 cases including keychainItemNotFound, credentialsFileNotFound, apiUnauthorized, apiError, networkError |
| `ClaudeUsage/Services/KeychainService.swift` | Reads claudeAiOauth nested JSON | ✓ VERIFIED | KeychainWrapper + ClaudeOAuthCredentials structs; service "Claude Code-credentials"; kSecAttrAccount absent (comment-only); milliseconds division present |
| `ClaudeUsage/Services/CredentialsService.swift` | Keychain -> file fallback orchestration | ✓ VERIFIED | `func loadCredentials() async -> Result<ClaudeOAuthCredentials, AppError>`; three-step chain; `readCredentialsFromFile()` with wrapper+flat parsing |
| `ClaudeUsage/Store/UsageStore.swift` | @Observable state container | ✓ VERIFIED | `@Observable @MainActor class UsageStore`; credentials, credentialError, menuBarTitle, usageResponse properties; loadCredentials() and fetchUsage() methods |
| `ClaudeUsage/Models/UsageResponse.swift` | Codable structs for API response | ✓ VERIFIED | UsageResponse, UsagePeriod, ExtraUsage Decodable structs; CodingKeys mapping snake_case fields; displayString does NOT multiply by 100 |
| `ClaudeUsage/Services/AnthropicAPIClient.swift` | fetchUsage(accessToken:) with correct headers | ✓ VERIFIED | Bearer token, `anthropic-beta: oauth-2025-04-20`, Accept header; 200/401/default handling; raw response OSLog debug logging |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| ClaudeUsageApp.swift | AppDelegate.swift | `@NSApplicationDelegateAdaptor` | ✓ WIRED | Line 5 of ClaudeUsageApp.swift |
| AppDelegate.swift | StatusBarController.swift | `var statusBarController: StatusBarController!` stored property | ✓ WIRED | Line 5 of AppDelegate.swift; instantiated in applicationDidFinishLaunching |
| AppDelegate.swift | UsageStore.swift | `var usageStore = UsageStore()` stored property | ✓ WIRED | Line 6 of AppDelegate.swift |
| AppDelegate.swift | UsageStore | `usageStore.loadCredentials()` in Task block | ✓ WIRED | Line 12 of AppDelegate.swift |
| AppDelegate.swift | UsageStore | `usageStore.fetchUsage()` in Task block | ✓ WIRED | Line 17 of AppDelegate.swift; gated on credentials != nil |
| AppDelegate.swift | StatusBarController | `updateTitle(usageStore.menuBarTitle)` twice | ✓ WIRED | Lines 13 and 18 of AppDelegate.swift |
| CredentialsService.swift | KeychainService.swift | `keychain.readClaudeCredentials()` | ✓ WIRED | Lines 7 and 12 of CredentialsService.swift |
| UsageStore.swift | AnthropicAPIClient.swift | `apiClient.fetchUsage(accessToken:)` | ✓ WIRED | Line 44 of UsageStore.swift |
| AnthropicAPIClient.swift | https://api.anthropic.com/api/oauth/usage | `URLSession.shared.data(for:)` | ✓ WIRED | Lines 7 and 16 of AnthropicAPIClient.swift |

---

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| StatusBarController (menuBarTitle display) | `statusItem.button?.title` | UsageStore.menuBarTitle, set by fetchUsage() from `fiveHour.displayString` | Yes — fiveHour.utilization decoded from live API JSON response (human-verified: real percentage confirmed matching /usage output) | ✓ FLOWING |
| UsageStore.credentials | `ClaudeOAuthCredentials?` | KeychainService via SecItemCopyMatching reading Keychain service "Claude Code-credentials" | Yes — live Keychain read; confirmed working on dev machine per 01-02 SUMMARY | ✓ FLOWING |

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Project builds cleanly | `xcodebuild -scheme ClaudeUsage -configuration Debug build` | BUILD SUCCEEDED | ✓ PASS |
| No Dock icon suppression key present | grep LSUIElement Info.plist | `<key>LSUIElement</key><true/>` found | ✓ PASS |
| Network entitlement present | grep network.client entitlements | `com.apple.security.network.client = true` | ✓ PASS |
| kSecAttrAccount absent from Keychain query | grep kSecAttrAccount KeychainService.swift | Comment-only, not a dict key | ✓ PASS |
| utilization not multiplied | grep "* 100" UsageResponse.swift | No match | ✓ PASS |
| End-to-end percentage display | Human checkpoint 01-03 | User confirmed percentage matches /usage command output | ✓ PASS |
| App lifecycle (no Dock, menu bar, quit) | Human checkpoint 01-01 | Approved — no Dock icon, —% in menu bar, Quit works | ✓ PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUTH-01 | 01-02, 01-03 | App reads Claude Code OAuth token from macOS Keychain on launch | ✓ SATISFIED | KeychainService.readClaudeCredentials() uses SecItemCopyMatching with service "Claude Code-credentials"; no kSecAttrAccount hardcoding; decodes claudeAiOauth nested wrapper; wired into AppDelegate launch sequence |
| AUTH-02 | 01-02 | App falls back to ~/.claude/.credentials.json if Keychain absent | ✓ SATISFIED | CredentialsService.readCredentialsFromFile() reads ~/.claude/.credentials.json; handles both wrapper and flat JSON; throws credentialsFileNotFound if absent; called after keychainItemNotFound |
| LIFE-01 | 01-01 | App runs as LSUIElement (no Dock icon) | ✓ SATISFIED | LSUIElement=YES in Info.plist; NSApp.setActivationPolicy(.accessory) belt-and-suspenders in AppDelegate |
| LIFE-02 | 01-01 | Dropdown includes Quit menu item | ✓ SATISFIED | NSMenu item "Quit ClaudeUsage" with action NSApplication.terminate(_:) in StatusBarController.buildMenu() |

**Requirements traceability note:** REQUIREMENTS.md Traceability table marks LIFE-01 and LIFE-02 as "Pending" in the Phase column, but the completion checkbox column shows them unchecked. This is a documentation inconsistency — both are fully implemented and verified in the codebase. The plan summaries correctly record `requirements-completed: [LIFE-01, LIFE-02]`.

**Orphaned requirements check:** No Phase 1 requirements found in REQUIREMENTS.md that are unaccounted for. All four IDs (AUTH-01, AUTH-02, LIFE-01, LIFE-02) are present in plan frontmatter and implemented.

---

### Anti-Patterns Found

No anti-patterns found. Scan across all 9 Swift files produced:
- Zero TODO/FIXME/XXX/HACK/placeholder comments
- Zero empty return stubs
- Zero hardcoded empty collections in data-rendering paths
- `kSecAttrAccount` appears only in a comment confirming intentional omission (not a stub — correct behavior per research)

---

### Human Verification Required

The following behaviors were confirmed by human checkpoint during plan execution and cannot be re-verified programmatically without running the app:

**1. No Dock icon on launch**
- Test: Build and run app (Cmd-R), observe whether Dock icon appears and whether app is visible in Cmd-Tab switcher
- Expected: No Dock icon; app absent from Cmd-Tab
- Why human: Requires visual inspection of running macOS session
- Result: APPROVED in checkpoint 01-01

**2. Menu bar percentage reflects live API data**
- Test: Launch app, observe menu bar update from —% to a real percentage; compare with `claude /usage` output
- Expected: Percentage is non-zero, non-trivial, matches /usage command value
- Why human: Requires live Keychain credentials and network access to Anthropic API
- Result: APPROVED in checkpoint 01-03 (percentage confirmed matching /usage output)

---

### Gaps Summary

No gaps. All 10 observable truths are verified, all 11 artifacts exist and are substantive, all 9 key links are wired, data flows from Keychain through credentials service through API client to menu bar title, and the project builds cleanly with BUILD SUCCEEDED.

**Minor documentation inconsistency (non-blocking):** REQUIREMENTS.md Traceability table marks LIFE-01 and LIFE-02 as "Pending" status rather than "Complete". This is a metadata-only discrepancy — both requirements are fully implemented and verified in code. The AUTH-01 and AUTH-02 rows correctly show "Complete".

---

_Verified: 2026-04-02_
_Verifier: Claude (gsd-verifier)_
