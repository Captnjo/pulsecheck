# Project Research Summary

**Project:** ClaudeMacWidget — macOS menu bar app for Claude Code usage monitoring
**Domain:** macOS menu bar utility (native Swift, API polling)
**Researched:** 2026-04-02
**Confidence:** MEDIUM-HIGH (core patterns HIGH, API contract MEDIUM due to undocumented endpoint)

## Executive Summary

This is a native macOS menu bar utility built in Swift/SwiftUI that reads Claude Code usage data from an internal Anthropic API and displays it as a glanceable percentage in the menu bar. Experts in this niche consistently build with an AppKit shell (`NSStatusItem` + `NSPopover`) wrapping a SwiftUI interior — not the simpler `MenuBarExtra` scene API — because `MenuBarExtra` lacks programmatic show/hide, direct button text access, and reliable `.onAppear` callbacks. The recommended approach is a zero-dependency Swift app targeting macOS 13+ (Ventura), using structured concurrency for polling, and reading the OAuth token Claude Code itself stores in the macOS Keychain rather than requiring a separate API key from the user.

The critical risk is the API layer. The official Anthropic analytics API (`/v1/organizations/usage_report/claude_code`) is organization/admin-only and does not work for personal Pro or Max subscribers. The only viable path for personal subscription users is piggybacking on Claude Code's existing OAuth token from the macOS Keychain and calling the same internal endpoint that powers the `claude.ai/settings/usage` page. This endpoint (`GET /api/oauth/usage`) is undocumented, unofficial, and has a known persistent 429 bug for some users that requires token refresh as the workaround — not retry with the same token. Plan for this endpoint to break on Anthropic backend changes.

The competitive landscape has three open-source Swift predecessors (cctray, Claude Usage Tracker, ccusage-monitor). Two of the three depend on the `ccusage` CLI (Node.js + Homebrew), which creates friction for non-developer users. The key differentiator for this app is eliminating that dependency entirely through direct API integration. Feature scope is well-established by the existing apps: menu bar percentage label with color coding, dropdown showing daily and weekly usage plus reset time, Keychain credential storage, and Launch at Login. History charts and multi-account support are explicitly v2+ work.

## Key Findings

### Recommended Stack

Build a native Swift 6.1 app with no third-party dependencies. All required functionality — networking, Keychain access, JSON decoding — is covered by system frameworks. The only optional external package is Apple's `swift-async-algorithms` (1.1.3) for a cleaner polling loop, but a `Task { while !Task.isCancelled { ... await Task.sleep(for: .seconds(60)) } }` pattern is equally correct and removes the dependency entirely.

**Core technologies:**
- Swift 6.1 (Xcode 16.3): primary language — strict concurrency catches data races at compile time, essential for polling + UI updates
- SwiftUI (macOS 13.0+): panel views interior — clean declarative UI inside the popover; avoid for menu bar scaffolding itself
- AppKit via NSStatusItem/NSPopover: menu bar shell — required for programmatic title updates, show/hide control, and right-click support that `MenuBarExtra` cannot provide
- URLSession (built-in): API polling — native async/await; no networking library needed for a single endpoint
- Security framework (built-in): Keychain storage — `SecItemAdd` / `SecItemCopyMatching`; encrypts token at rest
- Foundation JSONDecoder (built-in): response parsing — Codable structs + JSONDecoder is standard for this use case

**API authentication — critical detail:**
The `GET https://api.anthropic.com/api/oauth/usage` endpoint requires the OAuth bearer token Claude Code stores in the macOS Keychain under service `Claude Code-credentials`. The token JSON contains `accessToken`, `refreshToken`, and `expiresAt`. Access tokens are short-lived (~1 hour); refresh tokens rotate on each use. The app must check `expiresAt` before each poll and proactively refresh. On 429 responses, attempt a token refresh — not a same-token retry.

### Expected Features

Research identified a clear MVP through competitor analysis and Apple HIG review. The table stakes list is shorter than it appears — most items are LOW complexity and well under a day each.

