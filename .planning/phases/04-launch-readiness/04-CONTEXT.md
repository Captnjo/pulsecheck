# Phase 4: Launch Readiness - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning
**Mode:** Infrastructure phase — minimal context

<domain>
## Phase Boundary

Add Launch at Login toggle using SMAppService (macOS 13+). Add the toggle to the popover panel. Ensure quit stops polling and removes the menu bar icon cleanly.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — infrastructure phase. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key notes:
- Use SMAppService.mainApp for Launch at Login (macOS 13+, matches our macOS 14 minimum)
- Add a toggle switch in UsagePanelView above the Quit button
- Quit already works (NSApplication.terminate + stopPolling in applicationWillTerminate)

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — infrastructure phase. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — last phase.

</deferred>
