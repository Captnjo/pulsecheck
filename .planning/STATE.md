---
gsd_state_version: 1.0
milestone: v1.1
milestone_name: Polish & Resilience
status: complete
stopped_at: Milestone v1.1 complete
last_updated: "2026-04-03T00:00:00Z"
last_activity: 2026-04-03
progress:
  total_phases: 3
  completed_phases: 3
  total_plans: 4
  completed_plans: 4
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-03)

**Core value:** Instant visibility into Claude Code usage limits without leaving the desktop
**Current focus:** Planning next milestone

## Current Position

Phase: Complete
Plan: All plans complete
Status: v1.1 milestone shipped
Last activity: 2026-04-03

Progress: [##########] 100%

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

### Critical Architecture Notes

- **Keychain ACL**: Never call `SecItemUpdate` on `Claude Code-credentials`. Write refreshed tokens to `PulseCheck-claude-credentials` (PulseCheck-owned shadow item). Attempting to update Claude Code's item silently consumes the single-use refresh token and locks the user out.
- **Refresh race condition**: Gate all token refresh calls behind a Swift actor with a stored `Task<ClaudeOAuthCredentials, Error>?` handle. All callers await the same Task — one network request goes out.
- **Icon + colored text conflict**: `NSStatusBarButton.contentTintColor` tints both image and text simultaneously. Use template icon OR colored `attributedTitle` — do not mix on the same button.
- **403 scope-loss bug**: Anthropic server-side bug causes refreshed tokens to be missing `user:profile` scope. Inspect 403 body for "scope" / "user:profile" and route to `.apiUnauthorized` recovery path.

### Pending Todos

(None — milestone complete)

### Blockers/Concerns

- Undocumented OAuth endpoint — may break without notice

## Session Continuity

Last session: 2026-04-03
Stopped at: Milestone v1.1 complete
Resume file: None
