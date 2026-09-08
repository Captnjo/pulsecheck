# HANDOFF — PulseCheck

## Next up (open threads)

- **Verify Claude tab recovery on the real machine** — v1.4.3 (duplicate keychain-item fix) is released; Jo still needs to `brew upgrade --cask pulsecheck`, click **Always Allow** on the one new Keychain prompt (reading the live Apr-23 item for the first time), and confirm the tab populates. If it still fails after that, the next diagnostic is logging the decoded item count + chosen expiresAt at info level.
- **Developer ID signing + notarization** — the permanent fix for per-release Keychain re-prompts (ad-hoc signatures reset ACL grants every build). Blocked on Jo's $99/yr Apple Developer account decision. README documents the manual workaround.
- **Deferred features** (competitor research, deliberately parked): OpenRouter `/api/v1/credits` + `/activity` for management-capable keys (balance, 30-day charts, per-model costs), history sparklines, multi-profile Claude accounts (`CLAUDE_CONFIG_DIR`).
- **Release pipeline discipline** — the README download link was skipped on 1.4.1-1.4.3 (caught by Jo). It is a mandatory step of every release: tag → release → README → cask → brew check.

## State of work (this session, v1.2 → v1.4.3)

All released (GitHub releases + brew cask + NAS + GitHub, sha256 verified end-to-end each time). 41 unit tests, all passing. Committed and pushed everywhere.

- v1.2: security audit — never consume Claude Code's refresh token (provenance-tracked `claudeCode` vs `shadow` creds). THE core safety invariant.
- v1.3: multi-provider (Codex via `~/.codex/auth.json` → wham/usage; OpenRouter via opencode auth.json → `/api/v1/key`). Read-only creds for both. Tabs per provider, sandbox dropped (needs home-dir dotfiles).
- v1.3.1-1.3.4: codex window labels by actual duration (position lies), Keychain prompt reduction, 429-storm fix (rejected-token memory + Retry-After), SF Symbol tab icons.
- v1.4: competitor-research release — burn-rate projection, adaptive bars (green/amber/red, tint by projection), degrade-don't-blind, transport-vs-server retry split, oauth_apps weekly preference + percent-scale normalization, 15s refresh spam guard. Sources: Omarchy omarchy-agent-usage-claude, GNOME ClaudeCodeUsage, OpenRouter Monitor.
- v1.4.1: icon-only menu bar (worst-of % misleading across 3 providers); rejected-token re-read fix.
- v1.4.2: multi-store credential discovery (keychain + `~/.claude/.credentials.json`, CLAUDE_CONFIG_DIR-aware); shadow lineage survives transient refresh failures (only definitive invalid_grant drops it).
- v1.4.3: **the decisive fix** — duplicate `Claude Code-credentials` keychain items made `kSecMatchLimitOne` return the fossil while `claude auth login` refreshed the other twin. Now MatchLimitAll + freshest expiresAt. Implemented by codex (gpt-5.6-sol) as a delegated subagent from a diagnosed brief; independently verified.

Root-cause archaeology worth knowing: Claude Code 2.x (bun binary) keeps live OAuth tokens in memory per session; its keychain items and `~/.claude.json` can all be stale/metadata-only. Full chain recorded in project memory (root-cause-claude-signout.md).

## Env quickrefs

- Build: `xcodebuild -project PulseCheck.xcodeproj -scheme PulseCheck -destination 'platform=macOS' build`
- Test: same with `test` (41 tests, PulseCheckTests target)
- Release DMG: `./scripts/build-dmg.sh` (version from MARKETING_VERSION — bump in project.pbxproj, 4 config slots)
- Release pipeline (EVERY step mandatory): bump MARKETING_VERSION → build-dmg.sh → commit+push both remotes → tag vX.Y.Z → `gh release create vX.Y.Z <dmg>` → **sed README download link** → tap cask (Captnjo/homebrew-tap, Casks/pulsecheck.rb: version+sha256, verify by curling release URL) → `brew info --cask captnjo/tap/pulsecheck`
- Codex delegation pattern that worked: `codex exec -m gpt-5.6-sol -s workspace-write --cd <repo> "<diagnosed brief>"` — no GPT-6 exists on Jo's ChatGPT-account codex; gpt-5.6-sol is the strongest. Give it the root cause + exact spec + test command; verify its test run independently.
- xcodebuild on this Mac: CoreSimulator version warning is noise; **never add `shouldAutocreateTestPlan` to the shared scheme — hard-crashes xcodebuild 16.3**
- Remotes: `nas` = Forgejo 192.168.1.212 (jo/claudemacwidget.git — legacy name), `origin` = github.com/Captnjo/pulsecheck. Both Jo's.
- Root-cause doc: `~/.claude/projects/-Users-jo-Projects-Pulsecheck/memory/root-cause-claude-signout.md`
