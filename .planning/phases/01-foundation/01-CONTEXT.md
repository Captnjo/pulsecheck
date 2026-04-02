# Phase 1: Foundation - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a running macOS menu bar app that reads Claude Code credentials from the Keychain (with file fallback), makes a test API call to the Anthropic usage endpoint, and displays a placeholder "—%" in the menu bar with a Quit item. No Dock icon. This phase validates that the undocumented API endpoint works before building real UI on top of it.

</domain>

<decisions>
## Implementation Decisions

### App Structure
- Xcode project (not SPM) — standard for macOS apps, needed for Info.plist and entitlements
- Minimum deployment target: macOS 14 (Sonoma) — enables @Observable and modern Swift concurrency
- App name: ClaudeUsage, bundle ID: com.jo.ClaudeUsage
- NSStatusItem + NSPopover architecture (not MenuBarExtra) — research confirms MenuBarExtra can't update title text dynamically

### Credential Reading
- Keychain service name: "Claude Code-credentials" — this is the entry Claude Code uses
- Fallback path: ~/.claude/.credentials.json
- When no credentials found: show "No credentials" in menu bar text, log to console
- No UserDefaults state in Phase 1 — credentials in Keychain only

### API Verification
- Try `GET /api/oauth/usage` with `anthropic-beta: oauth-2025-04-20` header first
- Build thin abstraction layer — parse response into typed Swift models, easy to swap endpoint later
- If endpoint doesn't work: log raw response, show "API unavailable" in menu bar — fail gracefully

### Claude's Discretion
- Internal code organization (file/folder structure within Xcode project)
- Error logging approach (OSLog vs print)
- Exact Codable model field names (discover from actual API response)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — this phase establishes the patterns

### Integration Points
- macOS Keychain (Security framework)
- Claude Code credentials file (~/.claude/.credentials.json)
- Anthropic API (undocumented OAuth endpoint)

</code_context>

<specifics>
## Specific Ideas

- Inspired by czuryk/Waveshare-ePaper-10.85-dashboard which reads Claude Code usage via OAuth
- Research identified the OAuth client ID `9d1c250a-e61b-44d9-88ed-5944d1962f5e` for token refresh — verify empirically
- STATE.md flagged: verify exact URL, required headers, response shape, and 429 token-refresh behavior

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
