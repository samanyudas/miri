# Known limitations

This page lists every known limitation of Miri in one place.
Each entry names its kind, what triggers it, what you notice, any workaround, and the evidence behind it.
Report a limitation that is missing here through [GitHub Issues](https://github.com/samanyudas/miri/issues/new/choose).

## How to read this page

Unless an entry says otherwise, it applies to Miri Developer built from `main` at `3b0badf`, with the engine pinned at `3fee523`.
Miri has no release, so no entry describes a released version.
The audit for [#91](https://github.com/samanyudas/miri/issues/91) checked each entry against the source and the evidence on 27 October 2026.
Later the same day, the page was updated for `main` at `6882f8a`, with engine `7b180e6`, to drop the fixed [#120](https://github.com/samanyudas/miri/issues/120) and the verified [#72](https://github.com/samanyudas/miri/issues/72).

Each entry has one of five kinds:

- **Platform constraint.** macOS, the hardware, or the bundled engine sets the limit, and Miri works within it.
- **Scope exclusion.** Sam decided that v1 does not do this.
- **Not built yet.** Accepted v1 work that is not finished. Its issue tracks the work.
- **Confirmed defect.** Someone observed the wrong behavior on the real app.
- **Unverified.** Someone reported or suspects the behavior, or a scenario has not run on hardware. An unverified entry is not an established limitation.

**Previously undocumented** marks a confirmed entry that no user documentation, decision record, or architecture decision mentioned before this audit.
Working notes in PROGRESS.md and issue comments do not count as documentation.

## Release and support

| Limitation | Kind | Trigger and impact | Workaround | Evidence and tracking |
| --- | --- | --- | --- | --- |
| Miri has no release. You can only build it from source as Miri Developer. No Developer ID signed and notarized release disk image exists, and no Homebrew cask exists. `make package` builds a development disk image only. | Not built yet | Any use. | Build from source as the [README](../README.md#build-and-run) describes. | [Signing, distribution, and updates](../decisions/release-scope.md#signing-distribution-and-updates), [`scripts/build-app.sh`](../scripts/build-app.sh), [#82](https://github.com/samanyudas/miri/issues/82). |
| Miri does not update itself. The accepted Sparkle updater is not built yet. | Not built yet | Any use. You must rebuild to get changes. | Pull `main` and run `make build`. | No Sparkle code exists in `Sources/`. [Design tree status](../decisions/design-tree-status.md), [#82](https://github.com/samanyudas/miri/issues/82). |
| No v1 acceptance check has passed. No release candidate is frozen, and 0 of 3 full runs have passed. | Unverified | Every behavior on this page and in the release scope still needs its recorded check. | None. | [Acceptance ledger](acceptance-ledger.md#release-candidate), [#83](https://github.com/samanyudas/miri/issues/83). |
| Many recent fixes were checked with synthetic keyboard and mouse input only. A physical check is still open for drag into another stack, stack overflow, and the stack limit. | Unverified | Real input can differ from synthetic events. | None. | [#43](https://github.com/samanyudas/miri/issues/43), checks S-5 to S-7 in the [acceptance ledger](acceptance-ledger.md). |

## Platforms and hardware

| Limitation | Kind | Trigger and impact | Workaround | Evidence and tracking |
| --- | --- | --- | --- | --- |
| Miri runs only on Apple silicon Macs with macOS 27.0 or later. Intel Macs and older macOS versions are not supported. | Scope exclusion | The build script stops on a Mac that is not arm64, and the app declares macOS 27.0 as its minimum. | None. | [Supported platforms](../decisions/release-scope.md#supported-platforms), [`scripts/build-app.sh`](../scripts/build-app.sh). |
| Development has used one Mac, a MacBook Air with an Apple M3 chip, with at most two displays at once. | Unverified | Other Mac models and three or more displays have not run. | None. | [Multiple monitors](../decisions/release-scope.md#multiple-monitors). |
| Strip gestures need a built-in trackpad or a Magic Trackpad. | Platform constraint | A Mac with only a mouse has no strip swipe. | Use the keyboard commands, or a modifier with the mouse wheel. | [Setup](../decisions/setup.md). |

## Permissions and macOS settings

| Limitation | Kind | Trigger and impact | Workaround | Evidence and tracking |
| --- | --- | --- | --- | --- |
| Miri needs Accessibility permission, and it will not start window management without it. | Platform constraint | Permission off. The setup checker shows a problem. | Turn on Miri Developer in the Accessibility list. | [System access](../decisions/release-scope.md#system-access), [ADR 0002](adr/0002-limit-system-access.md). |
| Miri refuses to start while **Displays have separate Spaces** is off. Changing that setting needs a log out. | Platform constraint | The setting is off. Window management stays stopped. | Turn the setting on, then log out and back in. | [Conflicts and setup checker](../decisions/release-scope.md#conflicts-and-setup-checker), [ADR 0008](adr/0008-follow-macos-space-migration-for-display-changes.md). |
| Miri detects only four competing window managers: Paneru, AeroSpace, Amethyst, and yabai. Other window managers do not stop Miri from starting. | Unverified, previously undocumented | Another tool that moves windows runs beside Miri. Whether a given tool conflicts is not checked. | Quit other tools that move windows before you start Miri. | [`SetupChecker.swift`](../Sources/MiriCore/SetupChecker.swift). Next step: test common tools, such as Rectangle, with Miri running. |
| Stage Manager and the macOS tiling options move windows that Miri arranges. Miri warns about them but does not block. | Platform constraint | One of them is on. Windows can leave their layout place. | Turn them off. The setup checker links to the setting. | [Conflicts and setup checker](../decisions/release-scope.md#conflicts-and-setup-checker), [#43](https://github.com/samanyudas/miri/issues/43). |
| Miri never changes macOS settings. When a known macOS gesture conflicts with a strip gesture, or Miri cannot read the gesture settings, the strip gesture stays off. | Platform constraint | A conflict, or no successful gesture test. | Change the macOS gesture, then run **Test Gesture**. Keyboard commands work meanwhile. | [Strip gestures](../decisions/release-scope.md#strip-gestures). |

## Displays

| Limitation | Kind | Trigger and impact | Workaround | Evidence and tracking |
| --- | --- | --- | --- | --- |
| A thin sliver of each off-screen window stays visible at the display edge. On a side that touches another display, only a small corner of the window shows, at the bottom of that side. | Platform constraint, previously undocumented | Any strip wider than its display. macOS moves windows that sit fully off-screen, so the engine keeps 5 points showing. | The engine keys `sliver_width` and `sliver_height` set the size. | The engine's [recommended system options](https://github.com/samanyudas/paneru/blob/3fee523670ebf929ad936ba98beb999b0319930b/README.md#recommended-system-options). |
| Moving a maximized window to another display is checked only with the displays above and below each other. | Unverified | Side-by-side displays. Not checked since the [#103](https://github.com/samanyudas/miri/issues/103) fix. | None. | [#87](https://github.com/samanyudas/miri/issues/87). |
| Mixed arrangements, which need three displays, have not run. Grid arrangements and a maximum display count are deferred to v2. | Unverified for mixed, scope exclusion for grids | Three or more displays. | None. | [Multiple monitors](../decisions/release-scope.md#multiple-monitors). |
| After a display disconnects and returns, windows go back to their display in their old order and stacks. A cable unplug passed on hardware, and a software unplug passed 3 cycles. After a lid close or a sleep, windows return only while Miri still manages them, and #147 drops some. | Confirmed defect for the lid and sleep | Unplugging a display, closing the lid, or sleep. | If a strip cannot re-attach, its windows float and stay reachable. | [Display changes](../decisions/release-scope.md#display-changes), [#142](https://github.com/samanyudas/miri/issues/142), checks HD-1 to HD-5 in the [acceptance ledger](acceptance-ledger.md). |
| After a wake, windows that macOS moved to another display can drop out of Miri. They stay on screen but are no longer tiled. | Confirmed defect | A lid close, a sleep, or a wake that moves windows between displays. | Restart Miri, or focus each window. | [#147](https://github.com/samanyudas/miri/issues/147). |
| Focus and move commands stop at the end of a strip. They do not cross to the next display. | Not built yet | The focused column is the last one on its display. | To move focus to another display, press Control-Option-Command with W, A, S, or D. To move the window, add Shift. | [#104](https://github.com/samanyudas/miri/issues/104). |

## Finding and restoring windows

| Limitation | Kind | Trigger and impact | Workaround | Evidence and tracking |
| --- | --- | --- | --- | --- |
| One window of an app whose main thread stays busy at launch can stay unmanaged. | Confirmed defect with test apps only | Six busy test apps launch together. The engine lists each app's windows once, and a window whose details time out is skipped and not listed again. In 1 of 576 windows, one window stayed unmanaged for the 8 s check. | None known. | [#63](https://github.com/samanyudas/miri/issues/63). |
| After an engine restart, each strip starts at its first column. The window that was in view can sit off-screen, and a maximized window can come back partly in view. | Confirmed defect, previously undocumented | Restart Engine, a crash restart, or relaunching Miri. | Focus the window. | [#69](https://github.com/samanyudas/miri/issues/69). |
| Session restore drops windows that no longer exist and closes the gaps they leave. It keeps no state for a display that is not connected. | Platform constraint, previously undocumented | Restart after windows close or a display disconnects. | None. | The engine's [session restore](https://github.com/samanyudas/paneru/blob/3fee523670ebf929ad936ba98beb999b0319930b/CONFIGURATION.md) documentation. |
| A window that matches a floating rule floats after a restart, even if it was tiled when the layout was saved. A window you tiled with the float toggle stays tiled. | Scope exclusion | Restart with a floating rule that matches a tiled window. | Tile it again with Control-Option-T. | [Startup and crash recovery](../decisions/release-scope.md#startup-and-crash-recovery), [#15](https://github.com/samanyudas/miri/issues/15), [#93](https://github.com/samanyudas/miri/issues/93). |
| By default, the engine ignores windows that are neither standard nor floating windows, such as dialogs. It also ignores background apps that run without a Dock icon. | Platform constraint, previously undocumented | Those windows stay where the app puts them. | The engine documents a window rule with `manage = true` in `config.toml` that manages them. Settings has no control for it, and this rule has not run with Miri. | The engine's [window rules](https://github.com/samanyudas/paneru/blob/3fee523670ebf929ad936ba98beb999b0319930b/CONFIGURATION.md) documentation. |

## Stacks and window sizes

| Limitation | Kind | Trigger and impact | Workaround | Evidence and tracking |
| --- | --- | --- | --- | --- |
| When Finder is frontmost with no window, the previously focused stack window can stay above its overlapped place. | Scope exclusion | Click the desktop or close Finder's last window. The order returns when focus reaches a managed window. | Focus any managed window. | [Stacks](../decisions/release-scope.md#stacks), [#42](https://github.com/samanyudas/miri/issues/42). |
| Stacks overlap below each top bar when their windows cannot shrink further. The engine gives each resizable stacked window a layout slot of at least 200 points, so a stack can overlap when the real minimum heights would fit. A window that cannot be resized needs only its own height. | Confirmed defect, previously undocumented | Tall minimum heights in one column. Every top bar stays visible. | Focus a window to bring it to the front, or move a window to its own column. | [Stacks](../decisions/release-scope.md#stacks), [#93](https://github.com/samanyudas/miri/issues/93), [#124](https://github.com/samanyudas/miri/issues/124). |
| An app that applies a new size more than 500 ms late can have its old height recorded as a minimum. | Unverified, previously undocumented | Slow apps, such as some Chromium browsers. Inferred from the engine design and not observed. | None known. | [#40](https://github.com/samanyudas/miri/issues/40), closed. Next step: stack a fixture window that applies each new size 1 second late, then check whether the engine records a false minimum height. |
| Fixed-size windows float automatically. A fixed-size window that you tile keeps its own size, so empty space shows beside or below it. | Scope exclusion | Tile a fixed-size window with Control-Option-T. | None. | [V1 interactions](../decisions/release-scope.md#v1-interactions), [Stacks](../decisions/release-scope.md#stacks), [#93](https://github.com/samanyudas/miri/issues/93). |
| A window with a maximum size maximizes only to that size, at the top-left of the usable area. | Platform constraint | Maximize such a window. | None. | [Maximizing a window](../decisions/release-scope.md#maximizing-a-window). |

## Dragging, gestures, and focus

| Limitation | Kind | Trigger and impact | Workaround | Evidence and tracking |
| --- | --- | --- | --- | --- |
| A drop onto another display that macOS then tiles is not undone. The window leaves its layout place. | Confirmed defect, previously undocumented | A macOS tiling option is on during a drag to another display. | Turn off the macOS tiling options. | [#123](https://github.com/samanyudas/miri/issues/123). |
| A dragged window that macOS does not fill can end 8 points up against the menu bar. | Confirmed defect, previously undocumented | Some title-bar drags. Frequency is not recorded. | None known. | [#122](https://github.com/samanyudas/miri/issues/122). |
| Swipe lag builds up over time. | Confirmed defect, previously undocumented | Long sessions. The cause is unknown. | Quit and reopen Miri. | [#66](https://github.com/samanyudas/miri/issues/66). |
| The macOS system Picture-in-Picture window, which Safari, QuickTime Player, and IINA use, cannot take keyboard focus. | Platform constraint | Picture-in-Picture in those apps. macOS keeps the window above other windows. | Use the window's controls with the pointer. | [V1 interactions](../decisions/release-scope.md#v1-interactions), [#77](https://github.com/samanyudas/miri/issues/77). Firefox and Zen Picture-in-Picture have not run. |
| In Chromium-based browsers, a double-click on a tab also maximizes the window. | Platform constraint | The browser hides its tabs from Accessibility. | Double-click the title bar away from the tabs. | [Maximizing a window](../decisions/release-scope.md#maximizing-a-window). |
| A Picture-in-Picture window stays on the display where it opened. It does not follow focus to another display. | Scope exclusion | Move focus to another display while Picture-in-Picture plays. | Move the window by dragging it. | [V1 interactions](../decisions/release-scope.md#v1-interactions), [#77](https://github.com/samanyudas/miri/issues/77). |
| Arrow, HJKL, and WASD shortcuts are not yet interchangeable. | Not built yet | Only the default keys work for each action. A v1 release blocker. | Change the binding in **Shortcuts**. | [#79](https://github.com/samanyudas/miri/issues/79). |

## Reports not yet reproduced

These reports are not established limitations.
Each one has an open issue with the next investigation step.

- Windows show in Mission Control or a window switcher but are not on the expected desktop: [#85](https://github.com/samanyudas/miri/issues/85).
- Window interactions feel delayed: [#78](https://github.com/samanyudas/miri/issues/78).

## Deferred to v2

V1 leaves out the optional Miri dock, portable display layouts, tabbed columns, the minimap, inactive-window dimming, advanced window rules, and virtual workspaces.
It also leaves out focus borders, pointer-following controls, display exclusions, fixed-pixel presets, animation tuning, Hyper-key recording, five-finger gestures, and the guided shortcut tutorial.
A deferral does not commit Miri to building the feature in v2.
[Release scope](../decisions/release-scope.md) owns that list, and the [v2 roadmap](../decisions/v2-roadmap.md) records the candidates.
