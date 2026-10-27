# Keybinding reference

Status: accepted as Miri's default bindings on 14 October 2026.
Actions this reference does not cover use Paneru's defaults, changed only where they clash with macOS.

These bindings define Miri's default set for new installations.
Miri writes them to `[bindings]` from one table in `Sources/MiriCore/Bindings.swift`.
On 16 October 2026 a live run on macOS 27 against engine `39def42` sent each bound shortcut as a synthetic key event, and each one ran its engine command.
Engine `3455e37` adds the commands that run was missing: five-point resize steps, directional display focus and move, and column jumps that return to a stack's last-focused window.
Stop window manager is Miri's own shortcut, not an engine binding.
The remaining differences from the accepted behavior are in [Engine mapping](#engine-mapping).

## Modifier keys

| Symbol | Key |
| --- | --- |
| ⌃ | Control |
| ⌥ | Option |
| ⇧ | Shift |
| ⌘ | Command |

Control-Option leaves ordinary Option typing and Command app commands available.
Every directional action accepts the arrow keys, Vim keys, and W, A, S, and D, with the same modifiers.
Left uses Left Arrow, H, or A.
Down uses Down Arrow, J, or S.
Up uses Up Arrow, K, or W.
Right uses Right Arrow, L, or D.
No default shortcut needs the Fn key.
Sam chose this rule in [issue #79](https://github.com/samanyudas/miri/issues/79).

## Navigation and movement

| Action | Default shortcut | Alternatives |
| --- | --- | --- |
| Focus column left | ⌃⌥← | ⌃⌥H, ⌃⌥A |
| Focus column right | ⌃⌥→ | ⌃⌥L, ⌃⌥D |
| Focus window above within column | ⌃⌥↑ | ⌃⌥K, ⌃⌥W |
| Focus window below within column | ⌃⌥↓ | ⌃⌥J, ⌃⌥S |
| Focus first column or monitor left | ⌃⌥⌘← | ⌃⌥⌘H, ⌃⌥⌘A |
| Focus last column or monitor right | ⌃⌥⌘→ | ⌃⌥⌘L, ⌃⌥⌘D |
| Focus monitor above | ⌃⌥⌘↑ | ⌃⌥⌘K, ⌃⌥⌘W |
| Focus monitor below | ⌃⌥⌘↓ | ⌃⌥⌘J, ⌃⌥⌘S |
| Jump to column 1 through 9 | ⌃⌥1 through ⌃⌥9 | |
| Move column left | ⌃⌥⇧← | ⌃⌥⇧H, ⌃⌥⇧A |
| Move column right | ⌃⌥⇧→ | ⌃⌥⇧L, ⌃⌥⇧D |
| Move window up within column | ⌃⌥⇧↑ | ⌃⌥⇧K, ⌃⌥⇧W |
| Move window down within column | ⌃⌥⇧↓ | ⌃⌥⇧J, ⌃⌥⇧S |
| Move column to first position or monitor left | ⌃⌥⌘⇧← | ⌃⌥⌘⇧H, ⌃⌥⌘⇧A |
| Move column to last position or monitor right | ⌃⌥⌘⇧→ | ⌃⌥⌘⇧L, ⌃⌥⌘⇧D |
| Move column to monitor above | ⌃⌥⌘⇧↑ | ⌃⌥⌘⇧K, ⌃⌥⌘⇧W |
| Move column to monitor below | ⌃⌥⌘⇧↓ | ⌃⌥⌘⇧J, ⌃⌥⌘⇧S |
| Send column to next display | ⌃⌥N | |
| Stop window manager | ⌃⌥Q | |

These actions have no default shortcut, and Settings lists them for custom shortcuts:

- Focus first column, and Focus last column.
- Move column to first position, and Move column to last position.
- Focus monitor left, and Focus monitor right.
- Move column to monitor left, and Move column to monitor right.

Numbered jumps select columns rather than individual windows.
Within a stack, the selected column's last-focused window receives focus.

Focus first column or monitor left focuses the current display's first column.
When that column already has focus, the same shortcut focuses the display to the left.
Focus last column or monitor right does the same toward the last column and the display to the right.
Focus monitor above and Focus monitor below focus the neighboring display at once.
A focused display gives focus to its last-focused visible window, otherwise to its most visible window.
These focus commands move no windows, switch no native desktops, and leave the pointer where it is.

Move column to first position or monitor left moves the focused column to the current display's first position.
When the column is already first, the same shortcut moves it to the display to the left.
Move column to last position or monitor right does the same toward the last position and the display to the right.
Move column to monitor above, Move column to monitor below, and Send column to next display move the column at once.
Every display move takes the whole column, so each stack member moves with it in the same order, and the focused member keeps focus.
To move one member alone, pop it out into its own column first.
The arriving column goes immediately after the destination's active column, which is the column a display focus would select there.
With destination columns X, Y, and Z and Y active, moving column S there gives X, Y, S, Z.
An empty destination receives the column as its first column.
When no display lies in the requested direction, the shortcut does nothing, so a column or focus stays at the current display's end.

Display directions follow the physical arrangement in **System Settings > Displays**.
Focus and movement within a column stay on the current display at the column's top or bottom edge.
Only the monitor shortcuts, the edge-or-monitor shortcuts at a display's end, and ⌃⌥N cross to another display.
[Release scope](release-scope.md#multiple-monitors) requires this split, which settles the question in miri#23.
Stop window manager runs the same Stop as the menu bar, and Miri registers it itself.
Its shortcuts are customizable and live in `[miri].stop_shortcut`, as one chord string or an array of chord strings in the engine's syntax.
An absent key means ⌃⌥Q, and an empty array means Stop has no shortcut.
If the engine can load `[bindings]` and an accepted shortcut assigns a Stop chord to an engine command, that binding wins.
Miri then leaves that chord out of Stop.
If the engine rejects the binding section, or `[miri].stop_shortcut` is invalid, Miri keeps the previous Stop shortcuts.

## Width, height, and centering

| Action | Default shortcut |
| --- | --- |
| Cycle preset widths forward | ⌃⌥R |
| Maximize or restore window | ⌃⌥F |
| Centre column | ⌃⌥C |
| Make column wider | ⌃⌥= |
| Make column narrower | ⌃⌥- |
| Make window taller | ⌃⌥⇧= |
| Make window shorter | ⌃⌥⇧- |
| Equalize window heights within column | ⌃⌥0 |

A width change grows or shrinks the column around its own center.
The column shifts inward only when it would leave the display.
Within one run of width changes, Miri remembers where the column started, so returning to the original width returns it to the same place.
That memory ends when focus or the strip moves.
Sam accepted this behavior on 19 October 2026.

Maximize or restore window is the same toggle as a double-click on the window's title bar.
A maximized window is a column as wide as the display, and focus moves scroll past it.
It never creates a native full-screen Space.
[Maximizing a window](release-scope.md#maximizing-a-window) records the rules.
The width and height adjustment increment follows [Default shortcuts and layout](release-scope.md#default-shortcuts-and-layout).

## Stacks, tabs, and floating

| Action | Default shortcut |
| --- | --- |
| Stack focused window into left column | ⌃⌥[ |
| Stack focused window into right column | ⌃⌥] |
| Pop focused window out to right | ⌃⌥⇧] |
| Pop focused window out to left | ⌃⌥⇧[ |
| Toggle column between stacked and tabbed, v2 only | ⌃⌥⇧T |
| Float or unfloat focused window | ⌃⌥T |

An opening bracket `[` means left and a closing bracket `]` means right, for both stacking and popping out.
Sam chose this rule in [issue #92](https://github.com/samanyudas/miri/issues/92), which reversed the earlier join defaults.
Stacking moves only the focused window into the neighboring column, and the rest of its old stack stays in place.
In the first or last column, stacking toward the edge does nothing.

## macOS commands used alongside the app

These commands belong to macOS or the active application.

| Action | Command |
| --- | --- |
| Switch to adjacent Space | ⌃← or ⌃→ |
| Switch to numbered desktop | ⌃1 through ⌃9, after enabling Mission Control bindings |
| Open Mission Control | ⌃↑ or configured upward swipe |
| Move window to another Space | Drag window in Mission Control |
| Close window | ⌘W or red close button |
| Quit active application | ⌘Q |
| Toggle native fullscreen | ⌃⌘F, where supported by the active app |
| Switch application | ⌘Tab |
| Switch windows within application | ⌘` |
| Open Spotlight | ⌘Space |
| Lock screen | ⌃⌘Q |

Launch apps through the Dock, Spotlight, Raycast, or Alfred.
V1 requires directional monitor navigation for focus and window movement, as recorded in [Release scope](release-scope.md).
The directional monitor bindings appear in the navigation table above.
Clicking a window on another display also changes focus.

## Engine mapping

This table maps each accepted action to the command that the pinned engine `0d023e2` runs.
The mapping describes commands and their expected behavior.
[PROGRESS.md](../PROGRESS.md) records runtime and hardware checks.
A blank engine command means that Miri leaves the action unbound.
Any action not listed here maps directly, and the live run confirmed it.

| Action | Engine command | Difference from the accepted behavior |
| --- | --- | --- |
| Focus first or last column, Jump to column 1 through 9 | `window_focus_first`, `window_focus_last`, `window_focus_1` through `window_focus_9` | None. The engine counts columns, and in a stack it focuses the window that last had focus in that column. |
| Focus first column or monitor left, Focus last column or monitor right | `window_focusedge_west`, `window_focusedge_east` | None. |
| Move column to first position or monitor left, Move column to last position or monitor right | `window_moveedge_west`, `window_moveedge_east` | None. |
| Cycle preset widths forward | `window_resize` | None. |
| Make column wider or narrower | `window_step_grow`, `window_step_shrink` | None. Each press changes the width by `window_resize_step` of the display, 0.05 by default, and stops at full width without wrapping. |
| Make window taller or shorter | `window_vertical_step_grow`, `window_vertical_step_shrink` | The height changes only for a window in a stack, because a column's only window always fills the display height. The neighbouring window absorbs the change and keeps a layout slot of at least 200 points, including the gap. With the default 8-point gap, the native window keeps at least 192 points, subject to its own minimum height. |
| Centre column | `window_center` | None. The pointer stays where it is. |
| Maximize or restore window | `window_maximize` | None. `window_fullwidth` is the engine's older name for the same command, so a file that binds it keeps working, and Settings lists it under this action. |
| Focus monitor above, left, below, or right | `window_focusdisplay_north`, `_west`, `_south`, `_east` | None. Focus goes to the display's last-focused window when it is visible, otherwise to its most visible window. A display with no visible window gets its desktop focused, so its menu bar becomes active and shows Finder. The pointer stays where it is. |
| Move column to monitor above, left, below, or right | `window_movedisplay_north`, `_west`, `_south`, `_east` | None. Focus follows the column. |
| Send column to next display | `window_nextdisplay` | None. Focus follows the column. |
| Stop window manager | | Miri's own shortcut, because the engine `quit` command ends the engine, and the app treats that exit as a crash and restarts it. |
| Toggle column between stacked and tabbed | | This action is deferred to v2. |

Miri version 2 of the default set replaced the version 1 bindings `window_grow`, `window_shrink`, `window_vertical_grow`, and `window_vertical_shrink`.
On upgrade from a recorded version 1, Miri removes each of those four only while it still has the exact value Miri wrote, and then adds the step command.
An unversioned file keeps its existing bindings, even when they match a retired default.
A binding the user changed stays, and the step command gets only its free chords.
A version 1 resize binding that the user deleted stays unbound after the upgrade.

Version 3 of the default set moves Stack focused window into left column from ⌃⌥] to ⌃⌥[, and Stack focused window into right column from ⌃⌥[ to ⌃⌥].
On upgrade from a recorded version 1 or 2, Miri moves each of the two only while it still has the exact value Miri wrote and its new chord is free.
When another binding holds the new chord, the action keeps its old chord, so no chord gets two actions.
While a join binding has its old default value and another binding holds its new chord, the Shortcuts settings page reports which action kept its old chord and which action holds the new one.
A join binding that the user changed or deleted stays as it is.
An unversioned file and a `[bindings]` table in a form Miri does not rewrite keep their join bindings until the user resets the shortcuts.
The engine adds no bracket bindings of its own, because its default configuration has an empty `[bindings]` table.

Version 4 of the default set gives every directional action its arrow, Vim, and W, A, S, and D chords ([#79](https://github.com/samanyudas/miri/issues/79)).
It retires the defaults of Focus first column, Focus last column, Move column to first position, Move column to last position, Focus monitor left, Focus monitor right, Move column to monitor left, and Move column to monitor right.
The four edge-or-monitor actions take over their chords.
On upgrade from a recorded version 1, 2, or 3, Miri removes each retired default only while it still has the exact value Miri wrote.
It adds the new chords to a directional binding only while that binding still has the exact value Miri wrote and every new chord is free.
It then adds each edge-or-monitor action with its free chords.
When the user deleted every retired default that an edge-or-monitor action replaces, that action stays unbound.
A binding the user changed stays as it is.
When another binding holds a chord that version 4 would add, that binding keeps the chord, and the Shortcuts settings page reports which action lacks it and which action holds it.
An unversioned file keeps its bindings, gains no new chords on existing actions, and gains no edge-or-monitor action while it binds an action that one replaces.
A `[bindings]` table in a form Miri does not rewrite stays unchanged.
Reset to Defaults writes the version 4 set in every case.

Before [#106](https://github.com/samanyudas/miri/issues/106), the default for ⌃⌥F was `window_fullwidth`, which made a full-width column with gaps.
Miri now writes `window_maximize` for a new file or a reset to defaults.
An existing `window_fullwidth` binding stays as it is, because the engine reads it as `window_maximize`.
Miri adds no second binding for the action.

## Binding customization

Provide a shortcut recorder and allow several bindings per action.
Respect AZERTY, QWERTZ, and Dvorak layouts.
Recording Hyper-key combinations created with tools such as Karabiner-Elements is deferred to v2.
Reject a recorded shortcut already assigned to a different Miri action.
Warn about known macOS shortcut conflicts.
Never silently replace another binding when recording a shortcut.

Preserve user bindings on upgrade.
Add a new default only when the file does not already bind its engine command under any spelling the engine accepts.
For example, a user binding for `window_resize` also counts as a binding for `window_grow`.
Add each of the default's chords that is free, and skip the chords another binding already uses.
For example, if the user assigned ⌃⌥H to another action, Focus column left still gets ⌃⌥←.
Leave `[bindings]` unchanged when the file defines it in a form Miri does not rewrite, such as an inline table.
Offer an explicit action to switch to the current default set.

## Actions without selected bindings

This default set does not assign bindings for cycling presets backward, expanding to available width, centering all visible columns, or pulling a neighboring window into the focused column.
Actions not covered here use Paneru's defaults, changed only where they clash with macOS.

V1 has no dedicated binding to switch focus between floating and tiled windows.
Users can click a window or use macOS app and window switching.
