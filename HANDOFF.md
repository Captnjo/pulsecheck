# HANDOFF — PulseCheck

## Next up (open threads)

- **Codex tab will show "Auth expired" until Jo runs codex once** — his stored token is stale (last refresh Jul 23); the wham/usage endpoint is verified-correct from source, it self-heals on codex's next run. Nothing to build.
- **Developer ID signing + notarization** — the one remaining fix for the Keychain re-prompt-per-release annoyance (ad-hoc signature changes every build, so macOS re-asks "Always Allow"). Needs Jo's $99/yr Apple Developer account decision. Documented in README's Keychain section.
- **Possible next features** (from the competitor research, deliberately deferred): OpenRouter `/api/v1/credits` + `/activity` for management-capable keys (balance, 30-day charts, per-model costs), history sparklines, multi-profile Claude accounts (`CLAUDE_CONFIG_DIR`). None committed.
- **GitHub Release download link** in README points at v1.4 — keep in sync on every release (one-line sed, done every time so far).

## State of work (finished this session)

v1.2 → v1.4 all shipped (GitHub releases + brew cask + NAS + GitHub, sha256 verified each time):
- v1.2: security audit fixes — the big one: PulseCheck was consuming Claude Code's refresh token (rotation-on-use) and logging Claude Code out. Now provenance-tracked (`claudeCode` vs `shadow`), never consumes another tool's refresh token. THE core safety invariant of this codebase.
- v1.3: multi-provider — Codex (`~/.codex/auth.json` → chatgpt.com/backend-api/wham/usage) + OpenRouter (opencode's auth.json → /api/v1/key). Read-only creds for both. Tabs per provider, worst-of menu bar title. Sandbox entitlement dropped (needs home-dir dotfiles).
- v1.3.1: codex window labels derived from window duration, not position (Jo caught the bug).
- v1.3.2: Keychain prompt reduction (no primary-item read while shadow valid).
- v1.3.3: 429-storm fix — remember rejected token, zero API calls until keychain changes; honor Retry-After.
- v1.3.4: SF Symbol icons per provider tab.
- v1.4: competitor-research release — burn-rate projection ("burning fast — out in ~1h20m"), adaptive bars (green/amber/red at 50/80, tint by projection), degrade-don't-blind on API errors, transport-vs-server retry split, oauth_apps weekly preference + 0-1/0-100 scale normalization, 15s refresh spam guard. Sources: Omarchy's omarchy-agent-usage-claude (omacom/omarchy, quattro branch), GNOME ClaudeCodeUsage, OpenRouter Monitor.

37 unit tests, all passing. Everything committed and pushed (NAS + GitHub + tap).

## Env quickrefs

- Build: `xcodebuild -project PulseCheck.xcodeproj -scheme PulseCheck -destination 'platform=macOS' build`
- Test: same with `test` (37 tests, PulseCheckTests target)
- Release DMG: `./scripts/build-dmg.sh` (version from MARKETING_VERSION — bump in project.pbxproj, 4 config slots)
- Release pipeline: tag `vX.Y.Z` → `gh release create vX.Y.Z <dmg>` → README download link → tap repo (`/var/folders/.../opencode/tap` clone or `~/Projects`-adjacent; repo = Captnjo/homebrew-tap, Casks/pulsecheck.rb, bump version+sha256, verify by curling the release URL) → `brew info --cask captnjo/tap/pulsecheck` to confirm
- `xcodebuild` on this Mac: CoreSimulator version warning is noise; **never add `shouldAutocreateTestPlan` to the shared scheme — hard-crashes xcodebuild 16.3**
- Remotes: `nas` = Forgejo 192.168.1.212 (jo/claudemacwidget.git — legacy name), `origin` = github.com/Captnjo/pulsecheck. Both are Jo's.
- Root-cause doc for the original sign-out bug: `~/.claude/projects/-Users-jo-Projects-Pulsecheck/memory/root-cause-claude-signout.md`
