# Focus a window with a shortcut

A shortcut moves keyboard focus to the next column left or right in the strip, or to the window above or below in a stacked column.
The engine scrolls the strip so the focused column shows, and macOS makes that window's app frontmost.

## Sub-features

- `focus-west`: ⌃⌥← (also ⌃⌥H and ⌃⌥A) focuses the column to the left.
- `focus-east`: ⌃⌥→ (also ⌃⌥L and ⌃⌥D) focuses the column to the right.
- `focus-north`, `focus-south`: ⌃⌥↑ and ⌃⌥↓ focus the window above or below in a stacked column.
- `focus-edge`: ⌃⌥⌘← and ⌃⌥⌘→ focus the first or last column, or the next display at the edge.
- `focus-number`: ⌃⌥1 to ⌃⌥9 focus a column by its position.

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
- **Letter chords.** Run `V key ctrl+alt-h`, `V focused --wait-for fixture-1`, then `V key ctrl+alt-l`, `V focused --wait-for fixture-2`. Each exits 0, as for the arrows.
- **Stacks.** Not yet covered. Stacking needs ⌃⌥[ or ⌃⌥] first, then ⌃⌥↑ and ⌃⌥↓.

In the proof run on 2026-11-02, both views agreed about 0.6 s after each key press.

## Gotchas

- `V fixture --fixed` makes a window that cannot resize. The engine floats it, and column focus skips it. Without `--resizable`, the old AXFixture behaved this way, and focus moved between Sam's windows instead.
- A fixture started from a shell, not through `open`, never comes to the front. Focus then stays on Sam's window, and the before snapshot shows no fixture focused.
- At the left end of the strip, a fresh ⌃⌥← crosses only if a display touches that side.
  With no touching display it does nothing.
  Auto-repeat stays within the current strip.
- New windows open on the primary display. Check `engine_active_display` in the snapshot before you compare positions.
- The engine reports focus a few hundred milliseconds after the press. Use `--wait-for`, not a fixed sleep.
