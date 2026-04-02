<!-- GSD:project-start source:PROJECT.md -->
## Project

**Claude Mac Widget**

A macOS menu bar app that displays Claude Code usage data at a glance. Shows a usage percentage in the menu bar with a dropdown panel containing daily limit, weekly limit, and limit reset time. Polls the Anthropic API every minute for fresh data.

**Core Value:** Instant visibility into Claude Code usage limits without leaving the desktop.

### Constraints

- **Platform**: macOS only, SwiftUI + AppKit for menu bar integration
- **API**: Depends on Anthropic API having a usage/limits endpoint
- **Polling**: 60-second interval, must handle rate limits and network errors gracefully
- **Distribution**: Run locally, no App Store requirement for v1
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
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
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16.3 | IDE, compiler, signing | Minimum for Swift 6.1; macOS 15.2 required to run Xcode 16.3 |
| Swift Package Manager | Dependency management | Built into Xcode; no CocoaPods or Carthage needed for this project |
| Instruments (Time Profiler) | Performance | Verify 60s polling does not wake CPU excessively; use Timer coalescing |
## Installation
## API Authentication: Critical Design Decision
## Minimum Deployment Target
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftUI `MenuBarExtra` (.window style) | AppKit `NSStatusItem` + `NSMenu` | Only if targeting macOS 12 or earlier, or needing pixel-perfect control over menu item layout that SwiftUI can't provide |
| First-party Keychain (Security framework) | KeychainAccess (kishikawakatsumi) | If you need to read/write multiple Keychain items across many services; for a single token, the wrapper adds more complexity than it saves |
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
- Read service `Claude Code-credentials` from the system Keychain using `SecItemCopyMatching`
- Parse JSON `accessToken` / `refreshToken` / `expiresAt` fields
- No API key setup UI needed; piggyback on the user's existing Claude Code login
- This is the preferred UX: zero friction for existing Claude Code users
- Fall back to reading `~/.claude/.credentials.json` (the Linux/SSH fallback that Claude Code also writes)
- Show a first-run setup screen directing user to run `claude auth login`
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
## Sources
- https://sarunw.com/posts/swiftui-menu-bar-app/ — MenuBarExtra scene API patterns (MEDIUM confidence — 2022 article, API confirmed stable to 2025)
- https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ — `.window` style, LSUIElement, Dock hiding (MEDIUM confidence)
- https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — SettingsLink bug in MenuBarExtra (HIGH confidence — 2025 first-hand report)
- https://github.com/anthropics/claude-code/issues/30930 — OAuth usage endpoint 429 bug, token structure, refresh flow (MEDIUM confidence — issue thread, not official docs)
- https://github.com/apple/swift-async-algorithms — swift-async-algorithms 1.1.3 (March 2026), AsyncTimerSequence (HIGH confidence — official Apple repo)
- https://developer.apple.com/documentation/security/storing-keys-in-the-keychain — Keychain API (HIGH confidence — official docs)
- https://github.com/griffinmartin/opencode-claude-auth — Claude Code Keychain service name pattern, credentials JSON structure (MEDIUM confidence — third-party reverse engineering)
- https://www.theregister.com/2026/03/31/anthropic_claude_code_limits/ — Claude Code quota issues context (LOW confidence for API details)
- https://medium.com/better-programming/create-menu-bar-apps-for-macos-ventura-or-higher-4c05a5b28e31 — macOS 13 minimum confirmed for MenuBarExtra (MEDIUM confidence)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
