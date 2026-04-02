---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Polish & Resilience
status: verifying
stopped_at: Completed 05-01-PLAN.md
last_updated: "2026-04-02T18:36:17.908Z"
last_activity: 2026-04-02
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 1
  completed_plans: 1
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-02)

**Core value:** Instant visibility into Claude Code usage limits without leaving the desktop
**Current focus:** Phase 05 — visual-polish

## Current Position

Phase: 05 (visual-polish) — EXECUTING
Plan: 1 of 1
Status: Phase complete — ready for verification
Last activity: 2026-04-02

Progress: [..........] 0%

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

- [Phase 05-visual-polish]: Set isTemplate = true in code for belt-and-suspenders template rendering alongside asset catalog template-rendering-intent
- [Phase 05-visual-polish]: No contentTintColor on NSStatusBarButton — tints both icon and text; template image is the correct approach

### Critical Architecture Notes

- **Keychain ACL**: Never call `SecItemUpdate` on `Claude Code-credentials`. Write refreshed tokens to `PulseCheck-claude-credentials` (PulseCheck-owned shadow item). Attempting to update Claude Code's item silently consumes the single-use refresh token and locks the user out.
- **Refresh race condition**: Gate all token refresh calls behind a Swift actor with a stored `Task<ClaudeOAuthCredentials, Error>?` handle. All callers await the same Task — one network request goes out.
- **Icon + colored text conflict**: `NSStatusBarButton.contentTintColor` tints both image and text simultaneously. Use template icon OR colored `attributedTitle` — do not mix on the same button.
- **403 scope-loss bug**: Anthropic server-side bug causes refreshed tokens to be missing `user:profile` scope. Inspect 403 body for "scope" / "user:profile" and route to `.apiUnauthorized` recovery path.

### Pending Todos

- Validate OAuth refresh endpoint (`POST https://console.anthropic.com/v1/oauth/token`) with a live `curl` test before starting Phase 7 implementation.
- Decide shadow item conflict resolution: when both `Claude Code-credentials` and `PulseCheck-claude-credentials` exist, define which CredentialsService prefers and under what fallback conditions.

### Blockers/Concerns

- Undocumented OAuth endpoint — may break without notice
- OAuth refresh endpoint/client_id from third-party sources only (MEDIUM confidence) — validate before Phase 7

## Session Continuity

Last session: 2026-04-02T18:36:17.905Z
Stopped at: Completed 05-01-PLAN.md
Resume file: None
