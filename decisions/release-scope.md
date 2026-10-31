# Release scope

Status: accepted direction from Sam's design interview on 13 and 14 October 2026.
The [app acceptance checklist](v1-app-acceptance-checklist.md) records checks derived from accepted app behavior.
Remaining decisions and engineering prerequisites appear in [Design tree status](design-tree-status.md).

## Product purpose

Miri provides an app interface for a scrolling window manager.
Its native app interface is designed and will be built from the ground up for Miri.
Sam intends to use it daily and release it publicly as free and open-source software.
The interface addresses Sam's dissatisfaction with Paneru's existing UI.

## V1

V1 focuses on getting the window manager running through an app.
Miri bundles a pinned Paneru-based engine.
Changes to the engine focus on app integration, isolation, and verified compatibility fixes.
Compatibility fixes are contributed upstream where possible instead of establishing a permanent Paneru fork.
Miri pins the latest Paneru release tag, which is `v0.5.2` on 14 October 2026, plus any Miri patches.
Miri upgrades one release tag at a time, after a multi-monitor regression check on Sam's hardware.
The engine runs as a separate helper process inside `Miri.app`, as recorded in [ADR 0009](../docs/adr/0009-run-the-engine-as-a-helper-process.md).

### App controls and window recovery

The app provides start and stop controls, permission guidance, gap settings, width presets, shortcut editing, and access to logs.
The settings interface uses SwiftUI, with AppKit where needed, and provides menu bar controls.
Closing settings keeps window management running.
Stop pauses management, and Quit Miri stops both the app and its engine.
All managed windows must remain accessible after Miri stops, quits, or experiences an unrecoverable engine failure.
Never leave windows stranded off-screen.
The app acceptance checklist covers these controls and their failure behavior.

### Signing, distribution, and updates

Miri ships as a disk image signed with an Apple Developer ID and notarized by Apple.
Sparkle provides automatic updates, which also deliver engine upgrades.
A Homebrew cask is also offered.
By default, Miri checks for updates daily and asks before installing.
If the user enables automatic updates, Miri installs updates silently in the background at startup.

Sam enrolls in the Apple Developer Program before the first public release.
Development builds use ad-hoc signing on Sam's Mac.

The bundle ID is `io.github.samanyudas.miri`, and the engine helper uses `io.github.samanyudas.miri.engine`.
Development builds are named **Miri Developer** and use `io.github.samanyudas.miri.dev` and `io.github.samanyudas.miri.dev.engine`.
The separate identity keeps their Accessibility entry, preferences, and Launch Services identity apart from an installed release.
A contributor can therefore keep the released Miri installed in Applications next to a development build.
Development builds sign with a stable local identity when one exists, so their Accessibility grant survives rebuilds.
Sam accepted this on 14 October 2026.

The `samanyudas/miri` repository becomes public at the first working build.
The GPL requires the source to be public by the time any binary is distributed.

### Privacy and diagnostics

Miri sends no telemetry or window-management data off the Mac.
Update checks and downloads use the network.
Logs stay local, and a **Copy diagnostics** control prepares information for GitHub issues.
Diagnostics include versions, monitor setup, permission status, engine status, and redacted logs.
Window titles, document paths, usernames, and raw configuration are excluded by default.
Miri provides a preview before copying.

### Default shortcuts and layout

Default shortcuts follow the [keybinding reference](keybinding%20reference.md).
Actions it does not cover use Paneru's defaults, changed only where they clash with macOS.

Default width presets are `[0.25, 0.33, 0.5, 0.66, 0.75]`, and the inner and outer gaps are 8 points each.
The width preset list uses Paneru's `[options].preset_column_widths` key.
Mapping the accepted eight-point gaps to the pinned engine's padding fields remains engineering work.
New windows start at 50% of display width, and existing windows retain their widths.
Each width or height adjustment changes the size by five percentage points of the display's corresponding dimension, subject to window size constraints.

### Startup and crash recovery

Opening Miri starts window management after Accessibility permission is granted.
An explicit stopped state persists across launches.
Settings offer launch at login, enabled by default.