**Must have (table stakes):**
- Usage percentage in menu bar label — the core value proposition; color-coded green/yellow/red
- Dropdown panel: daily usage, weekly usage, reset countdown — reason to open the app
- Auto-refresh polling every 60 seconds — data must stay fresh without user action
- OAuth token read from Keychain (piggybacking Claude Code login) — zero friction for existing Claude Code users
- First-run setup flow — directs user to `claude auth login` if Keychain token is absent
- Adaptive template icon (light/dark menu bar) — `isTemplate = true`; colored icon breaks dark mode
- LSUIElement (no Dock icon) — correct menu bar app behavior; `LSUIElement = YES` in Info.plist
- Quit menu item — without a Dock icon this is the only reliable exit path
- Error state in label ("--" or "ERR") — graceful degradation when API fails
- Launch at Login toggle — expected for all utility apps; `SMAppService` on macOS 13+, opt-in

**Should have (competitive / v1.x):**
- Last-updated timestamp in dropdown — "Updated 23s ago" reduces uncertainty about data freshness
- Manual refresh action — power users want immediate refresh; ⌘R convention used by competitors
- Configurable warning thresholds — let users define yellow/red trigger percentages

**Defer (v2+):**
- Usage history charts — requires local persistence + charting UI; multiplies scope significantly
- Multi-account / profile support — large surface area; single account covers the vast majority of users
- CSV/JSON export — only relevant after history tracking exists

### Architecture Approach

The architecture is an AppKit shell with SwiftUI interior, connected by a single `@Observable` state container (`UsageStore`). `StatusBarController` owns the `NSStatusItem` and `NSPopover`, bridging to SwiftUI via `NSHostingController`. All business logic lives in `Services/` with no UI dependencies, making it unit-testable in isolation. Data flows in one direction: Anthropic API → `AnthropicAPIClient` → `UsageStore` → views + status bar title.

**Major components:**
1. `StatusBarController` — owns `NSStatusItem`; updates button title with usage %; handles click to show/hide `NSPopover`; app-level lifetime stored property (avoids GC pitfall)
2. `UsageStore` (@Observable) — single source of truth for all usage state; observed by both AppKit layer and SwiftUI views; drives color-coded label
3. `PollingService` — 60-second poll loop using Swift structured concurrency (`Task` + `Task.sleep`); implements exponential backoff on consecutive errors; cancels cleanly on quit
4. `AnthropicAPIClient` — stateless struct; HTTP request construction; OAuth header injection; token expiry check + refresh flow; JSON decoding to `UsageResponse`
5. `KeychainService` — reads/writes Keychain via `SecItem` API; reads existing Claude Code OAuth token from `Claude Code-credentials` service; consistent `kSecAttrService` key critical
6. `PanelView` / `SetupView` / `UsageView` — SwiftUI views wired to `UsageStore`; `PanelView` routes to `SetupView` (no token) or `UsageView` (token present)

**Build order (from architecture research):** Models → KeychainService → App shell + StatusBarController → Panel views → PollingService + API client. UI shell is manually testable before any API code is written.

### Critical Pitfalls

1. **Official analytics API is org-only** — `GET /v1/organizations/usage_report/claude_code` requires an admin API key; personal Pro/Max accounts get 401. Use the OAuth internal endpoint (`/api/oauth/usage`) with the Claude Code Keychain token instead. Verify this before writing any other code.

2. **NSStatusItem garbage collected (menu bar icon vanishes)** — if `NSStatusItem` is created in a local variable rather than a stored property with app-level lifetime, ARC releases it silently. Store it in `StatusBarController` which is held by the `@main` App struct for the app's lifetime.

3. **Settings window inaccessible from menu bar app** — `SettingsLink` and `openSettings()` do not work reliably for apps with `.accessory` activation policy. Avoid a separate settings window entirely; handle API key entry (first-run setup) directly inside the popover panel.

4. **Timer retain cycle causes unbounded memory growth** — `Timer` closures that capture `self` strongly, when `self` also holds the timer, create a reference cycle. The app runs 24/7; this becomes noticeable within hours. Use structured concurrency (`Task` + `Task.sleep`) instead — it participates in cooperative cancellation and avoids the cycle entirely.

