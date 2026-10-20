# Progress

Updated: 2026-10-20 on branch `feat/stack-limit`

This file records in-flight state and the handoff between sessions.
Product decisions live in `decisions/`, architecture in `docs/adr/`, and tasks in GitHub Issues.
Update it at the end of every session and in any PR that changes what is done or next.

## Objective

Reach a working v1 app that manages windows through the bundled engine, as defined in [release scope](decisions/release-scope.md).
The app foundation, engine integration, configuration, default shortcuts, shortcut customization, and gesture controls are merged.
The current milestone is the remaining v1 features: pointer-versus-focus gesture targeting, drag insertion into a stack, and stack overflow.
The stack limit is built and waits for its hardware check.
The public release path and the complete acceptance runs follow.

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
- `feat/stack-limit` delivers the stack limit (#44) with samanyudas/paneru#20, which adds the engine option `[options].stack_limit`.
  It holds a whole number from 1 or `"fit"`, defaults to `5`, and is capped at what fits in the column at 200 points on the active display.
  A Stack command into a full column moves the window out of its own stack into a new column between the two.
  A window that is already its own column stays put.
  Lowering the limit leaves existing stacks unchanged, and the engine reads the limit on every Stack command, so a hot reload applies to the next one.
  The engine rejects `0`, negative numbers, and other values with a parse error, and so does Miri, which reports `options.stack_limit`.
  `effective_stack_limit(config, column_height)` in the engine's `src/ecs/layout.rs` holds the cap, for reuse by drag insertion (#43).
  Settings has a Windows per stack picker on the Layout page, with Fit the display and the numbers from 1 to what fits on the main display.
  The branch pins engine `0cd2368`, the head of `miri/stack-limit`, so `make compat` fails until samanyudas/paneru#20 merges and the pin moves to that merge.
  On 20 October 2026, `make native` passed on this branch with 141 Swift tests, 40 engine library tests, and 427 engine binary tests.
  Its permission selftest reported `observed-granted. Attribution unresolved.`, and its recovery selftest recovered the fixture window.
  `make lint` passed except `make compat`, for the unmerged pin above.
  Settings was not opened, so the picker has not been seen on screen.
  No hardware check has run, and the acceptance check is S-7 in the [acceptance ledger](docs/acceptance-ledger.md).

## Next

Each phase lands as its own PR or PRs.
Record every acceptance result in the [acceptance ledger](docs/acceptance-ledger.md).

1. Finish the remaining v1 features.
   - Add pointer-default and focused-strip gesture targeting to the engine, the configuration, and Settings.
   - Implement dragging windows into columns and to new columns, on one display and across displays (#43).
   - Implement overlapping stack overflow (#42).
   - After samanyudas/paneru#20 merges, repin the engine to its merge commit on `miri/v0.5.2`, then run the stack limit hardware check (S-7, #44).
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

CI run [39222055411](https://github.com/samanyudas/miri/actions/runs/39222055411) passed on `main` at `e516edd` with engine `4b4705a` on 19 October 2026.
It ran documentation checks, lint, the build, 136 Swift tests, 40 engine library tests, 417 engine binary tests, and DMG packaging.
The permission selftest reported `observed-ungranted. Attribution unresolved.`, and its missing-helper and aliased-path checks passed.
The recovery selftest reported `skipped-ungranted`, because Miri Developer lacked the Accessibility grant.
That run therefore does not prove granted window recovery on the current pin.
The last granted recovery check is the 18 October 2026 `make check` on `feat/gesture-controls` at `5a354d1` with engine `a15682f`.
No trackpad has been used for any check.

Known limits from that 18 October 2026 work remain.
Native width constraints can still change the final edge after an app refuses a requested size.
A transfer during an existing resize derives its destination ratio from the intermediate width.
