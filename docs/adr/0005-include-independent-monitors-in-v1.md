---
status: accepted
---

# Include independent monitors in v1

Miri supports multiple physical monitors in v1 instead of deferring display support to v2.
Each physical monitor uses the same horizontal scrolling layout as the main display.
Its window order, focus, and scroll position remain independent of other displays.
Display ownership is therefore part of the initial layout model.
The earlier description of "vertically arranged" sets was accidental and does not add a virtual workspace system.

V1 supports horizontal, vertical, and mixed monitor arrangements that Sam can verify on real hardware.
Grid arrangements and the maximum display count move to v2, because v1 cannot verify them without the hardware.
Physical monitor positions determine navigation between displays.
Strip scrolling stays within the current display, and dedicated monitor navigation commands cross between displays.
Scrolling must keep off-screen windows on their assigned displays across all supported arrangements.
Reliable horizontal multi-monitor scrolling blocks the v1 release until verified.
Monitor disconnection and reconnection behavior is recorded in [ADR 0008](0008-follow-macos-space-migration-for-display-changes.md).
