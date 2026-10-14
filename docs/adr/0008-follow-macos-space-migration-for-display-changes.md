---
status: accepted
---

# Follow macOS Space migration for display changes

When a display disconnects, Miri relies on macOS to move that display's Spaces and on Paneru to re-attach each strip to its Space's new display.
Window order is kept, and strips return when macOS returns their Space to a reconnected display.
If re-attachment fails within Paneru's timeout, the windows become floating and stay reachable.

Sam considered persistent reconnection policies and layouts that follow the user across different physical monitors.
Those features require saved display layouts, monitor matching, and placement that overrides macOS.
That state would form a second window-management engine in Miri or a large Paneru extension, so the features move to the [v2 roadmap](../../decisions/v2-roadmap.md).
The v1 behavior therefore needs no reconnection settings, but it must be verified on hardware.
Source: Paneru revision `8a213313538a352537b26e25131cfe75f1e00724`, `src/ecs/display.rs` and `src/ecs/workspace.rs`.
