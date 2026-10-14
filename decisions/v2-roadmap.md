# V2 roadmap

Status: roadmap updated with Sam's Miri dock request on 14 October 2026.
These entries do not expand v1 acceptance criteria.

## Scope boundary

Multi-monitor support belongs to v1 following Sam's revised scope decision.
Each physical monitor uses the same horizontal scrolling layout as the main display, with independent window order, focus, and scroll position.
Horizontal, vertical, and mixed arrangements that Sam can verify on real hardware are v1 requirements.
Reliable horizontal multi-monitor scrolling blocks the v1 release if it fails.
The accepted behavior is recorded in the [release scope](release-scope.md).
Display support is not deferred to this roadmap.

## Accepted v2 work

Sam accepted the Miri dock for v2 and deferred the other work below during the interview on 14 October 2026.

- An optional Miri dock is enabled by default and can be disabled or enabled again.
  When inactive-window dimming is enabled, the Miri dock dims too.
  A stack containing windows from multiple apps shows multiple app icons in its dock entry.
  See [Miri dock](#miri-dock) for the accepted scope and window representation.
- Portable display layouts could carry a workspace between monitor setups, such as university, home, and work.
  A persistent setting would choose between restoring the previous layout, keeping the current layout, and applying saved window restoration rules.
  A separate setting would control whether layouts transfer to different physical monitors.
  This work depends on a Paneru interface that moves a strip to a chosen display.
  Display changes require one rule for any monitor count, not separate rules for each transition.
- Tabbed columns, the minimap, inactive-window dimming, advanced window rules, and drag-to-reorder are deferred from v1.
- A guided tutorial could teach the strip and essential shortcuts on first run.
- Grid monitor arrangements and the maximum supported display count move from v1.
  The target is eight displays, the most that Apple documents for any current Mac.
  A 3x3 grid needs nine displays and therefore exceeds that limit.
- Paneru's virtual workspaces, which add extra strips within one native Space, are turned off in v1 and planned for v2.
- Five-finger strip gestures are deferred from v1.
  The pinned engine's acceptance of the finger count does not establish usable hardware behavior.
- Focus borders, pointer-following controls, display exclusions, cross-display dragging, fixed-pixel presets, animation tuning, and Hyper-key recording are excluded from v1.
  Sam accepted these deferrals in the subsequent design-tree interview on 14 October 2026.
  Their deferral does not commit to implementing every proposal in v2.

## Miri dock

Sam requested a custom Miri dock for v2 on 14 October 2026.
The visual reference is Sam's supplied image, `Screenshot 2026-10-14 at 12.25.28.png`.
It shows a horizontal row of rounded app-icon entries and a highlighted focused entry.

The Miri dock is enabled by default and has an enable or disable control.
It dims when inactive-window dimming is enabled and shows multiple app icons for mixed-app stacks.
The custom Miri dock is separate from the macOS Dock and Miri's app icon within the macOS Dock.
These requirements do not expand v1 scope or establish implemented behavior.

### Representation of windows

Following Sam's "continue" response, the same-app recommendation is recorded as the v2 design.
The dock uses one entry per column, in scrolling-strip order.
A stack's entry contains one icon per distinct app.
If a stack contains several windows from the same app, that app's icon shows a window-count badge.
For example, a stack with two Safari windows and one Terminal window shows Safari with a `2` badge beside Terminal.
Selecting an app icon with several windows opens a picker that identifies each window by its title.
Selecting a window in the picker focuses that specific window.
If the same app has windows in separate columns, its icon appears in each corresponding column entry.
This representation preserves column positions while distinguishing windows that share an app icon.

Sam selected On by default for the Miri dock.
Dock placement, click behavior for single-window entries, and exact dimming appearance remain open.
Window selection must remain distinguishable when titles are identical or unavailable.
The picker design must respect Miri's existing no-screen-capture boundary.

## Candidate quality-of-life improvements

Sam deferred further quality-of-life improvements to v2 without selecting the complete feature list.
The following candidates come from Miri's design documents and are not accepted v2 requirements.

- A minimap could show the current position in the strip.
- A focus border and inactive-window dimming could identify the focused window.
- Gesture controls beyond v1's three fingers, four fingers, Off, and persistent direction reversal remain candidates.
- Dragging could reorder windows and columns.
- Per-app rules could control floating windows and strip placement.
- Automation could expose commands through a CLI, a URL scheme, or Raycast.

The accepted deferrals above determine which candidates are excluded from v1.
Each remaining candidate needs an explicit scope decision before implementation.
