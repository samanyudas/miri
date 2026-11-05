# Focus a window with a shortcut

A shortcut moves keyboard focus to the next column left or right in the strip, or to the window above or below in a stacked column.
The engine scrolls the strip so the focused column shows, and macOS makes that window's app frontmost.

## Sub-features

- `focus-west`: ⌃⌥← (also ⌃⌥H and ⌃⌥A) focuses the column to the left.
- `focus-east`: ⌃⌥→ (also ⌃⌥L and ⌃⌥D) focuses the column to the right.
- `focus-north`, `focus-south`: ⌃⌥↑ and ⌃⌥↓ (also ⌃⌥K and ⌃⌥J, ⌃⌥W and ⌃⌥S) focus the window above or below in a stacked column.
- `focus-display`: ⌃⌥⌘← and ⌃⌥⌘→ (also ⌃⌥⌘H and ⌃⌥⌘L, ⌃⌥⌘A and ⌃⌥⌘D) focus the monitor on that side from any column in the strip.
  ⌃⌥⌘↑ and ⌃⌥⌘↓ (also ⌃⌥⌘K and ⌃⌥⌘J, ⌃⌥⌘W and ⌃⌥⌘S) focus the monitor above or below.
  Each lands on the window last focused on that monitor.
- `focus-edge`: Focus first column or monitor left and Focus last column or monitor right remain in Settings with no default shortcut.
- `focus-number`: ⌃⌥1 to ⌃⌥9 (`Jump to column N`) focus a column by its position, on the window last focused in that column.

## How to get to it (user POV)

- Press the chord on the keyboard while any app is in front.
- Change the chords in Settings > Shortcuts, or in `[bindings]` of `config.toml`.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md).
- `config.toml` binds `window_focus_west` to `ctrl+alt-leftarrow` and `window_focus_east` to `ctrl+alt-rightarrow`.

- **Open two columns.** Run `V fixture --count 2`. The log shows `fixture-1` and `fixture-2` with window IDs and `the engine manages it`. The engine places `fixture-2` in a new column to the right of `fixture-1` and focuses it.
- **Record the start.** Run `V snapshot 1-before`. The log shows `engine focus fixture-2, macOS frontmost fixture-2`. In the JSON, both fixtures have `"floating": false`, and `fixture-1`'s `x` is smaller.
- **Focus left.** Run `V key ctrl+alt-leftarrow`, then `V focused --wait-for fixture-1`. The command exits 0.
- **Record it.** Run `V snapshot 2-after-left`. The log shows `engine focus fixture-1, macOS frontmost fixture-1`. `2-after-left-fixture-1.png` shows colored window buttons, and `2-after-left-fixture-2.png` shows grey ones.
- **Focus right.** Run `V key ctrl+alt-rightarrow`, `V focused --wait-for fixture-2`, and `V snapshot 3-after-right`. Focus is back on `fixture-2` in both views.
- **Letter chords.** Run `V key ctrl+alt-h`, `V focused --wait-for fixture-1`, then `V key ctrl+alt-l`, `V focused --wait-for fixture-2`. Do the same with `ctrl+alt-a` and `ctrl+alt-d`. Each exits 0, as for the arrows.
- **Column number.** Read `fixture-1`'s position in the active strip from `V query state`, where `virtual_workspaces[].windows` lists the strip in order. Press that number, such as `V key ctrl+alt-2`, then `V focused --wait-for fixture-1`.
- **Stack.** With `fixture-2` focused, run `V key ctrl+alt-leftbracket`. In the next snapshot both fixtures share `fixture-1`'s `x`, with half the height each.
- **Focus within the stack.** Run `V key ctrl+alt-uparrow` and `V focused --wait-for fixture-1`, then `V key ctrl+alt-downarrow` and `V focused --wait-for fixture-2`. Do the same with `k` and `j`, and with `w` and `s`.
- **Unstack.** Run `V key ctrl+alt+shift-rightbracket`. `fixture-2` returns to its own column on the right.

In the proof run on 2026-11-05, both views agreed about 0.2 s after each key press.

## Direct monitor focus

Monitor focus lands on the window last focused on the destination display.
That is one of Sam's windows unless a fixture held focus there last, so set that up first.
Check the display arrangement before you pick the arrow: on 2026-11-05 display 1 sat below display 3, so only ⌃⌥⌘↑ and ⌃⌥⌘↓ had a destination.

For displays one above the other:

- Open two fixtures, focus `fixture-2`, and move it with `V send-cmd window movedisplay south` as setup.
- Press ⌃⌥⌘↑, then ⌃⌥→ until `fixture-1` holds focus, so it is the last focused window on the upper display.
- Press ⌃⌥⌘↓ and `V focused --wait-for fixture-2`, then ⌃⌥⌘↑ and `V focused --wait-for fixture-1`.
  Repeat with `ctrl+alt+cmd-j` and `-k`, and with `-s` and `-w`.

For displays side by side, use at least three fixture columns on each display.
Record the fixture IDs and use engine commands only to set up the source's interior column and the destination's active fixture.
Confirm that the source fixture has a column on both sides before each shortcut.

- Upgrade a version 4 configuration with the exact default edge-focus arrays.
  Check that `window_focusdisplay_west` and `window_focusdisplay_east` now hold the Command-layer chords, and both edge-focus entries are empty.
- Press ⌃⌥⌘→ from an interior column on the left display.
  Record a snapshot and confirm that both engine focus and macOS focus select the destination fixture on the right display.
- Press ⌃⌥⌘← from an interior column on the right display.
  Confirm both focus observations on the left display.
- Open Settings > Shortcuts.
  Confirm that Focus first column or monitor left and Focus last column or monitor right remain visible with no shortcut chips.
- In isolated configuration tests, cover customized, deleted, empty, and conflicting bindings, then load a fresh store to confirm that conflict notices persist.
  Do not overwrite Sam's custom bindings for a live check.

## Gotchas

- `V fixture --fixed` makes a window that cannot resize. The engine floats it, and column focus skips it, so focus moves between Sam's windows instead. Plain `V fixture` windows resize, and the engine tiles them.
- From a floating window, such as Miri Settings, ⌃⌥← and ⌃⌥→ move only to another floating window on that side, and do nothing when there is none.
  `V send-cmd window focus west` does the same.
  ⌃⌥1 to ⌃⌥9 still work, so jump to a fixture's column number to leave Settings.
- A fixture started from a shell, not through `open`, never comes to the front. Focus then stays on Sam's window, and the before snapshot shows no fixture focused.
- At the left end of the strip, a fresh ⌃⌥← crosses only if a display touches that side and overlaps it vertically.
  With no such display it does nothing.
  At the right end with no such display, ⌃⌥→ enters a fullscreen Space when one exists.
  Auto-repeat stays within the current strip.
- New windows open on the primary display. Check `engine_active_display` in the snapshot before you compare positions.
- The engine reports focus a few hundred milliseconds after the press. Use `--wait-for`, not a fixed sleep.
