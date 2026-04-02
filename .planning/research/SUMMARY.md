# Project Research Summary

**Project:** PulseCheck (Claude Mac Widget) — v2.0 Polish & Resilience
**Domain:** macOS menu bar utility, OAuth-authenticated API polling
**Researched:** 2026-04-02
**Confidence:** HIGH (visual/storage features), MEDIUM (OAuth token refresh endpoint)

## Executive Summary

PulseCheck v2.0 adds six features to the v1.0 foundation: color-coded menu bar text, adaptive template icon, configurable warning thresholds, last-updated timestamp, manual refresh button, and OAuth token auto-refresh. The first five are well-understood AppKit/SwiftUI patterns with HIGH-confidence implementation paths and zero new dependencies. Every feature uses frameworks already imported in the project (AppKit, Foundation, Security, SwiftUI). The only exception is token refresh, which introduces a new URLSession POST and requires careful architecture decisions before writing a single line of code.

The recommended approach is to build in risk-ascending order: visual polish first (icon + colors), then UX improvements (timestamp + manual refresh), then settings persistence (threshold sliders), and OAuth token refresh last. This sequencing ensures the app is visually shippable early and that a regression from the high-risk token refresh work is immediately distinguishable from pre-existing issues. Two critical architecture decisions must be made before implementing token refresh: (1) whether to use a read-only bridge (show a "re-auth required" prompt) or a shadow Keychain item for write-back, and (2) confirming that refresh token serialization uses an actor-stored Task handle to prevent the dual-refresh race condition.

The single hardest constraint in the entire milestone is the Keychain ACL blocker: PulseCheck cannot write back to the `Claude Code-credentials` Keychain item because macOS enforces that only the item's creator (Claude Code) can modify it. Attempting `SecItemUpdate` on that item will silently consume the single-use refresh token without saving the replacement, leaving the user locked out. This is a CRITICAL pitfall that must drive the architectural design of the token refresh feature — not a detail to handle after the code is written.

## Key Findings

### Recommended Stack

The v2.0 stack adds zero new dependencies to v1.0. Every feature is implementable with AppKit (NSAttributedString, NSColor, NSImage), SwiftUI (@AppStorage, Text with .relative style, TimelineView), Foundation (URLSession async/await, JSONDecoder), and the Security framework (SecItemCopyMatching, SecItemAdd/Update). The project should remain dependency-free — `Task.sleep` polling is sufficient and swift-async-algorithms is still not needed.

Token refresh requires two new source files (`Services/OAuthRefreshService.swift`, `Services/TokenRefreshActor.swift`) and a write method on the existing `KeychainService`, but no package additions. The OAuth refresh endpoint (`POST https://console.anthropic.com/v1/oauth/token`) and client ID (`9d1c250a-e61b-44d9-88ed-5944d1962f5e`) are confirmed from third-party reverse engineering and match values already in CLAUDE.md.

**Core technologies:**
- Swift 6.1 / Xcode 16.3: primary language — strict concurrency catches data races at compile time, essential for polling + UI updates
- SwiftUI (macOS 13.0+): @AppStorage for threshold persistence, TimelineView for live timestamps, Text(.relative) for auto-refreshing relative times
- AppKit (NSStatusItem / NSStatusBarButton): attributedTitle for colored text, isTemplate for adaptive icon
- URLSession + JSONDecoder: all API calls including OAuth token refresh — no HTTP library needed for a single POST
- Security framework (Keychain): credential read (SecItemCopyMatching), new credential write (SecItemAdd/Update) for PulseCheck-owned shadow item
- UserDefaults / @AppStorage: threshold configuration — appropriate for preferences, NOT for credentials

### Expected Features

Research identified a clear set of table stakes, differentiators, and explicit anti-features for v2.0. The feature list is shorter than it appears — most items are LOW complexity.

**Must have (table stakes):**
- Color-coded menu bar text (green/yellow/red) — users of similar tools expect this; v1 bare text feels unfinished
- Adaptive template icon — without `isTemplate = true` the icon looks broken in dark mode; quality signal Apple and users both notice immediately
- Auto-refresh expired OAuth tokens — v1 fails silently after ~8 hours; requiring manual re-auth is unacceptable for a background utility

