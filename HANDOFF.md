# HANDOFF — PulseCheck

## Current work

v1.4.4 released and installed (2026-09-28). Source and tag pushed to GitHub and NAS; GitHub DMG and Homebrew cask published.

- Fixed Claude Keychain discovery: v1.4.3 combined kSecReturnData with kSecMatchLimitAll, which macOS rejects with errSecParam (-50). Now enumerates persistent references, reads individual items, and selects freshest credentials.
- Seven regression tests added; clean v1.4.4 full suite passes 48 tests. Local fixed build previously verified HTTP 200 for Claude, Codex, and OpenRouter.
- v1.4.4 DMG built, ad-hoc signature verified, image checksum verified. SHA-256: bdd6e4d65297a856ee1ff2379a375b2186acd44908a36b3b481661caed3277c8.
- README, CHANGELOG, CLAUDE.md, project declaration, and permanent memory updated.
- Published DMG downloaded and verified byte-for-byte. Homebrew upgraded the installed app to 1.4.4; signature and bundle version verified. Installed app loaded two Keychain candidates and received HTTP 200 from Claude, Codex, and OpenRouter. Claude briefly returned HTTP 429 before succeeding.
- Release: https://github.com/Captnjo/pulsecheck/releases/tag/v1.4.4
- Homebrew cask commit: 685298e. Previous app backup: `/tmp/PulseCheck-1.4.3-backup.app`. No remaining release actions.

## Open threads

- Developer ID signing/notarization remains deferred pending Jo's Apple Developer account decision. Ad-hoc signatures cause Keychain access prompts after updates.
- Deferred features: OpenRouter management-key balance/history, usage sparklines, multi-profile Claude accounts.

## Quick references

- Test: `xcodebuild -project PulseCheck.xcodeproj -scheme PulseCheck -destination 'platform=macOS' clean test`.
- DMG: `./scripts/build-dmg.sh`; version lives in four MARKETING_VERSION entries.
- Mandatory release pipeline: source + tag on both remotes, GitHub DMG release, README link, Homebrew cask version/checksum, downloaded SHA-256 verification, brew metadata check.
- origin: github.com/Captnjo/pulsecheck; nas: ssh://git@192.168.1.212:30143/jo/claudemacwidget.git (legacy name).
- Never consume Claude Code's refresh token. Never combine bulk password matching with data return.
- Durable root cause: `_memory/claude_keychain_query.md`.
- Never add shouldAutocreateTestPlan to the shared scheme; Xcode 16.3 crashes on it.