Miri restarts the engine automatically after an isolated crash.
After repeated crashes, Miri stops retrying and shows the failure.
The failure view provides logs and a manual restart control.
Three crashes within five minutes count as repeated crashes.
Paneru's startup session restore is on, so the layout returns after an engine start or crash restart.
A current floating rule wins over a saved tiled placement, so a window that matches a floating rule floats after a restart even if it was tiled when the layout was saved.
Sam decided this on 16 October 2026 in #15.
One exception applies, which Sam accepted on 25 October 2026 in [#93](https://github.com/samanyudas/miri/issues/93).
When the user tiles a window with the float toggle while a floating rule matches it, that window stays tiled after an engine or Miri restart.
The override lasts while that native window stays open, and it ends when the window floats again or closes.
It never passes to another window, and a saved tiled placement alone does not create it.
Dragging a floating window does not create it either.
A successful manual restart resets the count.

## Setup and conflicts

### Conflicts and setup checker

Miri refuses to start window management while a competing window manager runs, including standalone Paneru.
It names the tool to quit and leaves that tool's configuration untouched.
Miri also refuses to start while **Displays have separate Spaces** is off, because [ADR 0008](../docs/adr/0008-follow-macos-space-migration-for-display-changes.md) depends on it.
Miri explains that changing this setting requires logging out.

V1 includes a setup checker.
It reports missing Accessibility permission, **Displays have separate Spaces** turned off, Stage Manager turned on, competing window managers, and macOS gestures that clash with the strip swipe.
It also reports each macOS tiling option that is on, because macOS tiling moves windows that Miri arranges, including dragged windows ([#43](https://github.com/samanyudas/miri/issues/43)).
The options are **Drag windows to screen edges to tile**, **Drag windows to menu bar to fill screen**, and **Hold Option key while dragging windows to tile**.
These conflicts never block window management.
The setup checker links to the relevant System Settings page and never changes macOS settings itself.
If a non-gesture setting cannot be inspected, the checker shows **Not checked** with manual instructions.
An unavailable check is never presented as passed.
Strip gesture conflicts follow [Strip gestures](#strip-gestures).
The guided shortcut tutorial is deferred to v2.

### Configuration

Miri owns separate configuration and process identities.
Valid setting changes apply immediately and persist.
Miri leaves standalone Paneru's configuration files untouched.
Configuration upgrades create a backup before migration and preserve user values.
If a migration cannot preserve those values, Miri leaves the file untouched and shows an error.

### Supported platforms

Initial validation targets Sam's Apple silicon Mac running macOS 27.0.
V1 provisionally supports macOS 27 and later.
Sam revisits the minimum version later, and older versions are added only after community testing.
Intel support is deferred unless Sam needs it.

### Multiple monitors

Multi-monitor support is required in v1.
Each physical monitor uses the same horizontal scrolling layout as the main display.
Each native macOS Space on a display has its own scrolling strip, following Paneru's model.
Window order, focus, and scroll position remain independent on each strip.
Native fullscreen windows stay unmanaged and return to their original column when they leave fullscreen, subject to hardware verification.
Trackpad scrolling moves the strip on the display under the pointer by default.
A setting lets the user choose the focused window's strip instead.
Keyboard commands always act on the focused strip.
Paneru's current trackpad behavior needs checking, and the setting may need an engine patch.
Paneru's experimental virtual workspaces stay turned off, with their commands and menu bar indicator hidden.
Sam dropped them on 1 November 2026, because macOS Spaces already give each display several strips.
The earlier reference to "vertically arranged" sets was accidental and does not request additional virtual workspace rows.

V1 supports horizontal, vertical, and mixed physical monitor arrangements that Sam can verify on real hardware.
Grid arrangements and the maximum display count are deferred to v2.

Sam's test Mac is a MacBook Air with an Apple M3 chip.
It drives the built-in display plus one external display, or two external displays with the lid closed.
It therefore shows at most two displays at once.
Sam can test with a 24-inch and a 27-inch monitor at university, and a 27-inch monitor and a 32-inch TV at home.
Horizontal and vertical arrangements are set in **System Settings > Displays**, so one physical desk setup can test both.
Disconnection tests include unplugging cables, closing and opening the lid, and sleep and wake cycles.
Mixed arrangements need three displays, so Sam verifies them last, on a friend's MacBook Pro that drives three displays.
The [v1 acceptance checklist](v1-acceptance-checklist.md) defines a quick check for everyday iteration and a release check for v1.
V1 is released only after Sam uses Miri daily for 2 weeks across both locations without a lost window or repeated crashes.
A bug that loses windows restarts the 2-week period.
How this period combines with the checklist's three consecutive full runs is Q6.
Sam decides Q6 at the final check before publishing v1.
Scrolling behavior remains consistent and independent across all connected displays.
Directional monitor navigation moves focus and windows between displays according to their physical positions.
Strip scrolling and ordinary window navigation stay within the current display.
Only the dedicated monitor navigation commands cross between displays.
Scrolling reliability keeps off-screen windows on their assigned displays without macOS relocating them.
These are distinct requirements.
Reliable horizontal multi-monitor scrolling is a v1 release blocker.
Reusing Paneru does not establish that this blocker is resolved.

### Display changes

Each strip stays on its display while that display is connected.
When a display disconnects, its strips follow their macOS Space to the display that macOS selects and keep their window order.
If Paneru cannot re-attach a strip, its windows become floating and remain reachable.
When the display reconnects, each window returns to the display it was on before the disconnect, in its old column order and stack.
This applies to unplugging and replugging a display, closing and opening the lid, and sleep and wake.
Windows that never left their display keep their place, including reordering done while the other display was gone.
A window opened while a display was gone stays on the display it was opened on, and a window closed meanwhile is forgotten.
Windows from several Spaces of one display return together to the Space that display shows.
Miri keeps this record in memory and offers no reconnection settings in v1.
This behavior requires verification on hardware, including sleep and wake cycles.
The decision is recorded in [ADR 0008](../docs/adr/0008-follow-macos-space-migration-for-display-changes.md).

## Strip gestures

Strip gestures support three fingers, four fingers, and Off.
Initial setup recommends four fingers but enables it only when the gesture is verified as usable without a macOS conflict.
Otherwise, strip gestures default to Off.
The scrolling strip follows finger movement by default, with a persistent setting to reverse its direction.
Five-finger strip gestures are deferred.
When a known conflicting macOS gesture is confirmed, Miri disables its conflicting strip gesture, preserves keyboard window management, and shows manual setup instructions.
Miri never modifies macOS settings automatically.
If gesture conflict detection is unavailable, Miri shows **Unable to verify** and offers a gesture test.
Consistent strip movement without unintended macOS actions, followed by explicit user confirmation, counts as **Verified by user test**.
This result does not claim that the underlying macOS gesture configuration was automatically verified.
Miri persists the gesture preference and provides an option to retest.
Known confirmed conflicts still prevent gesture enablement, and failed or inconclusive tests leave the gesture Off.
User-test results remain valid across ordinary restarts.
Changing the finger count or direction, upgrading macOS or the bundled engine, or detecting a relevant macOS gesture change invalidates the result.
A user-reported change to relevant macOS gestures also invalidates the result.
The gesture preference remains saved, but the gesture stays Off until another successful test and explicit user confirmation.
Keyboard window management continues while retesting is required.

### Settling after a swipe

Sam accepted this behavior on 19 October 2026.
When the fingers lift, the strip always settles on a column.
It lands on the column nearest the screen center at the point where the flick would naturally stop, counting momentum, and that column takes focus.
The strip then moves only as far as needed to show that column fully, as V1 interactions describes.
A settle never leaves empty space beside a strip that overflows the display, so a flick past either end lands with that end on the screen edge.
Landing on a stack focuses the window in that stack that was used last.
A strip that already fits the display slides a little with resistance, then springs back.
Modifier-scroll with a mouse wheel settles the same way after a short pause.
Settling is always on in v1 and has no setting.

## V1 interactions

V1 includes keyboard navigation, column resizing, window stacking, floating windows, and trackpad scrolling.
V1 uses clicking and macOS window switching to access floating windows instead of a dedicated floating-to-tiled focus shortcut.
Fixed-size windows and Miri's settings float automatically.
Picture-in-Picture windows float automatically, stay above ordinary windows, and take keyboard focus once when they open.
Miri treats any window that its app keeps above the normal window level as such a window, so it also floats an app's own always-on-top window.
A Picture-in-Picture window stays on the display where it opened and does not follow focus to another display, as Sam decided on 26 October 2026.
When a player window that entered Picture-in-Picture returns, it takes back its old size and place, or a visible place on the current display if its old workspace is not shown.
Known limitation: the macOS system Picture-in-Picture window, which Safari, QuickTime Player, and IINA use, cannot take keyboard focus.
It ignores the keyboard even when it is frontmost, so Miri leaves it alone, and macOS keeps it above other windows.
Only an app's own Picture-in-Picture window, such as Chrome's, takes keyboard focus when it opens.
When focus moves, the strip moves only as far as needed to show the focused column fully.
A partly hidden column ends with its edge on the screen edge, and a fully visible column does not move.
Keyboard focus and trackpad or modifier scrolling follow this rule, and the Centre column command still centers on demand.
Sam replaced the earlier rule, which centered the focused column whenever the strip overflowed, on 19 October 2026.
The layout reserves space for the visible macOS Dock without a separate v1 setting.
Miri respects macOS Reduce Motion and provides a setting to disable animation.
Either Reduce Motion or the disable-animation setting makes strip movement instant.
Numbered jumps select columns and focus the last-focused window within the selected column.
Moving the pointer alone does not change focus, and Miri keyboard commands do not move the pointer.
Clicks, keyboard commands, and macOS window switching still change focus.
Sam confirmed this rule in [issue #90](https://github.com/samanyudas/miri/issues/90).

Directional monitor focus uses Control-Option-Command with W, A, S, and D for up, left, down, and right.
Adding Shift moves the focused window in the corresponding monitor direction.
These bindings preserve the previously selected shortcuts and require verification against the engine and macOS.
Shortcut recording follows [Binding customization](keybinding%20reference.md#binding-customization).
Tabbed columns, the minimap, inactive-window dimming, and advanced window rules are deferred to v2.
Focus borders, pointer-following controls, display exclusions, fixed-pixel presets, animation tuning, and Hyper-key recording are also deferred to v2.
Deferral excludes these proposals from v1 without committing to their inclusion in v2.

Miri uses the GNU General Public License version 3 or any later version at the recipient's option.
The SPDX license identifier is `GPL-3.0-or-later`.

The feature, configuration, shortcut, and setup documents describe Miri's design decisions and proposals.
They do not establish that every listed feature is required for v1.

### Stacks

Sam accepted these stack rules on 19 October 2026.
When a window joins or leaves a stack, every window in that column gets an equal share of its height.
Heights set with the vertical resize shortcuts are kept until the stack's members change.
A window that refuses its share keeps the height it accepts, and the other windows share the rest.
While the windows fit, stacked windows never overlap.

Sam accepted the width rule for windows with size constraints on 25 October 2026 ([#93](https://github.com/samanyudas/miri/issues/93)).
A stacked window that cannot grow to the column's width keeps its own size, aligned with the column's left edge.
The column keeps the width of its wider members, and the space to the right of the narrow window stays empty, so the desktop or other content behind it shows through.
A window that cannot shrink to the column's width widens the column, so the next column never covers it.

Sam accepted the overflow rule on 20 October 2026 ([#42](https://github.com/samanyudas/miri/issues/42)).
When the stacked windows cannot shrink further, each lower window overlaps the window above it, but only below that window's top bar.
A top bar is the window's title bar, toolbar, or navigation bar, and every top bar stays visible.
Miri measures each top bar through Accessibility and uses 52 points when it cannot.
The stack extends past the bottom of the screen only when even the top bars do not fit.
The focused window comes to the front and shows its full content.
When focus leaves it, it returns to its overlapped place in the stack.
Miri draws no extra cue for an overlapped stack.

Known limitation: when Finder is frontmost with no window, the previously focused stack window can remain above its overlapped place.
The stack returns to its normal order when focus reaches another managed window.
Miri does not temporarily activate stack apps to restore the order while Finder has focus.

A stack holds a limited number of windows, and a Stack command that would exceed the limit starts a new column instead.
Settings chooses the limit: fit the display, which allows as many windows as fit in a column at the minimum window height, or a set number from 1 up to that.
The default is a set number of 5, and the limit in use never exceeds what fits on the display the stack is on.
There is no unlimited option, because a column cannot show more windows than fit at the minimum height ([#44](https://github.com/samanyudas/miri/issues/44)).
Lowering the limit leaves existing stacks unchanged, and the new limit applies to the next Stack command or drop.

### Dragging windows

Sam accepted these drag rules on 19 and 20 October 2026 ([#43](https://github.com/samanyudas/miri/issues/43)).
Dragging a tiled window by its title bar moves it in the layout, on the same display or on another display.
A drag moves only the window it grabs, and moving a whole stack stays a keyboard action.
Floating windows never join the layout by drag, and dragging only moves them.

The pointer picks the display, the column and its zone, and the drop height, so the target is always under the pointer.
Over the dragged window's own column, a drop only reorders its stack, so a window grabbed near either end of its title bar and dragged straight down stays in its stack.
To take a window out of its stack by drag, drop it over a neighboring column's near quarter or over empty space.
Sam accepted this rule on 1 November 2026 ([#203](https://github.com/samanyudas/miri/issues/203)).
It replaces the earlier rule from 25 October 2026, where the dragged window's centre picked the column ([#72](https://github.com/samanyudas/miri/issues/72)).

- A drop with the pointer over the middle half of a column moves the window into that column, between the two windows it is dropped between.
  A drop above the top window makes it the top window, and a drop at the bottom of the screen makes it the bottom window.
  A drop on a single-window column forms a stack, and a drop within the window's own stack reorders it.
  The window takes that column's width, and the stack shares its height equally.
- A drop with the pointer over the outer quarter of another column moves the window to a new column on that side.
- A drop with the pointer over empty space moves the window to a new column at the nearest end of that strip.
- A window that becomes a new column keeps its width relative to its display.
  It is never wider than the destination's tiling area, so a window that macOS filled fits the new display.

While dragging, a horizontal insertion line shows a drop into a column, and a vertical line shows a new column.
A drop into a stack at its limit, or past what the destination display fits, is refused.
Miri shows a not-allowed indicator, and the window returns to its place.
Holding the pointer near a display edge with no neighboring display for about half a second scrolls the strip.
Holding the pointer for about half a second over the visible part of a column that a display edge cuts off also scrolls the strip, on any edge, including one shared with another display.
That hold counts only within 200 points of the edge, and not over a column that holds the dragged window.
Either hold keeps scrolling one column about every 350 milliseconds while the pointer stays where the hold started.
Sam chose this on 1 November 2026, so a strip beside another display can still scroll during a drag ([#205](https://github.com/samanyudas/miri/issues/205)).
After a drop, the dropped window keeps focus, and the strip moves only as far as needed to show it.
If macOS tiles the window instead, the engine returns it to its place in the layout.

### Maximizing a window

Sam accepted the first rules on 25 October 2026 ([#88](https://github.com/samanyudas/miri/issues/88)).
On 26 October 2026, Sam replaced the model and the toggle ([#106](https://github.com/samanyudas/miri/issues/106)).

A maximized tiled window is a column as wide as the display, and the window fills the usable area of its display.
The usable area excludes the menu bar and the visible Dock.
No action creates a native full-screen Space.
The maximized column stays in its row, and its neighbors sit beside it off-screen, as with any wide column.
Focus moves to the left or right and strip swipes scroll past it as usual.
The maximized window slides away and back and stays maximized, and no neighbor shows on top of it.
This matches niri's `maximize-column`.

Control-Option-F and a double-click on a window's title bar, toolbar, or navigation bar are one toggle.
Each maximizes the window, or restores it when it is maximized.
Control-Option-F acts on the focused window, and the double-click acts on the clicked window.
There is no timer.
A double-click on a control in the top bar, such as a button, text field, or tab, stays the control's own.
The separate Make column full width action is no longer one of Miri's defaults or listed actions.
A configuration that binds `window_fullwidth` keeps working, because the engine reads it as the maximize toggle.

Restore returns the column to its width just before maximizing, and the window to its earlier height.
The neighbors keep their sizes.
On a floating window, both triggers fill the usable area over the layout.
A floating window returns to its earlier size, at the same offset from the top-left corner of the usable area, moved and shrunk as needed to stay on the display.

Maximizing a stacked window moves it out of its stack into a column of its own.
The **Maximized stacked window opens** setting chooses the side, **Left of its stack** or **Right of its stack**.
The default is the right side, and the engine key is `[options].maximized_window_side`.
The stack keeps its width, and focus commands reach it like any neighbor.
On restore, the window returns to its old position in the stack when a window from that stack is still in a column that is not maximized and has room.
Otherwise the window stays a column of its own, at the restored width.
Miri never closes or moves other windows to make room.

Width commands, which grow, shrink, step, or cycle preset widths, restore a maximized window first and then apply.
Stack and unstack commands also restore it first, where it stands, and then apply.
Making a maximized window float restores it first, so it floats at its earlier size.
Dragging the edge of a maximized window with the pointer ends maximization and keeps the new width.
Equalize and balance leave a maximized column alone.
A new window opens beside a maximized window as usual, and the maximized window stays maximized.
A title-bar drag within the window's display works like any tiled drag.
It shows the drop line and reorders the row, and the window stays maximized at its new place.
A drop into a stack restores the window first and then joins that stack.
A window dropped onto a maximized column restores that column first.

A display move does not cancel maximization ([#87](https://github.com/samanyudas/miri/issues/87)).
A maximized window that a display command moves, or that a title-bar drag drops on another display, fills that display's usable area.
The display under the pointer at the drop is the destination.
Its place in the layout moves with it.
A display command puts it at the end of the destination's strip.
While a drag is over another display, Miri shows the same drop line as for any tiled window, and the drop puts the window there.
A floating maximized window has no place in a layout, so a drag shows no line.

The saved session records, for each maximized window, that it is maximized, its width before maximizing, and the stack it came from.
After an engine restart or a session restore, the window fills its display's usable area again, and a later restore works as usual.
A window that comes back on another display fills that display.

macOS also runs its own double-click action, such as Zoom.
For one second after each toggle, Miri puts the window back at the frame the toggle gave it, so that action does not change the result.

Known limitations:

- A window with a maximum size grows only to that size, at the top-left corner of the usable area.
- Chromium-based browsers can hide their tabs from Accessibility.
  In such a browser, a double-click on a tab also maximizes the window.

## V2

V2 contains further quality-of-life improvements.
V2 includes an optional custom Miri dock that can be enabled or disabled.
The Miri dock is enabled by default.
The Miri dock dims when inactive-window dimming is enabled and shows multiple app icons for a stack containing windows from multiple apps.
The [Miri dock plan](v2-roadmap.md#miri-dock) defines column entries, same-app window-count badges, and a window-title picker for individual window selection.
The [v2 roadmap](v2-roadmap.md) records deferred work and candidate improvements separately.

## System access

Miri requires Accessibility permission and keeps SIP enabled.
Screen Recording permission is needed only for the opt-in **Show window contents on edges next to another display** switch in Settings > Layout, which is off by default.
With that switch on, the engine photographs the whole of each window that is hidden behind or crossing an edge next to another display, and shows the photo only where the real window cannot show.
With it off, Miri does not capture the screen.
Undocumented APIs require individual compatibility assessments and defined fallback behavior.
The accepted boundary is recorded in [ADR 0002](../docs/adr/0002-limit-system-access.md).
