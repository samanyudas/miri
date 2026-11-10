# New window width

A window that opens while Miri runs joins the strip on the active display as a new column.
It keeps the width it opens with, but never more than that display's tiling area, so focusing it shows the whole window ([#410](https://github.com/samanyudas/miri/issues/410)).
A window that the user widens past the display afterwards keeps that width and pans.

## Sub-features

- `wider-than-display`: a window that opens wider than the tiling area, as an app that remembers its size from a larger display does, gets the tiling area's width.
- `background-open`: a window that opens on another display without taking focus, as after an updater relaunch, joins the active display's strip and gets that display's limit.

## How to get to it (user POV)

- An app opens a new window, or relaunches and restores its window, while Miri runs.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md).
- Two displays, the active one narrower than the width you pass. Read each display's ID and point size with `NSScreen.screens`, and the active display with `V query active`.

- **Focus the narrower display.** Press `ctrl+alt+cmd-downarrow` or the Focus display chord toward it, and check `V query active` shows its `display_id`.
- **Open a wide window in the background.** Run `V fixture --width 2560 --display <wider display ID> --background`, then `V snapshot after-open`. The fixture's `display_id` is the active display, and its `frame.width` is at most that display's tiling width: its point width minus the left and right `[padding]` in `config.toml`.
- **Focus it.** Press `ctrl+alt-rightarrow` until `V focused --wait-for fixture-1` passes, then `V snapshot focused`. The fixture's macOS frame lies inside the display: read it with `CGWindowListCopyWindowInfo` for the fixture's window ID.
- **Open a wide window with focus.** Run `V fixture --width 2560 --display <display ID>`. Its column is at most that display's tiling width.

## Gotchas

- AppKit limits a window that opens on a display to that display's width, so `--display <narrow display>` alone gives a column only the padding too wide. Open on the wider display with `--background` to get the full overflow from #410.
- The engine's frame includes the per-window padding, so it is 8 points wider than the macOS frame with Miri's 4-point padding.
