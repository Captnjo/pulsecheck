# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-02)

**Core value:** Instant visibility into Claude Code usage limits without leaving the desktop
**Current focus:** Phase 1 — Foundation

## Current Position

Phase: 1 of 4 (Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-04-02 — Roadmap created

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Research: Use NSStatusItem + NSPopover (not MenuBarExtra) — programmatic show/hide and title updates require it
- Research: OAuth internal endpoint (`/api/oauth/usage`) is the only viable path for personal Pro/Max accounts; official analytics API is org-admin-only
- Research: Keychain service name is `Claude Code-credentials`; verify on target machine before hardcoding

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 1: Undocumented OAuth endpoint — verify exact URL, required headers, response shape, and 429 token-refresh behavior against a real Claude Code installation before writing API client code
- Phase 1: OAuth client ID `9d1c250a-e61b-44d9-88ed-5944d1962f5e` is from third-party reverse engineering — confirm it produces valid refresh responses

## Session Continuity

Last session: 2026-04-02
Stopped at: Roadmap created, ready to plan Phase 1
Resume file: None
