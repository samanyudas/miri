# Features and shortcuts

Status: Miri product proposals, with accepted release boundaries recorded separately.

The [release scope](release-scope.md) records accepted v1 and v2 boundaries.
Features described below do not establish a complete v1 commitment.
Miri's native app interface is designed and built from the ground up for this project.
The app bundles a pinned Paneru-based engine.
Implementation and test status lives in [PROGRESS.md](../PROGRESS.md), not in this document.

## Use a horizontal strip of columns

Keep windows side by side on a strip that extends beyond the display.
Opening a new window inserts it beside the focused window.
Existing windows retain their widths.

Give each managed display and each macOS Space its own strip.
Keep column order, widths, stacks, focus, and scroll position independent between displays.
Restore column order, widths, and stacks after restarting.

Keep scrolled windows on their assigned displays without macOS relocating them.
Verify the edge-handling mechanism on real hardware before selecting an implementation.
See [Display arrangement and edge behavior](setup.md#arrange-and-select-displays).

When focus changes, scroll far enough to reveal the focused window.
Automatic centering follows [V1 interactions](release-scope.md#v1-interactions).
Alternative automatic centering modes remain proposals.

This layout preserves useful window sizes as more apps open.
It also makes the horizontal order of windows predictable.

## Support stacks, tabs, and floating windows

Allow several windows to share a column as a vertical stack.
Users can move a window into either neighboring column, reorder windows vertically, adjust heights, and pop a window into a separate column.

Tabbed columns are deferred to v2.
The proposed tabbed mode gives the selected window the column's full height and identifies the other windows in a tab bar.

Allow users to float or unfloat a window.
Automatic floating and access to floating windows follow [V1 interactions](release-scope.md#v1-interactions).
Advanced per-app rules for floating and strip placement are deferred to v2.

## Support keyboard, trackpad, and mouse input

Use Control-Option as the default keyboard modifier.
Support both arrow keys and Vim keys.
Add Shift to directional bindings to move windows rather than change focus.

Let users record new shortcuts and assign multiple bindings to an action.
Preserve existing shortcuts during upgrades.
Handle recording conflicts as described in [Binding customization](keybinding%20reference.md#binding-customization).
Support non-US keyboard layouts.

Horizontal strip gestures follow [Strip gestures](release-scope.md#strip-gestures).
The strip follows the fingers and settles at the nearest column on release.

Clicking a window changes focus.
Dragging a window into a stack follows [Stacks](release-scope.md#stacks).
Dragging to reorder columns is deferred to v2.
Dragging a window between displays is deferred to v2.

Focus follows mouse and mouse follows keyboard focus are deferred to v2.
Their proposed defaults are both off.

The selected default bindings are in [Keybinding reference](keybinding%20reference.md).
Directional monitor navigation is required in v1, with accepted bindings in the keybinding reference.

## Provide visual feedback and layout controls

The minimap and inactive-window dimming are deferred to v2.
The proposed minimap shows the current position while users navigate, then fades out.
The fade delay and duration remain unresolved.
A focus border is deferred to v2.

V2 includes an optional custom Miri dock that can be enabled or disabled.
The Miri dock is enabled by default.
The Miri dock dims when inactive-window dimming is enabled.
A stack containing windows from multiple apps shows multiple app icons in its dock entry.
The [Miri dock plan](v2-roadmap.md#miri-dock) defines column entries, same-app window-count badges, and a window-title picker for individual window selection.

Offer configurable width presets, full column width, width adjustments, height adjustments, and equal heights within a stack.
Reserve Dock space as described in [V1 interactions](release-scope.md#v1-interactions).
Allow separate gaps between windows and at display edges, including zero gaps.

Use a spring animation for strip motion that starts as soon as a navigation key is pressed.
Synchronize animation with the display refresh rate.
Duration and damping controls are deferred to v2.
Follow the Reduce Motion and disable-animation behavior in [V1 interactions](release-scope.md#v1-interactions).

Apply valid settings as users change them.
Provide the controls in a native settings window.
Migrate configuration as described in [Release scope](release-scope.md#configuration).

## Respect macOS window behavior

Avoid taking focus or scrolling the strip when a background app opens a window.
Leave native fullscreen windows unmanaged.
Verify their return to the original column when they leave fullscreen.

Excluding individual displays from management is deferred to v2.
V1 starts management after Accessibility permission is granted, unless the user left Miri stopped.
Launch at login is offered and enabled by default.

Use macOS Accessibility permission to move other apps' windows.

## Keep the interface native and the engine responsive

Build Miri's app interface with SwiftUI and AppKit where needed.
Provide native settings controls so ordinary setup does not require file editing.

Run the Paneru-based engine as a separate helper process inside `Miri.app`.
Handle shortcuts in the engine so navigation does not wait for the settings interface.
Keep the engine idle between events, such as window changes and shortcut input.
Active gestures and animations still require updates until they settle.

Settings visibility, Stop, Quit, and window recovery follow [App controls and window recovery](release-scope.md#app-controls-and-window-recovery).

## Provide signing and privacy guarantees

Sign the distributed app with a Developer ID and notarize it with Apple.
Require only Accessibility permission for window management.
Avoid kernel extensions, system modifications, and SIP changes.

Keep window management local to the Mac.
Require no account and collect no app telemetry.
Do not capture or read screen contents, or transmit window-management data.
Sparkle provides the app's update mechanism as recorded in [Release scope](release-scope.md).

Preserve Paneru's required copyright and MIT license notices alongside Miri's GPL-3.0-or-later license.

## Expose app controls and automation

Provide menu bar controls and an app icon in the macOS Dock that open Miri's settings.
Provide start, stop, restart, update, and diagnostic controls.

V1 includes a setup checker and access to the engine log.
Unavailable checks follow [Conflicts and setup checker](release-scope.md#conflicts-and-setup-checker).
Diagnostics follow [Privacy and diagnostics](release-scope.md#privacy-and-diagnostics).
Miri restarts the engine after an isolated crash.
Three crashes within five minutes stop automatic retries and expose a manual restart control.

The guided shortcut tutorial is deferred to v2.
Choose the shortcuts it teaches when designing that tutorial.

A CLI, a URL scheme, and Raycast commands remain v2 automation candidates.
Their syntax and supported actions remain unresolved.

## Open decisions

- Define tab-bar click behavior and drag behavior for v2.
- Select and verify the display-edge handling mechanism on real hardware.
- Choose the shortcuts taught on first run and the minimap fade timing for v2.
- Define Miri's automation interface before implementation.
- Verify animation, focus, gesture, and window-rule behavior in Miri before treating proposals as tested behavior.
