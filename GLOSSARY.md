# Miri

Miri is a macOS scrolling window manager with an app interface.
It is intended for daily use and public release as free and open-source software.

## Language

**Free and open-source software (FOSS)**:
Software whose license gives users the freedom to use, study, modify, and redistribute it.
_Avoid_: Source-available software, freeware

**App interface**:
The macOS interface through which users operate and configure Miri.
_Avoid_: Engine, website demo

**Window engine**:
The component that maintains the window layout and controls other apps' windows.
_Avoid_: Settings interface

**Physical monitor**:
A physical screen that holds one or more native Spaces, each with its own scrolling strip.
_Avoid_: Workspace, Space, virtual monitor

**Native Space**:
A macOS desktop on a physical monitor, created through Mission Control, with its own scrolling strip in Miri.
_Avoid_: Workspace, virtual workspace

**Virtual workspace**:
An extra scrolling strip stacked within one native Space, planned for v2.
_Avoid_: Space, vertical set

**Scrolling strip**:
A horizontal sequence of window columns on one native Space that can extend beyond a display's visible area.
_Avoid_: Vertical workspace set

**Strip gesture**:
A horizontal trackpad swipe that moves a scrolling strip.
_Avoid_: Space switching

**Gesture conflict**:
A macOS gesture assignment that prevents a Miri strip gesture from operating independently.
_Avoid_: Competing window manager

**Gesture test**:
A user-run check of whether a selected strip gesture works without a conflicting macOS gesture.
_Avoid_: Guided shortcut tutorial

**Verified by user test**:
A gesture usability result based on consistent real strip movement without unintended macOS actions, followed by explicit user confirmation.
_Avoid_: Automatically verified

**Column**:
A position in a scrolling strip containing a window or a group of windows.

**Maximized column**:
A column as wide as the display whose window fills the display's usable area, and which stays in its scrolling strip.
_Avoid_: Full-width column, native fullscreen

**Floating window**:
A window outside the scrolling strip whose position is independent of the strip's columns.
_Avoid_: Tiled window

**Tiled window**:
A window that occupies a column in a scrolling strip.
_Avoid_: Floating window

**Monitor navigation**:
Movement of focus or windows between physical monitors according to their screen arrangement.
_Avoid_: Strip scrolling

**Scrolling reliability**:
Consistent scrolling that keeps off-screen windows assigned to their physical monitors.
_Avoid_: Monitor navigation


**Orphaned strip**:
A strip whose display has disconnected and that waits for its macOS Space to appear on another display.
_Avoid_: Lost workspace

**Portable display layout**:
A v2 layout that follows the user to a different set of physical monitors.
_Avoid_: Display profile

**Competing window manager**:
Any other tool that moves or resizes windows, including standalone Paneru.
_Avoid_: Conflicting app

**Setup checker**:
The part of the app interface that reports macOS conditions that stop Miri from working correctly.
_Avoid_: Onboarding, setup wizard

**Repeated crashes**:
Three engine crashes within five minutes, after which Miri stops restarting the engine.
_Avoid_: Crash loop

**Quick check**:
The short multi-monitor test run during everyday development.
_Avoid_: Smoke test

**Release check**:
The full multi-monitor test that blocks the v1 release.
_Avoid_: Quick check, stress test
