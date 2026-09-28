# PulseCheck

Native macOS menu bar monitor for Claude Code, Codex, and OpenRouter. Current version: v1.4.4.

## Architecture

- Swift 6 language mode, SwiftUI views hosted by AppKit NSStatusItem + NSPopover; macOS 14+.
- Icon-only menu bar; UsagePanelView presents three provider tabs.
- UsageStore (@Observable, @MainActor) coordinates polling, recovery, stale data, and Claude burn-rate projections.
- URLSession networking; no external package dependencies.
- Claude: enumerate Keychain persistent references, read each password individually, select freshest expiresAt; also supports a CLAUDE_CONFIG_DIR-aware credentials-file fallback.
- Never combine kSecReturnData with kSecMatchLimitAll for password queries: macOS returns errSecParam (-50). This broke v1.4.3 and is repaired in v1.4.4.
- Credential provenance is mandatory: never consume Claude Code's refresh token. Only PulseCheck-owned shadow credentials may be refreshed. Codex and OpenRouter credentials remain read-only.
- Not App Store sandboxed; distribution is an ad-hoc-signed DMG. Developer ID signing/notarization remains deferred.

## Verification and releases

- Clean test: `xcodebuild -project PulseCheck.xcodeproj -scheme PulseCheck -destination 'platform=macOS' clean test` (48 tests).
- Release: bump all four MARKETING_VERSION settings; run `./scripts/build-dmg.sh`.
- Publish source and tag to origin (GitHub) and nas (Forgejo); publish DMG on GitHub Releases; update README download link and Captnjo/homebrew-tap cask version/checksum; verify downloaded SHA-256 and Homebrew metadata.
- Do not add shouldAutocreateTestPlan to the shared scheme: older Xcode 16.3 crashes with that setting.
- Durable project findings live in `_memory/`; transient work state lives in `HANDOFF.md`.

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->
