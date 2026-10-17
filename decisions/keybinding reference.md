# Keybinding reference

Status: accepted as Miri's default bindings on 14 October 2026.
Actions this reference does not cover use Paneru's defaults, changed only where they clash with macOS.

These bindings define Miri's default set for new installations.
Miri writes them to `[bindings]` from one table in `Sources/MiriCore/Bindings.swift`.
On 16 October 2026 a live run on macOS 27 against engine `39def42` sent each bound shortcut as a synthetic key event, and each one ran its engine command.
Engine `0010611` adds the commands that run was missing: five-point resize steps, directional display focus and move, and column jumps that return to a stack's last-focused window.
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
Strip navigation and movement accept both arrow keys and Vim keys.
Directional monitor commands use W, A, S, and D.

## Navigation and movement

| Action | Default shortcut | Alternative |
| --- | --- | --- |
| Focus column left | ⌃⌥← | ⌃⌥H |
| Focus column right | ⌃⌥→ | ⌃⌥L |
| Focus window above within column | ⌃⌥↑ | ⌃⌥K |
| Focus window below within column | ⌃⌥↓ | ⌃⌥J |
| Focus first column | ⌃⌥⌘← | |
| Focus last column | ⌃⌥⌘→ | |
| Jump to column 1 through 9 | ⌃⌥1 through ⌃⌥9 | |
| Move column left | ⌃⌥⇧← | ⌃⌥⇧H |
| Move column right | ⌃⌥⇧→ | ⌃⌥⇧L |
| Move window up within column | ⌃⌥⇧↑ | ⌃⌥⇧K |
| Move window down within column | ⌃⌥⇧↓ | ⌃⌥⇧J |
| Move column to first position | ⌃⌥⌘⇧← | |
| Move column to last position | ⌃⌥⌘⇧→ | |
| Send focused window to next display | ⌃⌥N | |
| Focus monitor above | ⌃⌥⌘W | |
| Focus monitor left | ⌃⌥⌘A | |
| Focus monitor below | ⌃⌥⌘S | |
| Focus monitor right | ⌃⌥⌘D | |
| Move focused window to monitor above | ⌃⌥⌘⇧W | |
| Move focused window to monitor left | ⌃⌥⌘⇧A | |
| Move focused window to monitor below | ⌃⌥⌘⇧S | |
| Move focused window to monitor right | ⌃⌥⌘⇧D | |
| Stop window manager | ⌃⌥Q | |

Numbered jumps select columns rather than individual windows.
Within a stack, the selected column's last-focused window receives focus.
The W, A, S, and D monitor shortcuts keep the choice made in an earlier design round.
They choose the display that lies in that direction in the physical arrangement in **System Settings > Displays**.
Focus and movement within a column stay on the current display at the column's top or bottom edge.
Only the W, A, S, and D monitor shortcuts and ⌃⌥N cross to another display.
[Release scope](release-scope.md#multiple-monitors) requires this split, which settles the question in miri#23.
Stop window manager runs the same Stop as the menu bar, and Miri registers it itself.
If `[bindings]` assigns ⌃⌥Q to an engine command, that binding wins and Miri leaves Stop without a shortcut.

## Width, height, and centering

| Action | Default shortcut |
| --- | --- |
| Cycle preset widths forward | ⌃⌥R |
| Make column full width | ⌃⌥F |
| Centre column | ⌃⌥C |
| Make column wider | ⌃⌥= |
| Make column narrower | ⌃⌥- |
| Make window taller | ⌃⌥⇧= |
| Make window shorter | ⌃⌥⇧- |
| Equalize window heights within column | ⌃⌥0 |

Full column width is separate from native macOS fullscreen.
The width and height adjustment increment follows [Default shortcuts and layout](release-scope.md#default-shortcuts-and-layout).

## Stacks, tabs, and floating

| Action | Default shortcut |
| --- | --- |
| Stack focused window into left column | ⌃⌥] |
| Stack focused window into right column | ⌃⌥[ |
| Pop focused window out to right | ⌃⌥⇧] |
| Pop focused window out to left | ⌃⌥⇧[ |
| Toggle column between stacked and tabbed, v2 only | ⌃⌥⇧T |
| Float or unfloat focused window | ⌃⌥T |

Miri assigns `]` to stacking left and `[` to stacking right.
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

This table maps each accepted action to the command that the pinned engine `0010611` runs.
A blank engine command means that Miri leaves the action unbound.
Any action not listed here maps directly, and the live run confirmed it.

| Action | Engine command | Difference from the accepted behavior |
| --- | --- | --- |
| Focus first or last column, Jump to column 1 through 9 | `window_focus_first`, `window_focus_last`, `window_focus_1` through `window_focus_9` | None. The engine counts columns, and in a stack it focuses the window that last had focus in that column. |
| Cycle preset widths forward | `window_resize` | None. |
| Make column wider or narrower | `window_step_grow`, `window_step_shrink` | None. Each press changes the width by `window_resize_step` of the display, 0.05 by default, and stops at full width without wrapping. |
| Make window taller or shorter | `window_vertical_step_grow`, `window_vertical_step_shrink` | The height changes only for a window in a stack, because a column's only window always fills the display height. The neighbouring window absorbs the change and keeps at least 200 points. |
| Centre column | `window_center` | The engine also moves the pointer to the centre of the display. |
| Focus monitor above, left, below, or right | `window_focusdisplay_north`, `_west`, `_south`, `_east` | None. Focus goes to the display's last-focused window when it is visible, otherwise to its most visible window. |
| Move focused window to monitor above, left, below, or right | `window_movedisplay_north`, `_west`, `_south`, `_east` | None. Focus follows the window. |
| Stop window manager | | Miri's own shortcut, because the engine `quit` command ends the engine, and the app treats that exit as a crash and restarts it. |
| Toggle column between stacked and tabbed | | This action is deferred to v2. |

Miri version 2 of the default set replaced the version 1 bindings `window_grow`, `window_shrink`, `window_vertical_grow`, and `window_vertical_shrink`.
On upgrade from a recorded version 1, Miri removes each of those four only while it still has the exact value Miri wrote, and then adds the step command.
An unversioned file keeps its existing bindings, even when they match a retired default.
A binding the user changed stays, and the step command gets only its free chords.

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