5. **Token storage in UserDefaults / @AppStorage** — plist-backed, readable by any process with disk access. OAuth tokens must live in the macOS Keychain only. The token already exists there from Claude Code's own login — read it from there rather than copying it elsewhere.

## Implications for Roadmap

Based on the dependency chain identified in ARCHITECTURE.md and the critical pitfall ordering from PITFALLS.md, a 4-phase structure is recommended.

### Phase 1: Foundation and API Verification

**Rationale:** The entire project depends on confirming the internal API endpoint works with the Claude Code Keychain token. This must be validated before any UI code is written. All subsequent phases depend on the types and Keychain service defined here. Two critical pitfalls (org-only API restriction, UserDefaults credential storage) must be addressed in this phase or they become expensive to fix later.

**Delivers:** Working Xcode project with LSUIElement, confirmed API call returning usage data, Keychain read of Claude Code OAuth token, typed models (`UsageResponse`, `AppError`), `KeychainService`, `UsageStore` with sample data, basic `StatusBarController` showing placeholder "—%"

**Addresses:** API key storage (Keychain), first-run "not logged in" detection, no Dock icon

**Avoids:** Org-only API pitfall (verify endpoint first), UserDefaults credential storage, NSStatusItem GC (establish stored property pattern immediately)

**Research flag:** NEEDS phase research — undocumented API endpoint, OAuth token refresh flow, Keychain service name for Claude Code credentials need empirical verification before implementation

### Phase 2: Polling Engine and Data Display

**Rationale:** Once the API contract and data types are confirmed, the polling loop and live display are the core value delivery. Timer retain cycle and rate limiting pitfalls belong here. The AppKit/SwiftUI bridge for the status bar title update is implemented here against real data.

**Delivers:** 60-second polling via structured concurrency, live percentage in menu bar label, color-coded green/yellow/red threshold, exponential backoff on errors (3 consecutive → stop + show error), error state label ("--"), `AnthropicAPIClient` with token refresh on 401/429

**Uses:** URLSession async/await, Security framework, Swift structured concurrency (`Task` + `Task.sleep`)

**Implements:** `PollingService`, `AnthropicAPIClient`, `StatusBarController` title update from `UsageStore`

**Avoids:** Timer retain cycle (use Task-based loop), polling below rate limit floor (60s minimum + backoff), updating UI from background thread (MainActor isolation)

**Research flag:** STANDARD — polling with Swift concurrency and URLSession are well-documented patterns; no phase research needed

### Phase 3: Panel UI and First-Run Flow

**Rationale:** The dropdown panel and setup flow are independent of polling correctness — they observe `UsageStore` state that already exists from Phase 2. Settings window inaccessibility pitfall applies here; design setup as in-panel flow from the start.

**Delivers:** NSPopover with SwiftUI interior showing daily usage meter, weekly usage meter, reset countdown, "Updated X ago" timestamp; `SetupView` for first-run (directs to `claude auth login` if token absent); graceful dismissal without setup; re-trigger setup path

**Implements:** `PanelView`, `UsageView`, `SetupView`, `NSHostingController` bridge in `StatusBarController`

**Avoids:** Settings window inaccessibility (in-panel setup only), `.onAppear` not firing in MenuBarExtra (using NSPopover delegate instead), blocking first-run prompt

**Research flag:** STANDARD — AppKit/SwiftUI popover bridge is well-documented; standard patterns apply

### Phase 4: Polish and Launch Readiness

**Rationale:** Launch-readiness items that are independent of core functionality: Launch at Login, adaptive icon, Quit menu item, error recovery UX, and the "looks done but isn't" checklist items from PITFALLS.md.

**Delivers:** Launch at Login toggle (SMAppService, opt-in default), adaptive template icon at 16pt 1x/2x, Quit menu item, manual refresh action (⌘R), percentage display edge cases (one decimal above 95%), App Nap exemption for polling, clean quit (timer cancel + URLSession task cancel)

**Uses:** SMAppService (macOS 13+), NSProcessInfo.processInfo.beginActivity, NSImage.isTemplate

