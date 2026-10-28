---
status: accepted
---

# Follow macOS Space migration, then send windows back to their display

When a display disconnects, macOS moves Spaces between displays, and Paneru re-attaches each strip to its Space's new display.
Every window stays reachable while the display is gone.
If re-attachment fails within Paneru's timeout, the strip's windows become floating and stay reachable.
When the display returns, macOS does not put the windows back where they were.
On Sam's Mac it hands the returning main display every Space that existed before, including the built-in display's own Space, and gives the built-in display a new empty Space.

Miri therefore restores the layout from before the change, as Sam decided in [#142](https://github.com/samanyudas/miri/issues/142) on 28 October 2026.
The engine records each display's columns and stacks when a display change starts, before macOS moves or destroys any Space.
After the change settles, it moves each window that macOS put on another display back to its own display, in its old column order and stack.
Windows that never left their display keep their place, including any reordering done meanwhile.
A window opened while a display was gone stays on the display it was opened on.
A window closed meanwhile is forgotten.
The engine can only move a window into a display's current Space, so windows from several Spaces of one display come back together in the Space that display shows.

The record is in memory only and needs no settings.
Layouts that follow the user to a different set of physical monitors, and a setting to choose between restoring and keeping the current layout, stay on the [v2 roadmap](../../decisions/v2-roadmap.md).
This behavior must be verified on hardware, including the lid and sleep and wake.
Source: Paneru branch `miri/v0.5.2`, `src/ecs/display_homes.rs` and `src/ecs/display.rs`.