**Should have (differentiators):**
- Configurable warning thresholds — power users have different workflows; hardcoded 75%/90% frustrates heavy daily users
- Last-updated timestamp — eliminates "how stale is this data?" uncertainty when opening the popover
- Manual refresh button — established pattern in this category (ccusage-monitor uses ⌘R); users finishing a heavy session want fresh data on demand

**Defer to v3+:**
- System notifications on threshold breach — macOS notification permissions are friction; color-coded label already solves the visibility problem
- Settings as a dedicated app window — requires activation policy juggling that breaks on macOS 26 (Tahoe); inline popover settings are sufficient for 2 sliders

**Anti-features (never build):**
- SettingsLink inside NSPopover/MenuBarExtra — documented Apple bug; wastes implementation time
- UserDefaults for token storage — plaintext, wrong tool for credentials
- Writing to Claude Code's Keychain item — ACL blocks it and silently consumes the single-use refresh token

### Architecture Approach

The existing architecture is a clean three-layer structure: `UsageStore` (@Observable, @MainActor) as the single source of truth, `StatusBarController` (AppKit bridge) as the rendering layer, and stateless `Services` structs for Keychain reads and API calls. v2.0 integrates into this structure with additive changes rather than restructuring.

The most significant wiring change is extending the `onTitleChanged` callback from `(String) -> Void` to `(String, NSColor) -> Void` so the store can pass color information to the status bar controller. `NSColor` is a value type and acceptable as a callback parameter; the AppKit/store boundary is preserved by computing the color in `UsageStore` (business logic) and rendering the `NSAttributedString` in `StatusBarController` (presentation).

OAuth refresh adds two new service files and a write path on `KeychainService`, plus a refresh-retry branch in `UsageStore.fetchUsage()`. The key design decision is where refreshed tokens are written: a PulseCheck-owned shadow Keychain item (`PulseCheck-claude-credentials`) that PulseCheck creates and can update freely.

**Major components:**
1. `UsageStore` — single source of truth; gains `lastFetchedAt`, `isFetching`, `ThresholdSettings`, and the OAuth refresh-retry flow
2. `StatusBarController` — AppKit bridge; gains `updateTitle(_:color:)` with NSAttributedString and `isTemplate = true` on the icon
3. `OAuthRefreshService` + `TokenRefreshActor` — new; handles the POST to the token endpoint with actor-serialized in-flight deduplication
4. `ThresholdSettings` — new; UserDefaults-backed struct for warning/critical thresholds
5. `KeychainService` — existing; gains `writeClaudeCredentials(_:)` targeting PulseCheck's own shadow Keychain item
6. `UsagePanelView` — gains inline threshold sliders (collapsible section), TimelineView timestamp, manual refresh button

**New files required:** `Models/ThresholdSettings.swift`, `Services/OAuthRefreshService.swift`, `Services/TokenRefreshActor.swift`

**Modified files:** `StatusBarController.swift`, `UsageStore.swift`, `AppDelegate.swift`, `KeychainService.swift`, `CredentialsService.swift`, `Views/UsagePanelView.swift`, `Models/AppError.swift`

### Critical Pitfalls

1. **Keychain ACL blocks write-back to Claude Code's item** — `SecItemUpdate` on `Claude Code-credentials` returns `errSecInvalidOwnerEdit` (-25243) and silently consumes the single-use refresh token, locking the user out. Never attempt this. Write new tokens to a separate `PulseCheck-claude-credentials` Keychain item that PulseCheck created and owns (Option B). Decide before writing any refresh code.

2. **Refresh token rotation race condition** — Two concurrent callers (polling loop + manual refresh) both detect `isExpired == true` before either writes back new credentials, both attempt a refresh. The second invalidates the first's new token. Prevention: gate all refresh calls behind a Swift actor with a stored `Task<ClaudeOAuthCredentials, Error>?` handle; all callers await the same Task, one network request goes out.

