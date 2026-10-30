---
status: accepted
---

# Limit system access

Miri requires Accessibility permission and keeps System Integrity Protection (SIP) enabled.
Features that require additional permissions or SIP changes do not meet these boundaries, except the one opt-in Screen Recording use below.
Undocumented macOS APIs require individual evaluation of their compatibility risks and fallback behavior before adoption.
This permits evaluating undocumented APIs without treating them as approved dependencies.

## Screen Recording for edge slices

Sam allowed one opt-in Screen Recording use in [#150](https://github.com/samanyudas/miri/issues/150) on 28 October 2026.
With displays side by side, a hidden column cannot leave a slice of its window on the edge the displays share, because macOS would move that window to the other display.
The engine instead shows a photo of the slice the window would show there.
The engine takes these photos, and the engine runs as a child process of `Miri.app`.

The **Show window contents on edges next to another display** switch in Settings > Layout controls this use.
It is off by default, and it writes `[options].shared_edge_slices`.
Turning it on asks macOS for Screen Recording permission.
Without the permission, the switch stays off.

The engine photographs the whole of each window that is hidden behind or crossing an edge next to another display, so the photo can stand in for the window while it slides across that edge.
It shows a photo only where the real window cannot show.
It photographs no other window or part of the screen, keeps the photos in memory only, and sends nothing off the Mac.
It keeps a window's last photo until the window closes or the switch turns off.
With the switch off, Miri does not capture the screen.
Whether macOS attributes the engine's captures to the permission of `Miri.app` must be checked on the signed bundle, as the [permission prototype](../prototypes/helper-permission.md) did for Accessibility under [ADR 0009](0009-run-the-engine-as-a-helper-process.md).
