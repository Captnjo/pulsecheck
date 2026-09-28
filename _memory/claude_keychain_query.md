---
name: claude_keychain_query
description: macOS rejects bulk password-data queries; enumerate references and read individually.
type: project
---

# Claude Keychain query regression

On 2026-09-27, installed PulseCheck v1.4.3 displayed "Claude Code not logged in" while Claude CLI 2.1.283 reported a logged-in Max account. Instrumented PulseCheck returned OSStatus -50 (errSecParam) before decoding any credentials.

The v1.4.3 duplicate-item fix combined kSecReturnData with kSecMatchLimitAll. macOS forbids that combination for password items. Enumerate references first, then request data for each individual item and select the freshest decodable credentials by expiresAt. Never return to selecting an arbitrary duplicate, and never consume Claude Code's refresh token.

Source: https://developer.apple.com/documentation/security/secitemcopymatching(_:_:)

The corrected implementation uses a persistent-reference enumeration followed by individual password reads. Seven regression tests cover the query sequence, duplicate selection, malformed/unreadable candidates, missing items, and enumeration failure. A clean full suite passed 48 tests. Live verification on 2026-09-27 read two candidates, selected unexpired credentials, and received HTTP 200 from Claude, Codex, and OpenRouter. Released as v1.4.4 on 2026-09-28. Source and tag published to GitHub and NAS; DMG published to GitHub Releases; Homebrew cask updated and installed locally. Downloaded DMG matches local SHA-256 bdd6e4d65297a856ee1ff2379a375b2186acd44908a36b3b481661caed3277c8. Installed release signature/version verified and all three providers returned HTTP 200.
