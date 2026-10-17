# Progress

Updated: 2026-10-17 on branch `fix/open-issues`

This file records in-flight state and the handoff between sessions.
Product decisions live in `decisions/`, architecture in `docs/adr/`, and tasks in GitHub Issues.
Update it at the end of every session and in any PR that changes what is done or next.

## Objective

Reach a working v1 app that manages windows through the bundled engine, as defined in [release scope](decisions/release-scope.md).
The current milestone is the first production app slice: menu bar controls, engine start and stop, and window recovery.

## Done

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
- `feat/default-bindings` writes the accepted default shortcuts to `[bindings]` from one table in `Sources/MiriCore/Bindings.swift`.
  A new install gets the full set.
  An existing file gets each default whose engine command it does not bind under any alias, with only the default's free chords.
  `[miri].default_bindings_version` records the offer, so Miri never re-adds a binding the user deleted.
  A live run on 16 October 2026 sent all 43 bound chords as synthetic key events, and the engine ran each command.
  The engine's behavior differed from the accepted behavior only where the engine mapping records it, such as a numbered jump into a stacked column focusing the top window instead of the last-focused one.
  Some actions stay unbound or behave differently, as the [engine mapping](decisions/keybinding%20reference.md#engine-mapping) records.
- `fix/open-issues` pins engine `0010611` on `miri/v0.5.2`, which includes the squash merge of samanyudas/paneru#9.
  The engine adds five-point resize steps (#22), directional display focus and move (#23), and column jumps that return to a stack's last-focused window (#24).
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
  Sam paused the run before the East and West check with the built-in display to the right of the monitor.
  Evidence is in `.build/artifacts/pr9-hardware-evidence/`.
  Test helpers remain in `.build/artifacts/pr9-hardware-runtime/` for that check and must be deleted afterwards.

## Next

PR #27 full-stop review fixed unversioned shortcut ownership, Stop ownership when another binding has an unknown key, and missing backups before default-version changes.
The upgrade also preserves deleted version 1 resize shortcuts.
Backups contain the exact original file under `config.toml.backups/`, and a backup failure leaves the configuration untouched.
The real-file upgrade recorded on 16 October predates this backup implementation.
At `0270e05`, `make check` passed with 73 Swift tests, 370 engine tests, both Accessibility selftests, and DMG packaging.
The subsequent deleted-shortcut regression failed before the fix, and all 26 binding tests passed afterwards.
At `be8207b`, the complete `make check` passed with 74 Swift tests, 370 engine tests, both Accessibility selftests, and DMG packaging.
Sam is available for the remaining physical shortcut checks, and the disposable-window run has started.
macOS currently reports only the built-in 2048 x 1332 display.
The original developer configuration is backed up in `.audit/pr27-hardware/original-config.toml` and must be restored after the run.
The observer records fixture-only state in `.audit/pr27-hardware/observations.jsonl`.
A later review reproduced valid multiline shortcut strings being rejected because Miri did not trim newlines as the engine does.
The parser now trims whitespace and newlines for both validation and Stop chord ownership.
All 75 Swift tests pass after that parser fix.
The initial hardware build was `be8207b`, which has the same window commands and Stop implementation as `9fc6c08`.
Sam's resize check exposed a real engine spacing defect after the test setup excluded T3 Code.
The first column returned to its original width but shifted from x=4 to x=55, leaving a blank left margin.
A local regression reproduces the same defect, and the candidate fix preserves the viewport edge of an already aligned outer column.
The candidate is on local engine branch `fix/pr27-resize-edge` in `/private/tmp/miri-pr27-resize-edge`.
The signed live candidate under `.audit/pr27-spacing-build/` contains engine `cb0f4ee` and is awaiting Sam's spacing recheck.
No engine fix has been published, and PR #27 still pins `0010611`.
The candidate passed 40 configuration and 331 integration tests without Lua, 51 configuration and 409 integration tests with Lua, and Clippy in both modes.
An additional rapid-resize test passed at normal animation speed.

1. Find out whether macOS tiling halves windows for #13, for example after a lock and unlock with an external display.
   To see every engine resize, log the old and new size in `WindowOS::resize` in `vendor/paneru/src/manager/windows.rs`.
2. Repeat the full live app run with an external display connected.
3. Verify focused-window stacking in both directions on hardware, starting from a stack of three windows.
   The 16 October shortcut run covered stacking and pop-out in both directions with single-window columns only.
4. Build the remaining v1 controls: the shortcut recorder and reset action, the gesture test, and pointer-targeted swipes.
5. Test #23 East and West with the built-in display to the right of the external monitor.
   Run the remaining shortcuts from #22, #24, #25, and #26 live.
6. Decide Q6, the release duration, at the final check before publishing v1.
7. Move to Rust 1.99 when the product is ready. samanyudas/paneru#6 fixes the two `assert_is_empty` Clippy errors in `src/lua/runtime.rs`. Branch `chore/rust-1.99-engine` holds the earlier attempt.

## Blockers

- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

See the verification section of the `feat/v1-app-core` PR.