**Avoids:** No Quit option (trapped app), stale data with no indicator, truncated menu bar label at 100%

**Research flag:** STANDARD — Launch at Login via SMAppService is well-documented; template image patterns are established

### Phase Ordering Rationale

- Phase 1 must be first because the API endpoint is undocumented and unverified — all other work depends on its contract
- Phase 2 before Phase 3 because the panel UI has nothing to display until `UsageStore` has real data; building UI against mock data first is acceptable but only if Phase 1 models are defined
- Phase 3 before Phase 4 because polish work (icon, Launch at Login) requires the full UX surface to be defined first
- The 5-component build order from ARCHITECTURE.md (Models → Keychain → Shell → Views → Polling) maps cleanly onto this phase structure

### Research Flags

Needs research before implementation:
- **Phase 1:** Undocumented OAuth usage endpoint — verify exact URL, required headers (`anthropic-beta: oauth-2025-04-20`), response shape, and 429 workaround behavior against a real Claude Code installation before any code is committed

Phases with standard patterns (skip research-phase):
- **Phase 2:** Swift concurrency polling + URLSession — well-documented, multiple production examples
- **Phase 3:** AppKit/SwiftUI NSPopover bridge — covered by official docs and multiple third-party write-ups
- **Phase 4:** SMAppService Launch at Login, template images — first-party Apple documentation is complete

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core Swift/SwiftUI/AppKit patterns verified across official docs and multiple production apps; API auth MEDIUM due to undocumented endpoint |
| Features | HIGH | Three direct competitors analyzed; feature set is well-established for this class of app; MVP scope is conservative |
| Architecture | HIGH | AppKit shell + SwiftUI interior is the consensus pattern; component boundaries and data flow verified against multiple production implementations |
| Pitfalls | HIGH | All 7 critical pitfalls verified against official docs, community reports, and existing implementations; recovery costs quantified |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Exact OAuth endpoint behavior:** The `/api/oauth/usage` response shape and 429 workaround are documented only from a GitHub issue thread (not official docs). Verify empirically against a real Claude Code installation in Phase 1 before building the API client.
- **Keychain service name variants:** Claude Code stores credentials under `Claude Code-credentials` but may have suffix variants across macOS versions. Verify the exact service name on the target machine before hardcoding it in `KeychainService`.
- **Token refresh client ID:** The OAuth client ID `9d1c250a-e61b-44d9-88ed-5944d1962f5e` is from third-party reverse engineering. Confirm it produces valid refresh responses before building the refresh flow.
- **MenuBarExtra vs NSStatusItem decision:** ARCHITECTURE.md recommends `NSStatusItem` over `MenuBarExtra` for programmatic control. The STACK.md notes `MenuBarExtra` as the modern first-party approach. Resolve this explicitly in Phase 1 scaffolding — the recommendation is `NSStatusItem` based on the limitations documented in PITFALLS.md.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — MenuBarExtra, NSStatusItem, NSPopover, Security/Keychain, SMAppService, URLSession
- apple/swift-async-algorithms (GitHub) — AsyncTimerSequence, version 1.1.3
- steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — SettingsLink bug confirmed 2025

### Secondary (MEDIUM confidence)
- github.com/anthropics/claude-code/issues/30930 — OAuth usage endpoint 429 bug, token structure, refresh flow
- github.com/griffinmartin/opencode-claude-auth — Claude Code Keychain service name and credentials JSON structure
- nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ — LSUIElement, Dock hiding, window style patterns
- github.com/goniszewski/cctray — competitor feature reference
- github.com/hamed-elfayome/Claude-Usage-Tracker — competitor with API-direct approach (closest comparable)
- github.com/joachimBrindeau/ccusage-monitor — competitor feature reference
- multi.app/blog/pushing-the-limits-nsstatusitem — NSStatusItem capabilities and limits
- platform.claude.com/docs/en/api/claude-code-analytics-api — confirmed org/admin-only restriction

### Tertiary (LOW confidence)
- theregister.com/2026/03/31/anthropic_claude_code_limits/ — Claude Code quota context; not used for API details

---
*Research completed: 2026-04-02*
*Ready for roadmap: yes*
