# Keybinding reference

Status: accepted as Miri's default bindings on 14 October 2026.
Actions this reference does not cover use Paneru's defaults, changed only where they clash with macOS.

These bindings define Miri's default set for new installations.
Miri writes them to `[bindings]` from one table in `Sources/MiriCore/Bindings.swift`.
On 16 October 2026 a live run on macOS 27 against engine `39def42` sent each bound shortcut as a synthetic key event, and each one performed its engine command.
Some actions have no engine command or differ from the accepted behavior, as [Engine mapping](#engine-mapping) records.

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
Directional monitor bindings preserve the previously selected shortcuts.
The pinned engine has no directional monitor commands, so Miri leaves these eight shortcuts unbound for now.

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

This table maps each accepted action to the command that the pinned engine `39def42` runs.
A blank engine command means that Miri leaves the action unbound.
Any action not listed here maps directly, and the live run confirmed it.

| Action | Engine command | Difference from the accepted behavior |
| --- | --- | --- |
| Focus window above or below within column | `window_focus_north`, `window_focus_south` | At the top or bottom of a column, focus moves to a display above or below. |
| Move window up or down within column | `window_swap_north`, `window_swap_south` | At the top or bottom of a column, the window moves to the next display. |
| Focus first or last column | `window_focus_first`, `window_focus_last` | In a stack, the top window gets focus, not the last-focused window. |
| Jump to column 1 through 9 | `window_focus_1` through `window_focus_9` | The engine counts columns, as accepted. In a stack, the top window gets focus, not the last-focused window. |
| Make column wider or narrower | `window_grow`, `window_shrink` | The width moves to the next preset instead of five percentage points, and it wraps around at the last preset. |
| Make window taller or shorter | `window_vertical_grow`, `window_vertical_shrink` | The height moves to the next stack-height preset instead of five percentage points, and it wraps around. It changes only windows in a stack. |
| Centre column | `window_center` | The engine also moves the pointer to the centre of the display. |
| Focus monitor above, left, below, or right | | The engine has no directional display focus command. |
| Move focused window to monitor above, left, below, or right | | The engine has no directional display move command. |
| Stop window manager | | The engine `quit` command ends the engine, and the app treats that exit as a crash and restarts the engine. Stop must be an app action. |
| Toggle column between stacked and tabbed | | This action is deferred to v2. |

## Binding customization

Provide a shortcut recorder and allow several bindings per action.
Respect AZERTY, QWERTZ, and Dvorak layouts.
Recording Hyper-key combinations created with tools such as Karabiner-Elements is deferred to v2.
Reject a recorded shortcut already assigned to a different Miri action.
Warn about known macOS shortcut conflicts.
Never silently replace another binding when recording a shortcut.

Preserve user bindings on upgrade.
Add new defaults only where the keys are free.
Offer an explicit action to switch to the current default set.

## Actions without selected bindings

This default set does not assign bindings for cycling presets backward, expanding to available width, centering all visible columns, or pulling a neighboring window into the focused column.
Actions not covered here use Paneru's defaults, changed only where they clash with macOS.

V1 has no dedicated binding to switch focus between floating and tiled windows.
Users can click a window or use macOS app and window switching.
