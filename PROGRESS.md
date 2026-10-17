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

PR #27 full-stop work is on `fix/open-issues` in `/Users/sam/.t3/projects/miri-fix-issues`.
The branch fixes default upgrades, exact configuration backups, and Stop ownership for usable and rejected engine bindings.
A deleted version 1 resize shortcut stays deleted.
An unversioned file keeps its existing shortcuts.
The real-file upgrade recorded on 16 October predates the backup implementation.

The latest local source is `5b9ac13`.
All 84 Swift tests in 14 suites pass, and strict formatting passes for the final scalar command-separator fix.
Independent review cleared the final Stop parser changes at `5b9ac13`, and its targeted run passed all 36 binding tests.
A signed candidate combines this Miri source with engine `5a0e74d` under `.audit/pr27-stop-final-build/`.
It is now running for the remaining physical checks.
The complete `make check` and CI must run again after the final engine pin.
The earlier full gate at `be8207b` passed with 74 Swift tests, 370 engine tests, both Accessibility selftests, and DMG packaging.
The nine hosted checks at `9fc6c08` cover the earlier pushed source only.

Sam's width check found a blank left margin after grow and shrink.
The engine restored the width but moved the first column from x=4 to x=55.
The engine fix preserves an already aligned outer column's viewport edge.
Sam confirmed normal spacing on the signed `cb0f4ee` candidate.
The observer recorded x=4 throughout a 508 to 610 to 508 point width roundtrip.

Sam's stacked-height check found a bottom gap after growth.
A native probe reproduced macOS accepting height 694 at the old origin before the engine moved the window upward for a requested height of 750.
The engine fix commits native position before size and waits for settled geometry before verification.
Sam confirmed the signed `5a0e74d` candidate grows and returns without the bottom gap.
A controlled native probe measured heights 558, 622, and 558 with bottom y=1324 throughout.
An initial automated after-probe lost focus and is excluded from the passing evidence.

Both engine fixes are published in [samanyudas/paneru#11](https://github.com/samanyudas/paneru/pull/11) at `4de642f`.
The PR remains open for Sam to review and merge.
CodeRabbit skips review because the base is `miri/v0.5.2`.
Independent source review found no production defects.
The final test commit closes its two timing-test gaps.
The engine's final test tree passed 40 configuration and 338 integration tests without Lua, and 51 configuration and 418 integration tests with Lua.
Formatting and Clippy pass in both modes.
PR #27 still pins published engine `0010611` until Sam merges the engine fix into `miri/v0.5.2`.

Sam confirmed numbered and first/last-column jumps return to the lower last-focused member, Fixture 0.
Sam confirmed ordinary Control-Option-Q stops management and subsequent resize input does nothing.
The app relaunched with a new process and remained Stopped without an engine process.
Sam also reproduced the rejected-reload defect: `hyper-h` leaves the engine managing while Control-Option-Q does nothing.
The typed binding inspection fix retains the previous Stop owner when the engine rejects the bindings.
Sam confirmed that physical Control-Option-Q now stops management after the rejected replacement.
The native UI showed Stopped and the engine process exited.
Sam also confirmed that Control-Option-A causes no movement for the intentional `lefarrow` typo.
The valid fixture-only configuration is restored after both checks.

The disposable-window run used `.audit/pr27-stop-final-build/`, with Miri UI `5b9ac13` and engine `5a0e74d`.
The original developer configuration is backed up in `.audit/pr27-hardware/original-config.toml` and must be restored after the run.
The observer records fixture-only state in `.audit/pr27-hardware/observations.jsonl`.
The horizontal run used top-aligned displays, with the built-in display at Quartz x=-2048 and the external display at x=0.
Sam reported that all four horizontal display actions worked.
A controlled physical West move now confirms that only Fixture 0 transfers from external display 3 to built-in display 1, with focus following.
The observer and native bounds match Sam's result.
Sam confirmed the controlled East focus, West focus, and East move.
The observer recorded focus from Fixture 0 on display 1 to Fixture 3 on display 3, back to Fixture 0 on display 1, then Fixture 0 moving to display 3 with focus following.
These horizontal checks passed on the current signed candidate.
A window query's `display_id` describes geometric visibility, so it does not prove ownership changes for off-screen neighbouring windows.
Sam has arranged the external display directly above the laptop with left edges aligned.
Native Quartz bounds confirm the external display at y=0 and the built-in display at y=1440.
Sam confirmed all four vertical compass actions, but the laptop's other fixtures moved off the left edge.
Selecting the affected apps restored their positions.
The vertical signoff is withheld while this strip-position defect is investigated.
Two controlled native replays reproduce the defect, with zero off-screen laptop neighbours before the roundtrip and two afterward.
Native x positions change from 8 to -495 and 516 to -725 while those windows remain on the laptop's native workspace.
Evidence is under `.audit/pr27-display-neighbours-controlled-before{,2}.*`.
Earlier automatic attempts had invalid focus or baseline visibility and are excluded from causal proof.

Sam paused this task on 17 October and will explicitly ask to continue.
The source diagnosis agent is interrupted, and no fix for the new strip-position defect has been written.
The signed test app, helper, observer, and all four disposable fixtures are stopped.
The original developer configuration is restored byte for byte.
The valid disposable configuration is saved as `.audit/pr27-hardware/paused-fixture-config.toml`.
The detailed restart instructions and pending source diagnosis are saved in `.audit/pr27-resume-20261017.md`.
Both PRs are unwatched for this pause.
Do not resume until Sam asks.

1. Find out whether macOS tiling halves windows for #13, for example after a lock and unlock with an external display.
   To see every engine resize, log the old and new size in `WindowOS::resize` in `vendor/paneru/src/manager/windows.rs`.
2. Repeat the full live app run with an external display connected.
3. Verify focused-window stacking in both directions on hardware, starting from a stack of three windows.
   The 16 October shortcut run covered stacking and pop-out in both directions with single-window columns only.
4. Build the remaining v1 controls: the shortcut recorder and reset action, the gesture test, and pointer-targeted swipes.
5. Finish the #23 vertical arrangement check.
   Restore the original configuration, quit the test app, and remove the owned fixture processes afterward.
6. Decide Q6, the release duration, at the final check before publishing v1.
7. Move to Rust 1.99 when the product is ready. samanyudas/paneru#6 fixes the two `assert_is_empty` Clippy errors in `src/lua/runtime.rs`. Branch `chore/rust-1.99-engine` holds the earlier attempt.

## Blockers

- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

The final local Stop parser suite at `5b9ac13` passes 84 Swift tests in 14 suites.
The final engine tree at `4de642f` passes both test modes and lint as recorded above.
The final combined `make check`, hosted CI, and remaining physical checks are still pending.
The append-only decision trail is `.audit/pr27-full-stop-20261017.tsv`.
