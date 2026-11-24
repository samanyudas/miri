# New window width

A window that opens while Miri runs joins the strip on the active display as a new column.
Miri writes `new_window_width = 0.5` under `[options]` in `config.toml` whenever the key is missing, so by default a new column is half the display's tiling area ([#460](https://github.com/samanyudas/miri/issues/460)).
When the key holds no ratio above 0 and up to 1, such as `0`, the window keeps the width it opens with.
Either way the column is never wider than the tiling area, so focusing it shows the whole window ([#410](https://github.com/samanyudas/miri/issues/410)).
A `[windows]` rule's `width` wins over `new_window_width` ([#464](https://github.com/samanyudas/miri/issues/464)).
A window that the user widens past the display afterwards keeps that width and pans.

The tiling area is the display's visible width, which excludes a Dock on the left or right, minus the left and right `[padding]`.

## Sub-features

- `half-width`: a new column is as wide as the 0.5 width preset, half the tiling area, so two new columns fill it side by side.
- `wider-than-display`: a window that opens wider than the tiling area, as an app that remembers its size from a larger display does, gets half the tiling area by default, and the tiling area's width when `new_window_width` holds no ratio.
- `background-open`: a window that opens without taking focus, as after an updater relaunch, joins the active display's strip, keeps focus where it was, and gets that display's width. With two displays, a window that opens on the other display joins the active one too.

## How to get to it (user POV)

- An app opens a new window, or relaunches and restores its window, while Miri runs.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md).
- `[options]` in `config.toml` holds `new_window_width = 0.5`, and `[padding]` holds the left and right padding you compare against.
- For the other-display steps, two displays. Read each display's ID and point size with `NSScreen.screens`, and the active display with `V query active`.

- **Empty the display.** Run `V empty-display`, or `V empty-display --display <ID>` for each display under test, so each strip holds only the fixtures you open next.
- **Open two half-width windows.** Focus the display under test, check `V query active`, then run `V fixture --count 2` and `V snapshot two-open`.
  Each fixture's `frame.width` is half the tiling width.
  The left fixture's `frame.x` is the display's left edge plus the left `[padding]`, and the right fixture's `frame.x + frame.width` is the right edge minus the right `[padding]`, each within 1 point.
  On 2026-11-25, on the 2048-point built-in display with 4-point padding, the fixtures were 1020 points wide at x 4 and 1024.
- **Column number.** Press `ctrl+alt-1` and `V focused --wait-for` the left fixture, then `ctrl+alt-2` and the right one.
- **Open a wide window with focus.** Run `V fixture --width 2560` and `V focused --wait-for` it. Its `frame.width` is half the tiling width, not 2560.
- **Open a wide window in the background.** Run `V fixture --width 2560 --background`, then `V snapshot wide`. `V query state` lists the fixture in the active strip, at half the tiling width, and `V focused` still shows the fixture that had focus.
  With two displays, add `--display <other display ID>` and check that the fixture's `display_id` is the active display.
- **The tiling-area limit.** Save a copy of `config.toml`, then change it to `new_window_width = 0` with an in-place write, such as Python's `open(path, "w")`, not with `sed -i`.
  Wait until `engine.log` has one more `Reloading configuration file` line, then run `V fixture --width 2560` and `V snapshot clamp`.
  The fixture's `frame.width` is the whole tiling width, 2040 points on the built-in display, at the left `[padding]`.
  Write the copy back in place, such as with `cat copy.toml > config.toml`, wait for the next reload line, and check that `diff <run>/backup/config.toml config.toml` is empty.
- **Move them to the other display.** With two displays and the other display's strip empty, focus the end column next to it and press `ctrl+alt+shift-leftarrow` or `-rightarrow`, which moves a strip's end column across.
  Do the same for the second fixture, then check the same edges on that display.

## Gotchas

- AppKit limits a window that opens on a display to that display's width, so on one display a `--width 2560` fixture opens 2048 points wide and the engine trims it to the tiling width. Open on a wider display with `--background` to get a larger overflow.
- `sed -i` replaces `config.toml` with a new file, and in the 2026-11-25 run the engine logged no reload for it. Miri's own saves and an in-place write each logged one.
- The width preset and the new column use the same rounding, so two half-width columns meet without a gap.
- The engine's frame includes the per-window padding, so it is 8 points wider than the macOS frame with Miri's 4-point padding.
