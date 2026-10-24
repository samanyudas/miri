# Progress

Updated: 2026-10-24 on branch `docs/finder-stack-limitation`, based on `main` at `f9d76ea`

This file records in-flight state and the handoff between sessions.
Product decisions live in `decisions/`, architecture in `docs/adr/`, and tasks in GitHub Issues.
Update it at the end of every session and in any PR that changes what is done or next.

## Objective

Reach a working v1 app that manages windows through the bundled engine, as defined in [release scope](decisions/release-scope.md).
The app foundation, engine integration, configuration, default shortcuts, shortcut customization, and gesture controls are merged.
The current milestone is the remaining v1 features: pointer-versus-focus gesture targeting and drag insertion into a stack.
The stack limit and stack overflow are built and await their hardware checks.
The public release path and the complete acceptance runs follow.

## Stack ordering and window admission repairs

[Engine PR #32](https://github.com/samanyudas/paneru/pull/32) merged into `miri/v0.5.2` as `50f49fc` for #42.
It keeps an overlapping stack of windows from different apps in order after focus changes.
`AXRaise` returns before a background app reorders its window, and it places that window just below the frontmost app's windows.
The engine now raises only windows that need to move, waits up to 50 ms for each raise to show, and waits up to 500 ms for the focused window to show in front.
Native focus walks with four fixture apps failed 7 of 12 steps on `9ac7ec7` and passed 96 of 96 on the fix.
While Finder is frontmost with no window, the previously focused stack window can remain in front instead of returning to its overlapped place.
The bounded focus-first experiment on 24 October used four native fixture apps and returned focus to Finder after activating each app in stack order.
The captured run left the wrong order without pauses and restored D1, C1, B1, A1 with 50 ms and 150 ms pauses.
The helper at `/tmp/miri-42/ff.swift` sets `AXFrontmost` for each app and then Finder.
It does not issue a separate `AXRaise`, so this records activation with the running engine rather than an isolated focus-and-raise implementation.
The workaround would take focus from Finder while cycling through the apps.
No engine change is included, and the Finder limitation is recorded in [release scope](decisions/release-scope.md#stacks).
Sam limited this investigation to one workaround attempt, so it ends here.
These results come from the prior session's captured output, not a fresh native run.
Two windows of one app with another app's window between them still cannot be fully ordered.

[Engine PR #33](https://github.com/samanyudas/paneru/pull/33) merged as `f831216` for #59.
macOS can announce a launch before `NSRunningApplication` knows the process, and the engine now looks it up again instead of dropping the process after 5 s.
An app that shows no window within 10 s now stays managed, so a later window enters the layout.
The float command now toggles a window only when macOS reports it focused in the frontmost app.
Native launch probes missed none of 320 ordinary windows, a window shown 12 s after launch was managed after 13 s, and the float key ignored an unmanaged focused window.
An app whose observers cannot register for 5 s is still dropped, and an app that keeps its main thread blocked can wait for a later event.

Both engine PRs passed two Sol rounds and scored 5/5 in Greptile.
This branch pins `f831216`.

## Previous acceptance repairs

[Engine PR #31](https://github.com/samanyudas/paneru/pull/31) merged into `miri/v0.5.2` as `9ac7ec7ef6bd4ecd60bca4019e40a22730b25cf5`.
[Miri PR #61](https://github.com/samanyudas/miri/pull/61) merged as `3898f6fd8e3f27bc6b4f7eab0a3e43d43c2797a9` and pins this published revision.
It keeps size-refusing stack windows on the display where the engine placed them.
It also exposes the eligible focused survivor after removal and preserves focus when a background window is destroyed.
The visibility request waits for scrolling or drag placement to finish and then checks the current focus.
Keyboard focus placement and workspace restoration retain control.
[Issue #60](https://github.com/samanyudas/miri/issues/60) tracks the close and visibility failure.

Sol approved the source and tests after five bounded review rounds.
Greptile reviewed the final engine revision at 5/5, and both PR checks passed.
Independent native verification returned PASS+NOTES on engine `1cbb987` before its tree-identical squash merge.
The verifier reproduced BASE moving a constrained window to the built-in display, stealing focus after background close, and leaving a focused survivor at x=-32.
The candidate retained the external display and focus, and corrected the survivor to x=8.
Native AX close, SIGTERM, graceful quit, and synthetic modifier-scroll checks passed within their recorded scope.
Physical touchpad behavior and exact native swipe timing remain unverified.
The engine passes 41 library and 759 binary tests without defaults, and 52 library and 849 binary tests with defaults.
Formatting and strict Clippy pass in both configurations.
Miri's full `make check` passes with the published pin.
This includes compatibility, 144 Swift tests, 41 library and 759 engine tests, strict lint, the signed build, permission observation, window recovery, and DMG packaging.
Sol approved the three-file Miri integration and verified parser compatibility and the minimum-height wording.
Independent verification of the final Miri artifact returned PASS+NOTES on `1fcfa57`, whose tree matches the merged revision.
The signed app and read-only DMG match completely, and fresh native closes preserve focus and final visibility.
All integration PR checks passed before merging.
Both PR watchers are stopped, and the verified app remains running with one engine child.
The DMG inspection left a nonblocking installation prompt that computer use could not inspect because it timed out.
No installation occurred.

The macOS tiling setup check already merged in [PR #57](https://github.com/samanyudas/miri/pull/57) as `601b056`.
The keybinding reference now distinguishes a 200-point layout slot from its 192-point native window with default gaps.
The overlap-order retry prototype failed 6 of 12 native focus steps and was removed from the shipping diff.
Overlap ordering and the documented stack-focus switch remain unresolved under #42.
[Issue #59](https://github.com/samanyudas/miri/issues/59) tracks intermittent window discovery and remains unfixed.
[Issue #58](https://github.com/samanyudas/miri/issues/58) separately tracks macOS tile height.
These changes do not complete frozen-release acceptance.
The evidence and decision trail remain in `.audit/acceptance-pickup/` in the repair worktree.

## Done

- `branding/window-mark` replaces the README's pink M logo with the blue and violet window mark.
  `assets/` also contains running and stopped menu bar SVGs and usage notes.
  SVG parsing and a browser preview passed for all three assets, including the menu bar marks on light and dark backgrounds.
  `make lint` passed on current `main` plus these assets, including all 18 harness tests.
  `make native` was skipped because this change contains only SVG assets and documentation.
  The native app does not yet load these assets, and the Paper UI screens remain unexported because Paper Desktop was closed.
- The v1 specification and product decisions are merged (#3).
- The Accessibility permission prototype is merged (#4).
  Enabling only the Miri entry authorizes both the app and its engine in the development build.
- The development harness is merged (#10), tracked by #9.
- PR #11, the Miri Developer identity, merged into `chore/repo-harness` after #10 had already merged that branch.
  Its commits never reached `main`, so `feat/v1-app-core` carries them.
- `feat/v1-app-core` adds the first production app slice:
  - `MiriCore`, a tested library with a TOML 1.0 parser that edits single values without touching the rest of the file.
  - Miri-owned `config.toml` with the accepted defaults and derived engine keys for gaps, presets, animation, and floating Settings.
  - An engine supervisor with an isolated environment, bounded logs, and a three-crashes-in-five-minutes restart limit.
  - App-side window recovery after every engine exit, verified live against the fixture window.
  - A setup checker, redacted diagnostics with a preview, and the menu bar and Settings UI.
- The engine fork change samanyudas/paneru#5 hides the engine's menu bar item through `[decorations.menu].visible`, which Miri sets to `false`.
  It also creates a missing `PANERU_CONFIG` file in place instead of falling back to standalone Paneru's files.
- The engine fork change samanyudas/paneru#6 makes stacking move only the focused window, in both directions, and adds pop-out to the left.
  It also stops a stack command next to a fullscreen column from dropping windows out of the layout.
- Sam decided on 15 October 2026 that stacking moves only the focused window, and deferred Q6 to the final pre-release check.
- PR #12, the first production app slice, merged into `main` on 15 October 2026 with #13 still open.
- samanyudas/paneru#7 merged into `miri/v0.5.2` on 16 October 2026 as engine `0341353`.
  It fixes #14: Stop and Quit no longer move floating, minimized, or hidden windows.
- Sam decided on 16 October 2026 that a current floating rule wins over a saved tiled placement (#15).
  samanyudas/paneru#8 merged into `miri/v0.5.2` on 16 October 2026 as engine `39def42`, which does this.
  A live run on the built-in display confirmed that a floating rule now wins after a restart.
- The issue lifecycle job that labels issues a merged PR references failed with HTTP 403 on every merge until #18.
  Its token lacked `pull-requests: read`. A harness test now checks each workflow job's scopes against its API calls.
- The release, timed-close, and reopen stages of the issue lifecycle have not run live, because no stable release exists.
  A harness test runs their real job scripts against a fake `gh`.
  A dispatched run of the close job passed on `main` on 16 October 2026.
  No issue carried `please confirm close`, so that run proved only that the job starts with its permissions and its script parses.
- On 16 October 2026, `make check` passed on `main`, and a live headless Claude session showed the guard block a push to `main`, a force push, a PR merge, a release, `tccutil reset`, and `defaults write`.
- #13 shrank a window in 1 of 35 runs, across the built-in display and a 2560 x 1440 external display.
  The engine requested only height changes in every run.
  After a screen lock, three windows were at exactly half width, and no engine had run since their last check.
  macOS tiling is the main suspect, but Sam may have moved them, so this is not confirmed.
  #13 was closed as completed on 16 October 2026 after these runs.
- `feat/default-bindings` writes the accepted default shortcuts to `[bindings]` from one table in `Sources/MiriCore/Bindings.swift`.
  A new install gets the full set.
  An existing file gets each default whose engine command it does not bind under any alias, with only the default's free chords.
  `[miri].default_bindings_version` records the offer, so Miri never re-adds a binding the user deleted.
  A live run on 16 October 2026 sent all 43 bound chords as synthetic key events, and the engine ran each command.
  The engine's behavior differed from the accepted behavior only where the engine mapping records it, such as a numbered jump into a stacked column focusing the top window instead of the last-focused one.
  Some actions stay unbound or behave differently, as the [engine mapping](decisions/keybinding%20reference.md#engine-mapping) records.
- PR #27 merged into `main` on 18 October 2026 and pins engine `3455e37` on `miri/v0.5.2`, the squash merge of samanyudas/paneru#11, which follows samanyudas/paneru#9 and #10.
  The engine adds five-percentage-point resize steps (#22), directional display focus and move (#23), and column jumps that return to a stack's last-focused window (#24).
  It drops a binding whose key name it does not know, instead of binding the A key (#26).
  Vertical focus and swap no longer cross to another display at a column's edge.
  Display focus preserves the selected virtual workspace and skips background native tabs.
  The Lua display commands reject positional directions.
  The merge also brought window-recovery fixes that preserve window state and geometry when an Accessibility handle is replaced.
  Miri's default set is now version 2. An upgrade replaces the four version 1 resize bindings only where they still have Miri's value.
  Miri reports a binding the engine cannot read, and owns ⌃⌥Q for Stop (#25).
  On 16 October 2026 the built app upgraded Sam's real version 1 file as designed, and the engine parsed all 51 bindings in it.
- samanyudas/paneru#10, merged as `0010611`, fixes a Rust 1.98.1 Clippy `float_cmp` error that `67debbc` introduced in a recovery test.
  On 17 October 2026, `make lint`, Swift lint, 69 Swift tests, the app build, and both end-to-end checks passed at `67debbc`, which has the same source apart from that test.
- A live run on 15 October 2026 on the built-in display only confirmed Start, 8-point gaps on all sides and between windows, Stop, crash recovery and restart, the three-crash limit, manual restart, and Quit.
- A 16 October 2026 hardware run of the PR #9 engine used an external 2560 x 1440 monitor above the built-in display.
  Sam confirmed horizontal growth and the South move, North focus, and South focus shortcuts.
  The recorder saw Fixture 0 move between displays and grow from 500 to 756 points, which matches two 128-point steps.
  Sam paused the run before the East and West check, which PR #27 later completed.
  Evidence is in `.build/artifacts/pr9-hardware-evidence/`.
  Fixture test helpers remain in `.build/artifacts/pr9-hardware-runtime/` and are reusable for native checks.
- PR #27 also fixes default upgrades, exact configuration backups, and Stop ownership for usable and rejected engine bindings.
  Its description records the full verification, and the append-only decision trail is `.audit/pr27-full-stop-20261017.tsv`.
  Sam physically confirmed width spacing, stacked-height growth, stack jump returns, ordinary Stop, Stop after a rejected reload, and the mistyped-key check.
  Sam physically confirmed all four horizontal and all four vertical display actions at engine `6e572ea`, whose tree matches `3455e37`.
  The horizontal check had the laptop left of the external monitor with top edges aligned.
  The vertical check had the external monitor above the laptop with left edges aligned.
  Both physical checks used fixture animation speed `1000`, and separate native replays passed at speed `14` with Fixture 0 and TextEdit.
  The confirmations are `.audit/pr27-hardware/horizontal-6e572ea-confirmation.json` and `.audit/pr27-hardware/vertical-6e572ea-confirmation.json`.
- PR #29 pins engine `a15682f`, the merge of samanyudas/paneru#12, which fixes #28.
  The engine now builds a native frame from its rounded origin and size, so odd widths and heights stay exact.
  A native gap check on 18 October 2026 used four fixture windows with 4-point window and edge padding, then resized the leftmost window to 629 points.
  Engine `3455e37` recorded width 636, and the native gap to its neighbour was 7 points.
  Engine `a15682f` recorded native X=8 and width 629 as x=4 and width 637, and every native gap stayed 8 points.

- `feat/shortcut-settings` adds the Shortcuts settings page.
  It records a chord through an event tap at the head of the HID event stream, so it also sees chords the engine binds.
  Each action lists several chords, and each chord has its own remove button.
  The page rejects a chord that another Miri action, Stop, or an unlisted engine command already uses, and the file stays unchanged.
  It warns before it takes a shortcut that macOS uses.
  That list is the live System Settings shortcuts merged over built-in defaults, plus standard app shortcuts.
  Reset to Defaults backs up the file, replaces `[bindings]` with the default set, and restores ⌃⌥Q for Stop.
  Stop is customizable in `[miri].stop_shortcut`.
  When the keyboard layout changes, Miri registers Stop again and restarts a running engine, because the engine reads the layout only when it starts.
  A default-binding upgrade never takes a chord that presses the same key as a Stop chord or a user binding under the active layout.
  Key names resolve through the active layout in the engine's order, so AZERTY, QWERTZ, and Dvorak record the key the engine binds.
  Unit tests pin key names and round trips on the US, French, German, and Dvorak layouts.
  On 18 October 2026 a built app ran with management stopped and a temporary home folder.
  Synthetic HID key events showed the rejection messages, the macOS conflict alert, adding a Stop chord, and the unusable-key message.
  They also showed that Escape and switching apps cancel recording, and that reset writes a backup.
  A second run on 18 October 2026 used the same temporary home folder with the engine running.
  While recording, the page caught ⌃⌥T and showed "⌃⌥T is already used by Float or unfloat focused window.", and the engine did not act.
  A recorded Stop chord, ⌃⌥⇧P, stopped management when pressed.
  With French, German, and Dvorak each selected, the recorder wrote `ctrl+alt+shift-a`, `-q`, and `-'` for the key at the US Q position.
  A freshly started engine ran each recorded binding.
  With the engine running, switching to French and back to Australian restarted the engine each time, with process IDs 5840, 6259, and 6268.
  On AZERTY the default digit shortcuts, such as ⌃⌥1, reach the keypad digits, because the top row types symbols without Shift.
  The page labels them as keypad keys, and [#31](https://github.com/samanyudas/miri/issues/31) tracks the engine fix.
  GPT-6.1 Sol reviewed the branch in four rounds and approved it after the layout restart and the upgrade fixes.
- `feat/gesture-controls` is phase 3a, the strip gesture controls without pointer-versus-focus targeting.
  Settings has a Gestures tab with Off, Three fingers, and Four fingers (recommended), and Reverse swipe direction.
  `[miri].strip_gesture` defaults to Off, and `[miri].reverse_swipe` sets `[swipe.gesture].direction`.
  `GestureState.evaluate` turns the swipe on only for a confirmed user test that matches the finger count, direction, macOS version, engine revision, and readable macOS gesture settings.
  A confirmed macOS conflict always keeps it off, and automatic detection never turns it on.
  Miri writes `[swipe.gesture].fingers_count` only while the swipe is on or a test runs, sets `vertical = false`, and removes the legacy `[options]` swipe keys.
  The gesture test polls `miri-engine query state --json`, needs the strip to slide both ways, fails on a Space switch, and saves a result only after the user confirms it.
  The result lives in user defaults, and Report a macOS Gesture Change deletes it.
  Unit tests cover the state table, the file keys, the result's JSON, and the movement detector.
  Changing the finger count, direction, macOS version, engine revision, or a readable macOS gesture setting deletes the saved result, even while the swipe is Off, so changing back needs a new test.
  The four-finger setup check no longer reports a conflict when macOS keeps the four-finger value at 2 while full-screen swiping uses three fingers, as on Sam's Mac on 18 October 2026.
  On 18 October 2026 the built app showed the Gestures tab on screen with the swipe Off by default and both test buttons disabled, and its config had `direction = "Natural"`, `vertical = false`, and no `fingers_count`.
  No live trackpad check has run.
  GPT-6.1 Sol reviewed the branch in three rounds and approved it.
  [#33](https://github.com/samanyudas/miri/issues/33) tracks the engine helper outliving a dead app, which would keep a test swipe active until the next launch.

- PR #37 records the strip settling design, and PR #41 pins engine `491508e`, which implements it.
  A swipe settles on the column nearest the center where the flick would stop, and focus reveals only the hidden part of a column.
  The engine also keeps a column's anchor during preset width cycling (#39), and Quit and Stop return windows to their frames from before Miri started.
  A live check on Sam's Mac started and quit the engine with nine windows open, and all nine returned to their starting frames.
  No real trackpad check of settling has run.
- PR #45 records the stack rules Sam accepted on 19 October 2026 in [release scope](decisions/release-scope.md#stacks).
  PR #46 pins engine `579bc0b`, which gives stacked windows equal heights and stops a window with a minimum height from overlapping the next one (#40).
- PR #47 makes CI tolerate the `open -W` race in both selftests and retries `hdiutil` in DMG packaging.
- PR #50 pins engine `4b4705a`, which asks a slow app for focus again before it floats the window (#48).
- On 20 October 2026 a status audit compared `main` at `e516edd` with the v1 documentation.
  Sam settled the open #42, #43, and #44 questions on 20 October 2026, and the branch `docs/drag-and-overflow-decisions` records them in [release scope](decisions/release-scope.md#dragging-windows).
  Dragging to reorder columns and dragging between displays moved into v1.
  The branch `docs/reconcile-audit-20261020` corrects the stale status claims, adds the [acceptance ledger](docs/acceptance-ledger.md), and updates #42, #43, and #44.
- PRs #51 and #52 changed only documents, but each listed `Refs #42`, `Refs #43`, and `Refs #44`, so the issue lifecycle labelled all three `fixed (pending release)`.
  The labels were removed on 20 October 2026, and one wrong bot comment remains on each issue.
  `fix/refs-vs-part-of` adds `Part of #N` for decisions, docs, and partial work, which never labels an issue, and stops `Related to #N` from labelling one.
  A harness test reproduced the `Related to` labelling before the change and passes after it.
- `feat/stack-overflow` pins engine `db5bba3`, the merge of samanyudas/paneru#21, which implements stack overflow (#42).
  When a stack's minimum heights exceed its column, each lower window overlaps the window above it only below that window's top bar.
  The engine measures each top bar through Accessibility when a stack first overlaps, and again when the window loses focus or resizes.
  A window with no measurable top bar gets 52 points.
  When any Accessibility read fails, the engine keeps the last measured height, or 52 points if it has none, and tries again after a growing wait.
  The focused window comes to the front, and it returns to its place when focus leaves it.
  The engine also lays out a stack with more windows than fit at the 200-point minimum, which it used to leave out of the layout.
  Engine unit and harness tests cover the overlap, the fallback, the refresh and retry, the spill past the bottom, the window order, and the dropped column.
  A read-only Accessibility probe measured a 96-point top bar on Helium, the only app with a standard window open.
  No real desktop or hardware check has run, so acceptance check S-5 stays pending.
- `feat/stack-limit` delivers the stack limit (#44) with samanyudas/paneru#20, which adds the engine option `[options].stack_limit`.
  It holds a whole number from 1 or `"fit"`, defaults to `5`, and is capped at what fits in the column at 200 points on the active display.
  A Stack command into a full column moves the window out of its own stack into a new column between the two.
  A window that is already its own column stays put.
  Lowering the limit leaves existing stacks unchanged, and the engine reads the limit on every Stack command, so a hot reload applies to the next one.
  The engine rejects `0`, negative numbers, and other values with a parse error, and so does Miri, which reports `options.stack_limit`.
  `effective_stack_limit(config, column_height)` in the engine's `src/ecs/layout.rs` holds the cap, for reuse by drag insertion (#43).
  Settings has a Windows per stack picker on the Layout page, with Fit the display and the numbers from 1 to what fits on the main display.
  PR #54 pinned engine `9065569`, the merge of samanyudas/paneru#20 into `miri/v0.5.2`.
  On 20 October 2026, `make native` passed on `feat/stack-limit` with 141 Swift tests, 40 engine library tests, and 427 engine binary tests.
  Its permission selftest reported `observed-granted. Attribution unresolved.`, and its recovery selftest recovered the fixture window.
  Before the engine merge, `make lint` passed except `make compat`, which rejected the unpublished pin.
  Settings was not opened during that run.
  No hardware check has run, and the acceptance check is S-7 in the [acceptance ledger](docs/acceptance-ledger.md).
- PR #54 merged into `main` as `6a85fcf` on 21 October 2026 after Greptile scored its final head `87178e9` at 5/5 and CI passed.
  Independent verification passed 142 Swift tests, strict Swift lint, and `make lint`, including 19 harness tests and compatibility.
  A native fixture rendered the production Layout settings view with an isolated model and configuration file.
  The previous commit kept a stale capacity of 6 after a simulated display notification, while the merged view immediately showed 3 and preserved the configured count of 5.
  This did not change physical displays or run the engine.
  This branch merges that result and keeps engine `db5bba3`, which contains both stack limit and stack overflow.


- `feat/drag-insert-integration` starts from `main` at `49661a5` and pins engine merge `ffff464` from [samanyudas/paneru#29](https://github.com/samanyudas/paneru/pull/29), merged into `miri/v0.5.2` on 23 October 2026.
  This brings in the landed drag insertion and feedback changes from engine PRs #22, #23, and #28, together with part C from #29.
  Part C adds cross-display drops, outer-edge hold scrolling, and restoration after macOS tiles a managed window (#43).
  Native membership uses fresh window frames and preserves held drags, pending engine placement, and native tab groups.
  The engine also replays a held tab group's skipped layout when a press ends without a drop.
  The regression failed before the fix for lost release, pointer movement, and resize cancellation, and passes after the fix.
  The app also recognizes the engine's `showmenu` and `hidemenu` binding keys and rejects extra words, matching the updated engine parser.
  The compatibility guard still requires the engine pin to be published on `miri/v0.5.2`.
  The verified merge satisfies that ancestry requirement.
  Mock engine tests cover the drag behavior, including a neighboring display with a native fullscreen Space.
  Standalone engine `ee94515` passes all thirteen final native fixture lanes on two physical displays on 23 October 2026.
  These include both keyboard-resize lanes, Window menu Half, Quarter, and Fill, same-display gestures, and nine consecutive cross-display runs.
  Immediate Grow produces width 1920 after an app resize to 1600, replacing the previous wrong 1280.
  Cross-display runs preserve width ratios, equal 643-point stack shares, insertion feedback, refusal, and complete return geometry.
  All fourteen unrelated window frames stay unchanged in every lane, and strict foreground checks pass.
  Every owned process exits and the original frontmost app returns.
  Sam disabled Vorssaint's Focus Follows Mouse setting before these final runs.
  The final runs use the existing engine focus behavior.
  These checks use three owned AppKit windows and Sam-authorized synthetic CGEvent input, with Helium hidden and its session preserved.
  Successful drops now retire earlier native resize snapshots for every native-tab member.
  A fixture-driven native Half-sized resize followed by a drag now keeps its accepted destination.
  Its frame stays at (0,30), 1280 by 705, instead of returning to the earlier slot.
  Sol approved the full engine change after two rounds, with the stale snapshot finding resolved.
  Physical diagonal-edge behavior has source and mock coverage only.
  The integration pins verified merge `ffff464`, whose tree exactly matches the reviewed and natively tested `ee94515`.
  Acceptance check S-6 stays pending.
- `feat/setup-tiling-conflicts` adds the macOS tiling check that Sam decided for drag insertion (#43).
  The setup checker now reports **Drag windows to screen edges to tile**, **Drag windows to menu bar to fill screen**, and **Hold Option key while dragging windows to tile** when they are on.
  macOS stores these values only after a change, so an absent value counts as on, the macOS default.
  The check never blocks window management.
  On 23 October 2026 the built app showed Passed with all three off, and named the two options turned on with `defaults` after Check Again.
  With macOS tiling on, a dragged window that macOS filled or tiled returned to its column origin and width within 0.4 seconds, but kept the macOS height of 1410 points instead of 1394.

## Next

Each phase lands as its own PR or PRs.
Record every acceptance result in the [acceptance ledger](docs/acceptance-ledger.md).

1. Finish the remaining v1 features.
   - Add pointer-default and focused-strip gesture targeting to the engine, the configuration, and Settings.
   - Finish CI and review for the verified engine #29 merge pin (#43).
   - Run the stack overflow and stack limit hardware checks (S-5 and S-7).
   - Verify every Strip gestures checklist item and the settling behavior on a real trackpad.
2. Build the public release path, in parallel with phase 1.
   Integrate Sparkle updates, then production signing, notarization, the release DMG, and the Homebrew cask.
   Verify install, upgrade, and Accessibility attribution on the released bundle.
3. Freeze one release candidate, then run the complete app and multi-monitor acceptance checklists on that bundle with Accessibility granted.
4. Define the engine memory-stability rule, complete the endurance period, and have Sam decide Q6 at the final check before publishing v1.
5. Move to Rust 1.99 when the product is ready. samanyudas/paneru#6 fixes the two `assert_is_empty` Clippy errors in `src/lua/runtime.rs`. Branch `chore/rust-1.99-engine` holds the earlier attempt.

## Blockers

- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

The app implementation at `540cc57`, with engine `48df35a`, passed strict Swift and engine lint, the signed app and helper build, and 142 Swift tests.
Its engine passed 41 library and 707 binary tests without default features, and 52 library and 794 binary tests with defaults.
The first native target failed recovery while the desktop was locked.
After Sam unlocked the desktop, `make e2e` passed both permission observations and fixture recovery.
Permission attribution remains unresolved.
Those app checks do not verify the newer standalone engine repairs.

On 23 October 2026, standalone engine `ee94515` passes 52 library and 841 binary tests with defaults.
The no-default run passes 41 library and 751 binary tests.
Formatting and strict Clippy pass in both feature configurations.
Sol approves the full engine change in round two, with source and mock evidence kept separate from native results.
All thirteen final native fixture lanes pass under the environment conditions above.
Greptile scored engine `ee94515` and integration `d4102fe` at 5/5.
Engine #29 merged after Sol approved, both bot checks passed, and all review threads were resolved.
Sol approved the merge-commit repin in integration round two, with no findings.

The integration repin to published merge `ffff464` passes `make check` on 23 October 2026.
This includes docs, 19 harness tests, ShellCheck, actionlint, compatibility, strict Swift and engine lint, the signed build, 142 Swift tests, and 41 library plus 751 binary engine tests.
Its native selftests report `observed-granted. Attribution unresolved.` and successful fixture recovery.
DMG creation, verification, mounting, signatures, and the embedded engine revision check also pass.
The parser hashes and publication guard remain unchanged.
The integration remains draft until fresh CI and bot review finish for the repin.