3. **NSAttributedString color + template icon conflict** — `NSStatusBarButton.contentTintColor` applies to both the image and title text simultaneously. Setting it for colored text tints the template icon incorrectly. Solution: decouple — use template icon OR colored `attributedTitle`, not both on the same button (colored text + text-only status item is the cleaner v2.0 choice; template icon applies only when there is no colored text).

4. **Colored text unreadable on button highlight** — When the popover opens, macOS renders the status button with a highlighted background. Custom NSColor text does not invert automatically. Mitigation: use `NSColor.systemGreen`, `NSColor.systemYellow`, `NSColor.systemRed` (semantic colors that adapt); optionally add KVO on `button.isHighlighted` to swap text to `NSColor.selectedMenuItemTextColor` when highlighted.

5. **403 scope-loss after token refresh treated as generic error** — A documented Anthropic server-side bug (GitHub issue #34785) causes refreshed tokens to be missing `user:profile` scope. The API returns 403 with scope language in the body. Inspect 403 response body for "scope" / "user:profile" and route it through the same `.apiUnauthorized` recovery path as 401.

## Implications for Roadmap

Based on research, the dependency graph and risk profile drive a clear 4-phase structure for v2.0.

### Phase 1: Visual Polish

**Rationale:** Template icon (one-liner code change) and color-coded text (NSAttributedString swap) are zero-risk, immediately visible improvements with no external dependencies and no data-flow changes beyond the callback signature update. Building these first establishes the visual baseline and validates the StatusBarController rendering pipeline. The icon/color interaction (Pitfall V2.4) must be designed together in this phase — they share the same `NSStatusBarButton`.

**Delivers:** A menu bar icon that works correctly in dark mode; a percentage label that communicates urgency at a glance using semantic system colors.

**Addresses:** Template icon (table stakes), color-coded text (table stakes) with hardcoded default thresholds (75%/90%) as a first pass.

**Avoids:**
- Pitfall V2.3: use `NSColor.systemGreen/Yellow/Red`, not fixed colors; optionally add highlight KVO
- Pitfall V2.4: choose text-only colored display OR icon-only template; do not mix `contentTintColor` and `isTemplate` on the same button
- Pitfall V2.8: use `DistributedNotificationCenter` with `"AppleInterfaceThemeChangedNotification"` if appearance observation is needed under `.accessory` policy

**Research flag:** Standard AppKit patterns — no phase research needed.

### Phase 2: UX Improvements (Timestamp + Manual Refresh)

**Rationale:** Last-updated timestamp and manual refresh share the same model change (`lastFetchedAt`, `isFetching` on UsageStore) and both only affect `UsagePanelView`. Implementing them together avoids opening the same two files twice. Neither touches auth or the status bar.

**Delivers:** A popover that shows data freshness ("Updated 2 minutes ago") and a Refresh button (⌘R) that triggers immediate fetch.

**Addresses:** Last-updated timestamp (differentiator), manual refresh button (differentiator).

**Avoids:** Pitfall V2.5 (manual refresh bursting two requests) — call `startPolling()` after a manual fetch to restart the 60-second countdown, preventing a burst of two requests in rapid succession.

**Uses:** SwiftUI `TimelineView(.periodic(from: .now, by: 10))` for live relative timestamp without a separate timer; `isFetching: Bool` guard on `fetchUsage()` to prevent double-tap.

**Research flag:** Standard SwiftUI/Swift concurrency patterns — no phase research needed.

### Phase 3: Configurable Thresholds

**Rationale:** `@AppStorage` persistence and inline slider UI are both straightforward. Phase 1 ships with hardcoded defaults (75%/90%); Phase 3 wires those defaults to user preferences. The inline-in-popover approach (not a separate Settings window) avoids the SettingsLink bug and activation policy juggling entirely.

**Delivers:** Two sliders in the popover for warning and critical thresholds, persisted across launches; color logic in Phase 1 reads these preferences.

**Addresses:** Configurable thresholds (differentiator).

**Avoids:** Pitfall V2.6 (AppStorage key collision) — use namespaced keys (`com.jo.PulseCheck.warningThreshold.v1`), store as `Double` (0.0–1.0 fraction), never flip to percentage representation. Avoids SettingsLink anti-feature by keeping all settings inline.

**Uses:** `@AppStorage` / `UserDefaults`, new `ThresholdSettings` struct, SwiftUI `Slider` bound to `@AppStorage` values.

**Research flag:** Standard patterns — no phase research needed.

### Phase 4: OAuth Token Auto-Refresh

**Rationale:** This is the highest-risk feature in the milestone. It touches the authentication path that all API calls depend on, requires a new service layer, modifies the Keychain integration, and has two CRITICAL pitfalls that can lock users out permanently. It must come last so that a regression is immediately distinguishable from pre-existing issues. All visual and UX features should be stable and committed before this phase begins.

**Delivers:** Silent token refresh that keeps the app working beyond the ~8-hour access token lifetime without any user action.

**Addresses:** Auto-refresh expired OAuth tokens (table stakes).

**Avoids:**
- Pitfall V2.1 (Keychain ACL): write refreshed tokens to PulseCheck's own `PulseCheck-claude-credentials` item — never call `SecItemUpdate` on `Claude Code-credentials`
- Pitfall V2.2 (rotation race): all refresh calls go through `TokenRefreshActor` which holds a stored `Task` handle; concurrent callers await the same Task
- Pitfall V2.7 (403 scope-loss): inspect 403 body for "scope" or "user:profile" text, route to `.apiUnauthorized` recovery path

**Uses:** URLSession async/await POST, Swift `actor` for refresh serialization, `SecItemAdd`/`SecItemUpdate` on PulseCheck's own Keychain item, `ClaudeOAuthCredentials.isExpired` for proactive check before each poll cycle.

**New files:** `Services/OAuthRefreshService.swift` (~45 lines), `Services/TokenRefreshActor.swift` (~25 lines)

**Modified files:** `Services/KeychainService.swift` (add write method), `Services/CredentialsService.swift` (proactive refresh on expired token), `Store/UsageStore.swift` (401/403 → refresh → retry; `refreshAttempted` flag), `Models/AppError.swift` (add `.tokenRefreshFailed`)

**Research flag:** MEDIUM confidence. Validate that `POST https://console.anthropic.com/v1/oauth/token` with client_id `9d1c250a-e61b-44d9-88ed-5944d1962f5e` still works against a live expired token before investing a full day of implementation. A quick `curl` test is sufficient validation. Also confirm the shadow item approach does not produce conflicting reads when both `Claude Code-credentials` and `PulseCheck-claude-credentials` exist.

### Phase Ordering Rationale

- Phase 1 (Visual Polish) has no external dependencies and zero auth risk — it can ship independently as a standalone improvement.
- Phase 2 (UX Improvements) is additive model changes that never touch auth and can be implemented in any order relative to Phase 1.
- Phase 3 (Thresholds) depends on Phase 1 having hardcoded defaults in place; it wires user preferences into color logic that Phase 1 established.
- Phase 4 (Token Refresh) is isolated last to contain its blast radius. The CRITICAL Keychain ACL pitfall means the shadow item architecture must be locked before writing code.
- Pitfalls V2.3 and V2.4 (colored text + icon rendering) interact at the `NSStatusBarButton` level and must be designed together in Phase 1 — do not implement the icon in Phase 1 and revisit the color conflict in a later phase.

### Research Flags

Needs deeper research during planning:
- **Phase 4 (OAuth Token Refresh):** Validate the refresh endpoint and client_id from third-party sources (opencode project reverse engineering) against a live Claude Code installation before starting implementation. Confirm shadow item preference logic when both Keychain items exist concurrently.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Visual Polish):** NSAttributedString and `isTemplate` are stable AppKit APIs unchanged since macOS 10.10. Well-documented across official docs and production apps.
- **Phase 2 (UX Improvements):** `TimelineView`, `Text(.relative)`, and async boolean guard patterns are official SwiftUI APIs with complete documentation.
- **Phase 3 (Configurable Thresholds):** `@AppStorage` is official SwiftUI API with extensive documentation. Inline popover settings pattern is straightforward.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All v2.0 features confirmed implementable with existing imported frameworks; zero new dependencies required |
| Features | HIGH | Clear table stakes / differentiator / anti-feature split; implementation paths individually verified in STACK.md and FEATURES.md |
| Architecture | HIGH | Based on direct source reading of all 9 existing files (535 LOC); integration points, callback signature changes, and new component boundaries identified precisely |
| Pitfalls — visual/storage | HIGH | NSAttributedString, template image, @AppStorage behavior from official Apple docs and multiple independent sources; Keychain ACL from Apple TN3137 |
| Pitfalls — OAuth token refresh | MEDIUM | Keychain ACL (HIGH, Apple TN3137); endpoint/client_id from third-party reverse engineering (MEDIUM); scope-loss bug from GitHub issue thread (MEDIUM) |

