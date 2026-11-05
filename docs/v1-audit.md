# V1 completion and verification audit

This audit answers [#83](https://github.com/samanyudas/miri/issues/83): how much of v1 is built, and how much of it has been tested, on one fixed revision.
It is a snapshot taken on 6 November 2026.
It owns no fact of its own.
[Release scope](../decisions/release-scope.md) owns what v1 is, the [acceptance ledger](acceptance-ledger.md) owns acceptance results, [known limitations](limitations.md) owns limitations, and GitHub Issues own the work.
When this page and one of those owners disagree later, the owner is right.

## Audited revision

| Item | Value |
| --- | --- |
| App revision | `main` at `6edff137`, the merge of [#304](https://github.com/samanyudas/miri/pull/304) |
| Engine pin | `vendor/paneru` at `ee896478` (engine `ee89647`) on branch `miri/v0.5.2` of `samanyudas/paneru` |
| Same code as | `a5853509`. The three later commits change only docs, issue templates, and the command guard tests. |
| Tested artifact | `Miri Developer.app` built from `6edff137` with `make build`, signed with Miri Developer Local Signing, engine source `ee896478` |
| Release artifact | None. No GitHub release, release disk image, or Homebrew cask exists. |
| macOS | 27.0.1 (26A434) |
| Hardware | MacBook Air, Apple M3 (`Mac15,12`), built-in display 2048 x 1332 and a 2560 x 1440 external display as the main display, side by side |

Evidence gathered on this revision:

- **Automated tests.** CI run [42036549784](https://github.com/samanyudas/miri/actions/runs/42036549784) on `6edff137` passed every job on attempt 2.
  Attempt 1 failed one engine test, `slice_photos::a_press_while_a_revealed_photo_waits_never_shows_its_window_beside_it`.
  The previous commit `3668b75a` has the same engine code and passed, so this test is flaky.
- **Lifecycle model check.** `make verify-engine-lifecycle` exited 0 on `6edff137`.
  All seven rules hold in 196 states, all three mutants break as expected, and the covered code is unchanged since sync commit `f9d4ab38`.
- **Native run.** `verify-miri` run `20261106-090237` drove the tested artifact with synthetic key presses and Accessibility presses on the hardware above.
  It is an automated native observation, not a hand check, and its files stay on Sam's Mac in `~/.cache/miri/verify-miri/runs/`.
  The results are in [Observed on the audited revision](#observed-on-the-audited-revision).

## Status words

Each requirement below gets the furthest status that has evidence.
The statuses are separate kinds of evidence, and a later one does not imply an earlier one.

| Status | Meaning on this page |
| --- | --- |
| Not built | No code on `6edff137` does it. |
| Partly built | Some of the requirement is on `6edff137`, and a named part is missing. |
| Merged | The code is on `main` at `6edff137`. Every built item on this page is merged, because the audit reads `main` only. |
| Automatically tested | A Swift Testing suite, an engine test, or a selftest covers it and passed in CI on `6edff137`, or the lifecycle model check (TLA) covers it. CI does not run the model check. It passed when run locally on `6edff137`. |
| Natively tested | A `verify-miri` run or a selftest drove Miri Developer on Sam's desktop with synthetic input. The column names the revision. |
| Hand checked | Sam used real input on real hardware, or Sam physically changed displays, the lid, or sleep. The column names the revision. |
| Hardware accepted | A check in the acceptance ledger passed on a frozen release candidate. |
| Published | A signed, notarized release is available to the public. |

On `6edff137`, no requirement is hardware accepted, because no release candidate is frozen and every ledger check is **Pending**.
No requirement is published, because Miri has no release.
Every native and hand check below ran on an older revision than `6edff137`, except the native run of 6 November 2026.
An older result is stale when code it covers changed afterwards.
The notes say so where PROGRESS.md or an issue records such a change.

## Summary

The denominator is the 98 requirements in the [requirement map](#requirement-map).
Each one is an accepted rule from release scope, split as the map shows, plus [#302](https://github.com/samanyudas/miri/issues/302), which Sam accepted into v1 on 5 November 2026.
A requirement counts as complete for a status only when the whole requirement reached it.
Counted on `6edff137` with a script that reads the map's tables:

| Status reached | Requirements |
| --- | --- |
| Built and merged | 84 of 98 |
| Partly built | 6 of 98 |
| Not built | 8 of 98 |
| Automatically tested | 83 of 98 |
| Natively tested or hand checked on some revision | 66 of 98 |
| Natively tested on `6edff137` | 6 of 98, and one of them, LAY-3, failed |
| Hardware accepted | 0 of 98 |
| Published | 0 of 98 |

The automatically tested count includes 3 partly built requirements whose built part has tests.
The native and hand count includes results on old revisions, so it says what was ever seen, not what holds now.

The acceptance ledger has 105 checks: S-1 to S-7, 70 app checks, and 28 multi-monitor checks.
0 of 105 pass, because none has run on a frozen release candidate.
0 of 3 required full runs have passed.

Feature work and release readiness are separate:

- **Features.** Most accepted window-management behavior is built and automatically tested.
  The gaps are new-window width ([#305](https://github.com/samanyudas/miri/issues/305)), the swipe target and its setting ([#212](https://github.com/samanyudas/miri/issues/212)), the login item state ([#201](https://github.com/samanyudas/miri/issues/201)), and Karabiner-Elements and Hyper key support ([#302](https://github.com/samanyudas/miri/issues/302)).
- **Release.** None of the signing, notarization, update, or Homebrew work exists ([#82](https://github.com/samanyudas/miri/issues/82)), no release candidate is frozen, and no acceptance or endurance check has passed.

## Requirement map

Columns:

- **Built** is Built, Partly, or Not built.
- **Tests** names the automated coverage, or None.
- **Latest native or hand evidence** names the newest observation on real hardware, its kind, and its revision.
  Native means natively tested with synthetic input, and Hand means hand checked by Sam.
- **Checks** are the acceptance ledger rows that verify the requirement.

Abbreviations: `SC` is `Sources/MiriCore`, `SM` is `Sources/Miri`, `E` is `vendor/paneru/src`, `T` is `Tests/MiriCoreTests`, `ET` is `vendor/paneru/src/tests`, and TLA is the lifecycle model check.

### App controls and window recovery

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| APP-1 | Start and Stop in the menu and Settings, and a Stop shortcut | Built: `SM/AppModel.swift`, `SM/Views.swift` | TLA | Native, `6edff137`, run `20261106-090237`: ⌃⌥Q stopped, Start started | AL-1 to AL-3 |
| APP-2 | Permission guidance | Built: `SC/SetupChecker.swift`, `SM/InitialSetup.swift` | `SetupCheckerTests` | None with a grant. The CI permission selftest on `e516edd` ran without one and left attribution unresolved | AP-1, AP-2 |
| APP-3 | Gap and width preset settings | Built: `LayoutSettings` | `ConfigurationTests` | Native, gap stepper on the #228 branch, 1 Nov, branch commit not recorded. Width presets: none | AC-1 |
| APP-4 | Shortcut editing | Built: `SM/ShortcutsSettings.swift`, `SM/ShortcutRecorder.swift` | `ShortcutsTests` | Native, `c4ba432e`, run `20261105-160539` | AS-1, AS-13, AS-14 |
| APP-5 | Access to logs | Built: `AppModel.showLogsInFinder` | `RotatingLogTests` | Native, #220 branch on `e8d69276`, 2 Nov | AU-3 |
| APP-6 | Closing Settings keeps management running | Built | None | None | AL-1 |
| APP-7 | Stop pauses, and Quit stops the app and the engine | Built: `AppModel.stop`, `prepareToQuit` | TLA, `EngineTests` | Native, Stop on `6edff137`. Quit on `4c30e66b`, run `20261102-165439` | AL-2, AL-3 |
| APP-8 | Every managed window stays reachable after Stop, Quit, or an engine failure | Built: `SC/WindowRecovery.swift`, `E/parent_watch.rs` | `WindowRecoveryTests`, `EngineTests`, recovery selftest | Native, `6edff137`: after Stop, all 12 windows lay inside the two displays. Which windows were off screen before the Stop was not recorded. Recovery selftest on `e120875c`, 4 Nov | AW-1 to AW-6 |

### Privacy and diagnostics

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| PRV-1 | No telemetry or window data leaves the Mac | Built: no network code in `Sources` or the engine | None | None | AU-4 |
| PRV-2 | Copy Diagnostics with a preview, covering versions, displays, permission, engine status, and redacted logs | Built: `SM/Views.swift` `DiagnosticsView`, `SC/Diagnostics.swift` | `DiagnosticsReportTests` | None | AU-3 |
| PRV-3 | Titles, paths, user names, and raw configuration excluded | Built: `Redactor.redact` | `RedactorTests` | None | AU-5 |

### Default shortcuts and layout

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| LAY-1 | Default shortcuts follow the keybinding reference | Built: `SC/Bindings.swift` | `BindingsTests` | Native, `c4ba432e`, run `20261105-160539` | AS-4 |
| LAY-2 | Presets `[0.25, 0.33, 0.5, 0.66, 0.75]` and 8-point gaps | Built: `MiriSettings` | `ConfigurationTests` | Native, fresh install on the #92 branch, 26 Oct, branch commit not recorded, before the version 5 defaults | AC-7 |
| LAY-3 | New windows start at 50% of display width | **Not built.** Miri writes no width rule | None | Native, `6edff137`: a 380-point window tiled at 388 points on a 2560-point display | AS-5, [#305](https://github.com/samanyudas/miri/issues/305) |
| LAY-4 | Existing windows keep their widths | Built | `ET/session_restore.rs` | Native, `4c30e66b`, #153, 2 Nov | AS-5 |
| LAY-5 | Width and height change by five percentage points per press | Built: `window_resize_step` | `ET/tiling.rs` | Native, `4c30e66b`, #153, 2 Nov | AS-6 |
| LAY-6 | Shortcuts and the recorder work with non-US layouts, including AZERTY, QWERTZ, and Dvorak | Built: `SC/KeyLayout.swift`, and `AppModel` restarts the engine when the layout changes | `ShortcutsTests`, `BindingsTests` on US, French, German, and Dvorak layouts | Native, engine `28f550f` on the #31 branch, 26 Oct, branch commit not recorded: the engine logged top-row AZERTY digits, and no key press result counted | AS-2 |

### Startup and crash recovery

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| REC-1 | Management starts once Accessibility is granted | Built: `AppModel.launch`, `pollSetupUntilReady` | TLA | Native, `make check` on `e120875c`, 4 Nov. Attribution unresolved | AP-2 |
| REC-2 | A Stop persists across launches | Built: `managementStopped` | TLA | Native, `6edff137`: relaunch started no engine and showed `Stopped` | AL-2 |
| REC-3 | Launch at login, on by default | Partly: on by default, but Settings does not show the login item's state | None | None | AL-4, [#201](https://github.com/samanyudas/miri/issues/201) |
| REC-4 | The engine restarts after an isolated crash and restores the layout | Built: `EngineSupervisor.exited` | `EngineTests`, `ET/session_restore.rs` | Native, `6edff137`: after `kill -9`, a new engine ran within 2 s, restore matched 12 windows, fixture frames unchanged | AL-5, HQ-7, HR-1 |
| REC-5 | Three crashes in five minutes stop retries and show the failure, logs, and Restart | Built: `CrashPolicy` | `EngineTests` | Native, #220 branch on `e8d69276`, 2 Nov | AL-6, HR-2 |
| REC-6 | A successful manual restart resets the crash count | Built: `restartManually` | `EngineTests` | Native, `929a2c10`, run `20261104-171657` | AL-7 |
| REC-7 | A floating rule beats a saved tiled placement, except a window tiled with the float toggle ([#15](https://github.com/samanyudas/miri/issues/15), [#93](https://github.com/samanyudas/miri/issues/93)) | Built: `E/ecs/tile_overrides.rs` | `ET/session_restore.rs` | Native, engine `e7036de` (same tree as `6325638`), #93: an engine restart kept the override, with commands sent to the engine. A Miri restart with a non-Miri window: none | None |

### Setup and conflicts

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| SET-1 | Refuse to start while a competing window manager runs, name it, and leave its configuration alone | Built for Paneru, AeroSpace, Amethyst, and yabai | `SetupCheckerTests` | Native, `c4ba432e`, `yabai` stand-in, run `20261105-160539` | AP-4 |
| SET-2 | Refuse while **Displays have separate Spaces** is off, and explain the log out | Built | `SetupCheckerTests` | None | AP-5 |
| SET-3 | Report Stage Manager, the three macOS tiling options, and gesture conflicts, without blocking | Built | `SetupCheckerTests` | Native, gesture advice on `e120875c`, 4 Nov. Tiling, 23 Oct, revision not recorded. Stage Manager: none | AP-6 |
| SET-4 | Link to System Settings and never change macOS settings | Built: read-only `SetupProbe` | None | Native, as SET-3 | AP-6 |
| SET-5 | An unreadable setting shows **Not checked**, never passed | Built | `SetupCheckerTests` | None | AP-7 |

### Configuration

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| CFG-1 | Separate configuration and process identities, and standalone Paneru's files untouched | Built: `EnginePaths.environment` | `ConfigurationTests` | None | AC-6 |
| CFG-2 | Valid changes apply at once and persist, including external edits | Built: `ConfigurationStore`, `ConfigurationWatcher` | `ConfigurationTests` | Native, external edit for #26, 26 Oct, engine `03a7420`, app revision not recorded | AC-1 to AC-3 |
| CFG-3 | Invalid TOML keeps the last valid settings and shows the error and its line | Built | `ConfigurationTests` | Native, #221 branch on `e8d69276`, 2 Nov | AC-4 |
| CFG-4 | A write failure is reported, and the last valid settings stay | Built: `.unwritable` | `BindingsTests` | None | AC-5 |
| CFG-5 | Upgrades back up the file first and keep user values | Partly: a backup is made only when the default shortcut version changes or on Reset | `BindingsTests`, `ShortcutsTests` | Native, version 4 to 5 migration of Sam's file on `554a4fc9`, run `20261104-225455` | AC-8 |
| CFG-6 | A migration that cannot keep user values leaves the file and shows an error | Built for shortcut migration | `BindingsTests` | None | AC-9 |

### Supported platforms

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| PLT-1 | macOS 27 or later on Apple silicon | Built: `Package.swift`, `scripts/build-app.sh` | `scripts/check-compat.py` | Every native run, on macOS 27 | None |

### Multiple monitors

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| MON-1 | One strip per display and native Space, with independent order, focus, and scroll | Built | `ET/display.rs`, `ET/mission_control.rs` | Hand, `0b596031`: a swipe on each display moved only its strip, 3 Nov | HQ-2, HA-5 |
| MON-2 | Native fullscreen windows stay unmanaged and return to their column | Built: `E/ecs/workspace.rs` | `ET/interaction.rs` `native_fullscreen_transition_removes_window_from_original_strip_without_focus_marker` | None | HD-7 |
| MON-3 | A swipe moves the strip under the pointer by default | **Not built.** The engine moves the active display's strip | None | None. Sam's swipes on `0b596031` on 3 Nov did not separate the pointer's display from the active display | S-1, [#212](https://github.com/samanyudas/miri/issues/212) |
| MON-4 | A setting chooses the focused window's strip instead | **Not built** | None | None | S-1, [#212](https://github.com/samanyudas/miri/issues/212) |
| MON-5 | Keyboard commands act on the focused strip | Built | Engine tests | Native, `c4ba432e`, 5 Nov | AS-4 |
| MON-6 | Virtual workspaces off, with their commands and indicator hidden | Built | `ConfigurationTests` | None | AS-12 |
| MON-7 | Horizontal and vertical arrangements | Built | `ET/display.rs`, `ET/side_by_side.rs` | Native, `c356ad7a`, run `20261103-021450`: 20 of 20 arrangement steps. External display below the laptop: none | HA-1 to HA-3, HQ-1 |
| MON-8 | Mixed arrangements on three displays | Built in the engine | Engine tests | None. Needs a friend's three-display Mac | HA-1 to HA-6 on that Mac |
| MON-9 | Directional monitor focus and move, and nothing moves toward a side with no display | Built | `BindingsTests`, `ET/display.rs` | Native, `554a4fc9` and `c4ba432e`, 4 Nov | HM-1 to HM-3, HQ-3 |
| MON-10 | Focus and Move column cross to a touching display at the strip's end ([#104](https://github.com/samanyudas/miri/issues/104)) | Built | `ET/column_moves.rs` | Native, `c4ba432e`, 4 Nov. Sam's side-by-side hand check is open | HQ-3 |
| MON-11 | Off-screen windows stay on their own display | Built: `E/ecs/shared_edge.rs` | `ET/side_by_side.rs` | Native, `c356ad7a`, 3 Nov | HQ-1, HA-4 |

### Display changes

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| DSP-1 | On disconnect, strips follow their Space and keep their order | Built | `ET/reconnect.rs` | Hand, cable unplug, 28 Oct, engine `e1705af`, app revision not recorded | HQ-4, HD-1 |
| DSP-2 | On reconnect, each window returns to its display, column, and stack, and unmoved windows keep their place | Built: `E/ecs/display_homes.rs` | `ET/reconnect.rs` | Hand, one cable replug on `c356ad7a`, 3 Nov. [#265](https://github.com/samanyudas/miri/issues/265) is not reproduced | HQ-4, HD-1 |
| DSP-3 | The same for lid close and open | Built | `ET/reconnect.rs` | Hand, lid cycle with a stack on `37abded6`, engine `200109e`, 5 Nov | HQ-5, HD-2 |
| DSP-4 | The same for sleep and wake | Built | None specific | Hand, one sleep and wake, 16 of 16 windows, on `fabf16d4`, engine `589b44b`, 1 Nov. [#144](https://github.com/samanyudas/miri/issues/144) changed this path on 5 Nov | HQ-6, HD-3 |
| DSP-5 | A strip that cannot re-attach floats its windows | Built | `ET/reconnect.rs` | None | None |
| DSP-6 | Display rearrangement, main display, resolution, and fullscreen changes keep every window reachable | Built | `ET/reconnect.rs` | Native, Arrange sheet drags on `d77f8d46`, 3 Nov: 1 failure in 36, accepted as a limitation | HD-4 to HD-7 |

### Strip gestures

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| GES-1 | Three fingers, four fingers, or Off, and five fingers unavailable | Built: `StripGesture` | `GestureTests` | Native, `e120875c`, 4 Nov | AG-1 |
| GES-2 | Initial setup recommends four fingers and enables it only when verified | Built: `SM/InitialSetup.swift` | `GestureTests` | Native, `050bac63`, 1 Nov. Hand, Sam's four-finger test, 1 Nov | AG-2, AG-3 |
| GES-3 | The strip follows the fingers, with a saved setting to reverse it | Built | `ConfigurationTests` | Hand, four-finger swipes on two displays on `0b596031`, 3 Nov. Reverse: none | AG-4, AG-5 |
| GES-4 | A confirmed conflict turns the swipe off and shows steps, and never changes macOS | Built | `GestureTests` | Native, `050bac63`, 1 Nov | AG-7, AG-12 |
| GES-5 | **Unable to verify** offers a gesture test, and only movement plus confirmation counts as **Verified by user test** | Built: `SM/GestureTest.swift` | `GestureTests` | Hand, Sam's three-finger test, 1 Nov, revision not recorded | AG-8, AG-9, AG-11 |
| GES-6 | The result survives restarts and is invalidated by finger, direction, macOS, engine, or macOS gesture changes, or a user report | Built: `GestureState.evaluate` | `GestureTests` | None | AG-10, AG-13 to AG-15 |
| GES-7 | Keyboard management continues while the swipe is Off | Built | None | None | AG-6, AG-16 |

### Settling after a swipe

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| STL-1 | The strip settles on the column nearest the centre, counting momentum, and focuses it | Built: `E/ecs/scroll.rs` | `ET/settling.rs` | Native, Option-scroll stand-in, run `20261103-022523`, 3 Nov, app revision not recorded. No real trackpad settling is recorded | S-3 |
| STL-2 | No empty space past an end, a stack lands on its last-used window, and a strip that fits resists | Built | `ET/settling.rs` | None | S-3 |
| STL-3 | Modifier-scroll with a mouse wheel settles after a pause | Built | `ET/settling.rs` | Native, run `20261103-022523`, 3 Nov, app revision not recorded | S-3 |

### V1 interactions

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| INT-1 | Fixed-size windows and Miri's Settings float | Built | `ET/tiling.rs`, `ConfigurationTests` | Native, `d67550a` with engine `3bdae94`, the final #93 pass. [#249](https://github.com/samanyudas/miri/issues/249) and [#250](https://github.com/samanyudas/miri/issues/250) changed new-window handling on 5 Nov | AS-7 |
| INT-2 | Picture-in-Picture windows float above others, take focus once, stay on their display, and the player returns to its place | Built | `ET/tiling.rs` | Native, `a5853509` with engine `ee89647`, runs `20261105-220252` and `20261105-222020`. Hand, Sam's drags on engine `972a001`, the same tree as `ee89647` | AS-7 |
| INT-3 | Focus moves the strip only as far as needed, and Centre column still centres | Built | `ET/settling.rs` | Native, focus moves on `38b851c8`, 2 Nov. The distance moved was not measured | S-2, AS-8 |
| INT-4 | The layout reserves the visible Dock | Built | `ET/maximize.rs` | Native, Dock changes for #215, 1 Nov, engine `8b585cc`, app revision not recorded | AS-9 |
| INT-5 | Reduce Motion or the animation setting makes movement instant | Built | `ConfigurationTests`, `ET/settling.rs` | None | AS-10, AS-11 |
| INT-6 | A keyboard slide is an exponential ease-out that retargets from the remaining distance ([#278](https://github.com/samanyudas/miri/issues/278)) | Built: `ease_out_factor` | `ET` animation tests | Not recorded. [#280](https://github.com/samanyudas/miri/issues/280) reports a first-frame jump and is ready for an agent to reproduce on current `main` | None |
| INT-7 | Numbered jumps focus the stack's last-focused window | Built | `ET` column jump tests | Native, `c4ba432e`, run `20261105-160539` | AS-4 |
| INT-8 | The pointer alone does not change focus, and commands do not move the pointer ([#90](https://github.com/samanyudas/miri/issues/90)) | Built: engine defaults | `ET` focus tests | Native, engine `8fa68be`. Hand, `4798e5c` with engine `d4340b7`, for closing windows (#90) | None |
| INT-9 | ⌃⌥⌘ with arrows, HJKL, and WASD, and Shift to move | Built | `BindingsTests` | Native, `48b104e`, #79, 31 Oct. [#279](https://github.com/samanyudas/miri/issues/279) and #104 changed key handling on 4 Nov | AS-4 |
| INT-10 | Karabiner-Elements shortcuts work, and the recorder records a Hyper key chord ([#302](https://github.com/samanyudas/miri/issues/302)) | Partly: four-modifier chords parse, and nothing has run with Karabiner-Elements | `BindingsTests` | None | None |

### Stacks

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| STK-1 | Equal heights on membership change, set heights kept, and no overlap while windows fit | Built: `E/ecs/layout.rs` | `ET/stacks.rs` | Native, `0d878f80`, #124, 2 Nov | S-4 |
| STK-2 | Width rules for windows that cannot grow or shrink ([#93](https://github.com/samanyudas/miri/issues/93)) | Built | `ET/stacks.rs` | Native, `3710a40` with engine `4216682`, synthetic keys. #93 also records a hand check by Sam, revision not recorded | None |
| STK-3 | An overflowing stack overlaps only below each top bar, and the focused window comes forward | Built | `ET/stacks.rs`, `ET/focus.rs` | Native, `0d878f80`, 2 Nov. Sam's hand check is open | S-5 |
| STK-4 | Stack limit: default 5, never above what fits, Stack past it starts a column, and lowering it keeps existing stacks | Built: `StackLimit`, Layout picker | `ConfigurationTests`, `ET/stacks.rs` | Native, the `34f2f6d` tree with engine `f831216`, 24 Oct, and `stack_limit = "fit"` on `fd16a22` with engine `1fd95b1`, 27 Oct. Sam's hand check is open | S-7 |

### Dragging windows

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| DRG-1 | A title-bar drag moves only that window, on its display or another, to the target under the pointer ([#43](https://github.com/samanyudas/miri/issues/43), [#203](https://github.com/samanyudas/miri/issues/203)) | Built: `E/ecs/drag.rs` | `ET/drag.rs` | Hand, Sam's trackpad drags, 5 of 5, 1 Nov, engine `ffe0673` | S-6 |
| DRG-2 | Insertion lines, refusal with a not-allowed symbol, and the window returns | Built | `ET/drag.rs` | Hand, 31 Oct, engine `5e90388` | S-6 |
| DRG-3 | Edge holds scroll the strip, including over a column cut off at a shared edge ([#205](https://github.com/samanyudas/miri/issues/205)) | Built | `ET/drag.rs` | Native, synthetic drags, 31 Oct, revision not recorded | S-6 |
| DRG-4 | Floating windows never join the layout by drag | Built | `ET/drag` tests | Not recorded | S-6 |
| DRG-5 | If macOS tiles a dropped window, the engine returns it to its place | Partly: a drop on another display that macOS tiles is not undone ([#123](https://github.com/samanyudas/miri/issues/123), labelled `v2 blocker`) | `ET/drag` tests | Not recorded | S-6 |

### Maximizing a window

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| MAX-1 | ⌃⌥F and a title-bar double-click toggle a display-wide column that fills the usable area, and restore returns its width ([#88](https://github.com/samanyudas/miri/issues/88), [#106](https://github.com/samanyudas/miri/issues/106)) | Built: `E/ecs/maximize.rs` | `ET/maximize.rs` | Native, `fd16a22`, engine `1fd95b1`, 27 Oct | AS-15 |
| MAX-2 | A stacked window pops out on the side the setting chooses and returns on restore | Built | `ConfigurationTests`, `ET/maximize.rs` | Native, branch on engine `3fee523`, 27 Oct | AS-16 |
| MAX-3 | A `window_fullwidth` binding works as the maximize toggle | Built | `ShortcutsTests` | Native, branch on engine `3fee523`, 27 Oct | AS-17 |
| MAX-4 | Width, stack, float, edge drag, and drop rules for a maximized window | Built | `ET/maximize/restore_first.rs` | Native, `fd16a22` with engine `1fd95b1`, 27 Oct, #88 | AS-15 |
| MAX-5 | A display move keeps it maximized ([#87](https://github.com/samanyudas/miri/issues/87)) | Built | `ET/maximize.rs`, `ET/column_moves.rs` | Native, #87, 1 Nov, engine `8b585cc`, app revision not recorded | HR-3 |
| MAX-6 | The session restores it maximized after an engine restart | Built | `ET/maximize/session.rs` | Native, one display and no stack, engine `3fee523`, 27 Oct | HR-3 |

### System access and licence

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| SYS-1 | Accessibility permission only, with SIP on | Built | `SetupCheckerTests` | Native, `e120875c`, 4 Nov. Attribution on a Developer ID build is unresolved | AP-1, AP-2 |
| SYS-2 | Screen Recording only for the opt-in shared-edge switch, off by default | Built: `SC/ScreenRecording.swift` | `ScreenRecordingTests`, `ET/slice_photos.rs` | Hand, 29 and 30 Oct, #150, revision not recorded | None |
| SYS-3 | Each undocumented API has an assessment and a fallback | Partly: the review against the pinned engine is open | None | None | None |
| SYS-4 | Distributed source and licence notices follow GPL-3.0-or-later and keep Paneru's MIT notices | Partly: `LICENSE` exists, and no release exists to check | None | None | AR-3 |

### Signing, distribution, and updates

These rows are part of the denominator.
[Packaging, distribution, and endurance](#packaging-distribution-and-endurance) reports them in detail.

| ID | Requirement | Built | Tests | Latest native or hand evidence | Checks |
| --- | --- | --- | --- | --- | --- |
| DST-1 | A disk image signed with Developer ID | **Not built** | None | None | AR-1 |
| DST-2 | Notarized by Apple | **Not built** | None | None | AR-1 |
| DST-3 | Sparkle updates that also deliver engine upgrades | **Not built** | None | None | AU-2 |
| DST-4 | A daily check that asks before installing, and an optional silent install at startup | **Not built** | None | None | AU-1, AU-2 |
| DST-5 | A Homebrew cask | **Not built** | None | None | AR-2 |
| DST-6 | Development builds as Miri Developer with their own bundle IDs and local signing | Built: `scripts/build-app.sh` | `scripts/check-compat.py` | Every native run | None |

## Observed on the audited revision

`verify-miri` run `20261106-090237` on 6 November 2026 drove the tested artifact on the hardware above.
Each line is an automated native observation with synthetic input.
None of them passes a ledger check, because none ran on a frozen release candidate.

| Step | Result |
| --- | --- |
| Open three resizable AXFixture windows, 380 points wide | Each tiled at 388 points on a 2560-point display. LAY-3 expects 1280 points. Filed as [#305](https://github.com/samanyudas/miri/issues/305). |
| Press ⌃⌥Q | The status read `Stopped`, `managementStopped` was `1`, and the engine exited 0.8 s after the press. |
| Read every window frame while stopped | All 12 windows lay inside the two displays. |
| Relaunch while stopped | No engine started, and Settings showed `Stopped`. |
| Press Start Window Management | The status read `Managing windows`, and `managementStopped` was `0`. |
| `kill -9` the engine with Settings open | A new engine started 1.8 s later under the same app, the session restore matched 12 windows, and all three fixture frames were unchanged. |
| `V end` | Sam's build relaunched, and the layout check found all 9 of Sam's windows where they were at the start. |

The 6 November run did not drive Restart, the crash limit, Quit, setup checks, or shortcut editing.
Run `20261105-160539` on `c4ba432e` drove all of them except Quit.
The app code for the lifecycle, setup checks, and shortcut editing is unchanged from `c4ba432e` to `6edff137`, and only the engine pin moved.

## Partial behavior, missing checks, known failures, and stale evidence

### Known failures

- New windows keep their own width instead of 50% ([#305](https://github.com/samanyudas/miri/issues/305), observed on `6edff137`).
- A drop on another display that macOS then tiles stays tiled ([#123](https://github.com/samanyudas/miri/issues/123), labelled `v2 blocker`).
- One Arrange sheet drag in 36 moved System Settings into the other display's strip. Sam accepted it as a limitation when [#103](https://github.com/samanyudas/miri/issues/103) closed.
- The engine test `slice_photos::a_press_while_a_revealed_photo_waits_never_shows_its_window_beside_it` is flaky in CI.

### Reports not reproduced

[#78](https://github.com/samanyudas/miri/issues/78), [#122](https://github.com/samanyudas/miri/issues/122), [#166](https://github.com/samanyudas/miri/issues/166), [#177](https://github.com/samanyudas/miri/issues/177), [#210](https://github.com/samanyudas/miri/issues/210), [#265](https://github.com/samanyudas/miri/issues/265), and [#280](https://github.com/samanyudas/miri/issues/280) are open without a reproduction on a current build.

### Checks with no evidence on any revision

AP-3, AP-4 for tools other than the four detected, AP-5, AP-7, AL-1, AL-4, AW-1, AW-2 with windows known to be off screen, AW-6, AC-2, AC-5, AC-6, AS-5 as a pass, AS-10, AS-12, AG-16, AU-1, AU-2, AU-4, AU-5, AR-1 to AR-3, HA-3, HD-1 to HD-3 at their required counts, HD-5 to HD-7, HR-1, HE-1, and HE-2.

### Stale evidence and records

- Every native and hand result in the map, except the 6 November run, predates `a5853509`.
  Later changes touched key handling (#279 and #104, 4 Nov), startup focus (#248, 4 Nov), stack rejoining across Spaces (#144, 5 Nov), and new-window tiling (#249 and #250, 5 Nov).
- [Known limitations](limitations.md) still names `main` at `fabf16d4` and engine `589b44b` as its baseline.
  It lists the Mission Control drag as a confirmed defect, but [#143](https://github.com/samanyudas/miri/issues/143) closed with a verified fix on 3 November.
  It lists swipe lag as a confirmed defect, but [#66](https://github.com/samanyudas/miri/issues/66) closed as not planned on 5 November, after Sam could no longer reproduce it.
  It lists the 8-point drag gap as a confirmed defect, but [#122](https://github.com/samanyudas/miri/issues/122) did not reproduce on `6edff137`.
- [Design tree status](../decisions/design-tree-status.md) says it was reconciled with `main` at `e516edd` on 20 October.
- #302 moved Hyper key recording into v1 on 5 November, but release scope, the keybinding reference, the v2 roadmap, design tree status, and the v1 specification still defer it to v2.
- [#278](https://github.com/samanyudas/miri/issues/278) is still open, although Sam decided it and [#282](https://github.com/samanyudas/miri/pull/282) is merged.
- These closed issues left acceptance boxes unticked, or their closing comments name a hand check that is still open: [#42](https://github.com/samanyudas/miri/issues/42), [#43](https://github.com/samanyudas/miri/issues/43), [#44](https://github.com/samanyudas/miri/issues/44), [#106](https://github.com/samanyudas/miri/issues/106), [#159](https://github.com/samanyudas/miri/issues/159), [#183](https://github.com/samanyudas/miri/issues/183), [#199](https://github.com/samanyudas/miri/issues/199), [#205](https://github.com/samanyudas/miri/issues/205), and [#219](https://github.com/samanyudas/miri/issues/219).

## Remaining blockers

Owners come from issue comments and PROGRESS.md.
No issue has an assignee.

| Blocker | Next concrete action | Owner |
| --- | --- | --- |
| Apple Developer Program enrollment | Enroll, so Developer ID signing and notarization can start | Sam |
| [#82](https://github.com/samanyudas/miri/issues/82) signing, notarization, Sparkle, release disk image, Homebrew cask | Split it into child tasks, with the steps that need Sam's Apple account labelled `ready-for-human` | Agent to split, Sam for account steps |
| Accessibility attribution on a Developer ID build | Grant permission to the first signed, notarized build and check both the app and the engine | Sam |
| [#305](https://github.com/samanyudas/miri/issues/305) new windows at 50% width | Triage, then build the engine rule for newly created windows only | Sam to triage, then agent |
| [#212](https://github.com/samanyudas/miri/issues/212) swipe under the pointer and its setting | Triage, then build the engine target, the configuration key, and the Settings control | Sam to triage, then agent |
| [#201](https://github.com/samanyudas/miri/issues/201) launch at login state | Build the login item state in Settings, then check a log out and log in | Agent to build, Sam to log out and in |
| [#302](https://github.com/samanyudas/miri/issues/302) Karabiner-Elements and Hyper key | Update the five decision documents, then run the manual checks with Karabiner-Elements | Agent for documents, Sam for the manual checks |
| [#104](https://github.com/samanyudas/miri/issues/104) display crossing | Hand check side by side, then close | Sam |
| S-5 and S-7 stack overflow and limit | Hand check on the frozen candidate | Sam |
| Real trackpad gestures and settling, S-1, S-3, AG-4 | Run with a real trackpad on the frozen candidate | Sam |
| Release candidate | Freeze a candidate after the items above, then run the app and multi-monitor checklists 3 times in a row | Agent for app checks, Sam for hardware checks |
| Memory-stability rule for HE-1 | Define a measurable pass rule | Unknown |
| Endurance HE-1 and HE-2, and Q6 | See [Packaging, distribution, and endurance](#packaging-distribution-and-endurance) | Sam |
| Configuration keys, validation ranges, and private API fallbacks | Review them against the pinned engine, as design tree status lists | Agent |
| DRG-5: release scope says the engine undoes macOS tiling after a drop, but [#123](https://github.com/samanyudas/miri/issues/123), the cross-display case, is labelled `v2 blocker` | Decide whether the cross-display case is v1, then fix it or record the deferral in release scope | Sam to decide, then agent |
| Flaky engine test | Make the slice photo test deterministic | Agent |

## Packaging, distribution, and endurance

These requirements gate a public release, not feature completion.

| Requirement | State on `6edff137` | Evidence |
| --- | --- | --- |
| Development disk image | `make package` builds a development disk image of `Miri Developer.app` | CI run [42036549784](https://github.com/samanyudas/miri/actions/runs/42036549784), job "Build, selftest, and package on macOS 27" |
| Release disk image, signed with Developer ID | Not built. `scripts/build-app.sh` signs with the local identity or ad hoc | No `notarytool` or `stapler` call in `scripts/` |
| Notarization | Not built | As above |
| Sparkle updates and the update policy | Not built | No Sparkle code in `Sources/` or `Package.swift` |
| Homebrew cask | Not built | No cask file in the repository |
| Release bundle IDs | Partly: the engine has a release Info.plist, and no script builds the release app | `vendor/paneru/assets/Info.plist` |
| Distributed source and licence notices | Not checked, because no release exists | AR-3 |
| 8-hour session with two displays, stable engine memory | Not run, and no memory-stability rule exists | HE-1 |
| 2-week daily use at both locations without a lost window or repeated crashes | Not started. A bug that loses windows restarts the period | HE-2 |
| 3 consecutive full checklist runs on the release candidate | 0 of 3 | [Acceptance ledger](acceptance-ledger.md#release-candidate) |

### Q6

Release scope describes one 2-week daily-use period across both locations.
The multi-monitor checklist requires 3 consecutive full runs, and each full run includes that 2-week period, which implies 6 weeks.
Q6 asks how the two combine.
On 15 October 2026, Sam deferred Q6 to the final check before publishing v1, as [design tree status](../decisions/design-tree-status.md#open-product-decisions) and the [v1 specification](specs/miri-v1.md) record.
Until then, both requirements stay as written.
This audit keeps Q6 deferred, and nothing on this page depends on its answer.

## The 17 feedback requests

[#77](https://github.com/samanyudas/miri/issues/77) to [#93](https://github.com/samanyudas/miri/issues/93) came from 17 points of feedback, one issue per point.
Their own text puts 13 in v1, of which 10 are release blockers, and 4 in v2.
#83 is this audit.

| Issue | Release in the issue | In accepted v1 scope | State |
| --- | --- | --- | --- |
| #77 Picture-in-Picture | v1 blocker | Yes, V1 interactions | Closed |
| #78 Interaction delays | v1, not a blocker | Not in release scope | Open, not reproduced |
| #79 Arrow, HJKL, and WASD | v1 blocker | Yes, V1 interactions | Closed |
| #80 Reveal overflow stacks | v2 | No | Open |
| #81 First-run tour | v2 | No, the tutorial is deferred | Open |
| #82 Release delivery | v1 blocker | Yes, Signing, distribution, and updates | Open |
| #83 This audit | v1, not a blocker | Not a product requirement | Open |
| #84 Stack creation and reset | v2 | No | Open |
| #85 Missing windows | v1 blocker | Not a separate rule | Closed |
| #86 Liquid Glass drag feedback | v2 | No | Open |
| #87 Maximized windows across displays | v1 blocker | Yes, Maximizing a window | Closed |
| #88 Double-click to maximize | v1 blocker | Yes, Maximizing a window | Closed |
| #89 One strip per display and Space | v1 blocker | Yes, Multiple monitors | Closed |
| #90 Focus independent of the pointer | v1 blocker | Yes, V1 interactions | Closed |
| #91 Limitations inventory | v1, not a blocker | Not a product requirement | Closed |
| #92 Bracket directions | v1 blocker | Yes, through the keybinding reference | Closed |
| #93 Constrained window sizes | v1 blocker | Yes, Stacks | Closed |
