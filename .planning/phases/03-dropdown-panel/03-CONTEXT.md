# Phase 3: Dropdown Panel - Context

**Gathered:** 2026-04-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the SwiftUI popover panel that appears when clicking the menu bar item. Shows daily and weekly usage with progress bars and reset time countdowns. Displays error states when offline or auth fails. Includes a Quit button at the bottom.

</domain>

<decisions>
## Implementation Decisions

### Panel Layout
- SwiftUI view hosted in the existing NSPopover — two sections (Daily/Weekly), each with label + progress bar + reset time
- Use native SwiftUI ProgressView (linear style) with percentage label
- Reset time as relative countdown ("Resets in 2h 15m") — most actionable for the user
- Panel width: 280px — compact but readable

### Error States
- On error: replace content area with error message + icon — simple and clear
- Quit button at bottom of panel — always visible

### User Clarification (from discuss Phase 2)
- Menu bar: daily usage percentage only
- Popover on click: progress bars + reset times for BOTH daily and weekly

### Claude's Discretion
- Exact color scheme and styling
- Spacing and padding values
- Font sizes
- Whether to show exact numbers alongside progress bars (e.g. "51% used" vs just the bar)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- UsageStore.usageResponse — already has the full UsageResponse with fiveHour and sevenDay periods
- UsageResponse.UsagePeriod — has utilization, expiresAt fields
- StatusBarController — already has NSPopover, just needs contentViewController set
- onTitleChanged callback pattern from Phase 2

### Established Patterns
- @Observable @MainActor UsageStore
- NSStatusItem + NSPopover architecture
- StatusBarController manages popover show/hide

### Integration Points
- StatusBarController.popover.contentViewController needs to be set to NSHostingController wrapping the SwiftUI view
- SwiftUI view observes UsageStore for data
- Left-click toggles popover (already wired)

</code_context>

<specifics>
## Specific Ideas

- The API response includes expiresAt timestamps (milliseconds) for both fiveHour and sevenDay — use these for reset countdown
- UsagePeriod already has displayString for percentage — reuse in the panel

</specifics>

<deferred>
## Deferred Ideas

- Color-coded progress bars based on thresholds → v2
- Manual refresh button → v2
- Last-updated timestamp → v2

</deferred>