**Overall confidence:** HIGH for Phases 1–3, MEDIUM for Phase 4.

### Gaps to Address

- **OAuth endpoint validation:** The refresh endpoint URL and client_id come from third-party sources (opencode project). Validate with a live `curl` test against an actual expired Claude Code token before implementing Phase 4 in full.
- **Shadow item conflict resolution:** When both `Claude Code-credentials` and `PulseCheck-claude-credentials` exist, define which item is preferred and under what conditions PulseCheck falls back to the Claude Code item. This logic belongs in `CredentialsService` and must be decided before Phase 4 implementation.
- **Highlight color legibility:** The `NSColor.systemRed/Green/Yellow` approach is the correct mitigation for colored text on highlight. If testing shows the colors are still unreadable when highlighted, the fallback is a colored SF Symbol dot alongside monochrome text — this sidesteps all three highlight pitfalls entirely. Leave the final decision to Phase 1 visual testing.
- **403 scope-loss trigger rate:** The documented Anthropic bug (missing `user:profile` scope after refresh, GitHub issue #34785) has unknown frequency. The mitigation is cheap (3-line body inspection) and should be implemented regardless, but the trigger condition is not fully understood from the issue thread.

## Sources

### Primary (HIGH confidence)
- https://developer.apple.com/documentation/appkit/nsbutton/1524640-attributedtitle — attributedTitle API reference
- https://developer.apple.com/documentation/appkit/nsimage/istemplate — isTemplate behavior, official HIG recommendation
- https://developer.apple.com/documentation/swiftui/appstorage — @AppStorage persistence wrapper
- https://developer.apple.com/documentation/security/storing-keys-in-the-keychain — Keychain SecItem APIs
- https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains — Keychain ACL behavior, errSecInvalidOwnerEdit
- https://www.donnywals.com/building-a-token-refresh-flow-with-async-await-and-swift-concurrency/ — Swift actor pattern for refresh serialization (July 2025)
- https://github.com/apple/swift-async-algorithms — swift-async-algorithms 1.1.3 (still not needed for this project)
- https://developer.apple.com/documentation/appkit/nsstatusitem — NSStatusItem button, image, attributedTitle, contentTintColor APIs

### Secondary (MEDIUM confidence)
- https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — SettingsLink bug inside MenuBarExtra (2025, first-hand report)
- https://github.com/anthropics/claude-code/issues/30930 — OAuth usage endpoint 429 bug, token structure, refresh flow
- https://github.com/anthropics/claude-code/issues/34785 — OAuth refresh produces tokens with missing scopes (scope-loss bug)
- https://deepwiki.com/anomalyco/opencode-anthropic-auth/3.3-token-lifecycle-management — refresh endpoint URL, fields, client_id
- https://github.com/griffinmartin/opencode-claude-auth — Claude Code Keychain service name, credentials JSON structure
- https://multi.app/blog/pushing-the-limits-nsstatusitem — real-world NSStatusItem colored title patterns
- https://www.jessesquires.com/blog/2019/08/16/workaround-highlight-bug-nsstatusitem/ — highlight state color behavior (2019, unchanged)
- https://sarunw.com/posts/swiftui-menu-bar-app/ — MenuBarExtra scene API patterns (2022, confirmed stable 2025)
- https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ — LSUIElement, Dock hiding, window style patterns

### Tertiary (LOW confidence)
- https://www.theregister.com/2026/03/31/anthropic_claude_code_limits/ — Claude Code quota context; not used for API implementation details

---
*Research completed: 2026-04-02*
*Ready for roadmap: yes*
