# Progress

Updated: 2026-10-18 on branch `fix/open-issues`

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
The candidate is saved for the remaining physical checks.
It is currently stopped.
The complete `make check` and CI must run again after the final engine pin.
The earlier full gate at `be8207b` passed with 74 Swift tests, 370 engine tests, both Accessibility selftests, and DMG packaging.
Hosted checks passed at pushed head `34998d6`, including the later Stop parser changes.

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

Sam paused this task on 17 October and asked to continue on 18 October.
Both PRs remain open, draft, and unwatched while the new engine fix is completed.
The current user configuration was backed up as `.audit/pr27-hardware/resume-original-config-20261018.toml` and matches the original.
The display arrangement still has the external monitor above the laptop.
A new signed candidate combines Miri UI `5b9ac13` with engine `51f0c5c` under `.audit/pr27-neighbours-r3-build/`.
That interim candidate and its observer were stopped after Sam's arrival-gap report.
The original developer configuration was restored byte for byte before the next candidate and remains backed up.
All four disposable fixture apps remain open for the next candidate.

The effective configuration uses continuous scrolling by default, which skips the existing whole-strip edge clamp.
Engine commit `a90bdd0` adds the exact roundtrip regression through the real display and layout systems.
Its continuous case fails before the fix, and the noncontinuous control passes.
All other 470 tests pass on that test-only tree.
Engine `838cd47` separately fixes a pre-existing strict float comparison and passes its targeted test and Clippy.
An independent Claude Opus 5.5 design judge selected minimal fitting correction inside the existing placement pass.
The accepted design is recorded in `.audit/pr27-neighbours-design/synthesis.md`.
Engine `de75e2f` adds compatibility tests before implementation.
The refit-only implementation passes both exact roundtrip cases but still fails the Stay-mode animation test.
A generic pending-target projection broke rapid resizing and automatic centering and was rejected.
Engine `bc91de0` adds the automatic-centering control before the final focus change.
Engine `649915f` instead uses the existing visibility request for non-centering focus during a pending strip movement.
Both complete test modes pass at that head: 51 configuration plus 427 engine tests with Lua, and 40 plus 347 without Lua.
Both Clippy modes and formatting pass under Rust 1.98.1.
A signed native roundtrip at that head confirms both actual transfers, focus following, and zero off-screen laptop neighbours afterward.
This is native command evidence, not Sam's physical shortcut signoff.

Independent Claude Opus 5.5 source review found a Medium stale-Center regression and a Low animated-focus regression in noncontinuous mode.
A native run confirms that Center followed by removal leaves survivors at x=578 instead of the fixed left edge x=4.
The native attempt for the second finding used an explicit focus command, which adds its own reshuffle, so it is excluded from causal proof.
Engine `23a2dc4` commits the configuration-mode regression tests before their fixes.
Engine `187a916` keeps the existing noncontinuous edge-rule result as the source fitting seed.
Engine `51f0c5c` computes tolerated visibility at the pending strip target during continuous focus animation.
It uses the moving size and adds no persistent state, request field, system, accessor, or configuration option.
A rejected guard that disabled the path for positive tolerance reintroduced source clipping during Stay.
Its patch, command, hashes, and failed log are saved separately under `.audit/pr27-neighbours-r3-rejected-zero-guard.*`.

The exact final tree passes 51 configuration plus 431 engine tests with Lua, and 40 plus 351 without Lua.
Both Clippy modes and formatting pass under Rust 1.98.1.
The exact commands, source hashes, and immutable final log hashes are in `.audit/pr27-neighbours-r3-verification.json`.
The signed final candidate passes the fixed-edge Center-removal replay and returns the native left edge to x=8.
It also passes the wider default roundtrip with actual transfers and focus following.
The laptop columns return to x=4, 514, and 1406, with no native window outside the laptop display after Fixture 0 leaves.
These are native command checks, not physical shortcut proof.
Sam confirmed that the vertical commands work on the signed `51f0c5c` candidate.
He reported an empty area to the right of Fixture 0 after it arrives on the laptop.
The recorder confirms an 811-point gap between the arriving column and the usable right edge.
The engine appends the window last but centers its old source width before the delayed target resize.
The independent design judge initially selected a one-shot layout request for initial arrival and delayed width adaptation.
The selected layout arithmetic uses pending geometry and must preserve later scrolling, Center, and Snap.
Engine `6c42b1b` commits the arrival regression before production changes.
Its focus, workspace, order, and adapted-width checks pass, but the arriving right edge is 1237 instead of 2044.
All 484 existing tests pass on that tests-only tree.
The uncommitted arrival correction passes the original reproduction and preserves newer Center and Snap placement.
A completed modifier-scroll exposes a callback race after the temporary Scrolling component disappears.
The delayed arrival changes the user's x1336 to x1476.
The parent reopened cancellation after that failing control and obtained two independent bounded-request proposals.
The failing receipt is `.audit/pr27-arrival-completed-scroll-before.log`.
Neither cancellation proposal is implemented.
The parent instead tested the premise that native sizing requires the existing 150 ms delay.
A synchronous-sizing prototype passes all 51 library and 446 engine tests, including completed scrolling and newer Center or Snap.
Two signed native roundtrips at different widths confirm focus following and zero native arrival right gap.
All three fitting laptop neighbours remain visible after Fixture 0 returns above.
Native bottom gaps are zero on both displays.
The prototype contains the exact saved dirty patch identified by `.audit/pr27-arrival-sync-native/candidate.json`.
After that prototype check, it was stopped and the original configuration was restored byte for byte.
The parent selected synchronous sizing without a delayed callback or cancellation state.
The current contract is `.audit/pr27-arrival-design/synchronous-selection.md`.
Engine `6e572ea` commits synchronous sizing, the one-shot arrival request, and the pending-size visibility correction.
Both full modes pass without filtering: 51 library plus 446 engine tests with Lua, and 40 plus 366 without Lua.
Both strict Clippy modes, formatting, and diff checks pass.
The exact source hashes and command receipts are in `.audit/pr27-arrival-sync-final-verification.json`.
The comment review finds no added or changed comments, six deleted comment lines, and no flags.
Independent Claude Opus 5.5 review finds no production defects in the full `4de642f..6e572ea` range and closes the earlier findings.
The signed exact-head bundle is saved under `.audit/pr27-arrival-final-build/`.
Its native default roundtrip confirms focus following, zero native right and bottom gaps, and fully visible laptop neighbours after return.
Its fixed-edge Center-removal replay restores the native left edge to x=8.
Two invalid baseline attempts stopped before any reproduction moves and are excluded.
The first fixed-edge assertion rejected ECS x=5 instead of x=4 while the actual native left edge was already x=8.
A separate replay passes with the same one-point ECS tolerance used by the arrival probe and the exact native x=8 requirement.
The exclusions and correction are recorded in `.audit/pr27-arrival-native-setup-exclusions.json`.
After the native checks, the app and helper were stopped and the original configuration was restored byte for byte.
The same signed `6e572ea` build was relaunched with the valid disposable configuration for Sam's physical recheck.
The baseline confirmed Fixture 0 above and all three laptop neighbours fully visible.
The fixture-only observer recorded the check.
The exact original configuration remained backed up throughout.
Sam physically confirmed all four vertical actions at `6e572ea`, with focus following both moves, right-edge arrival, and fully visible laptop neighbours after return.
The observer records the matching focus and transfer sequence, and the final native bounds confirm all three laptop neighbours are visible.
Two additional user transfer transitions occurred after the prescribed return and are retained in the evidence.
No programmatic movement occurred while Sam performed the vertical check.
The confirmation is `.audit/pr27-hardware/vertical-6e572ea-confirmation.json`.
Sam also physically confirmed the horizontal check at `6e572ea`, with the laptop left of the external monitor and top edges aligned.
Both focus changes worked, both moves kept Fixture 0 focused, and the arriving window reached the laptop's usable right edge.
All three laptop neighbours were fully visible after Fixture 0 returned right.
The confirmation and matching observer sequence are `.audit/pr27-hardware/horizontal-6e572ea-confirmation.json`.
Both physical arrangement checks used the disposable configuration's animation speed `1000`.
The trail review correctly identified that this did not test the historical delayed-resize concern at Sam's normal animation speed `14`.
Native replays now pass at speed `14` with both Fixture 0 and a disposable TextEdit document in both arrangements.
The observer records intermediate animation frames, and all eight destination bottom edges have zero native gap.
Those native replays also confirm right-edge arrival, focus following, and visible source neighbours after return.
Their evidence is `.audit/pr27-arrival-speed14-verification.json` and is separate from physical keyboard proof.
The original configuration is now restored byte for byte.
The test app, helper, observer, and all four owned fixture processes are stopped.
Only the disposable TextEdit document was closed, and the pre-existing TextEdit application remains running.
The laptop-left, top-aligned display arrangement is restored and verified in Quartz coordinates.
The cleanup receipt is `.audit/pr27-hardware/horizontal-final-restored-20261018.json`.

Independent round 3 review closed the prior findings and found one maximum-hidden-tolerance focus defect.
Engine `e28c1c6` adds its failing regression and `84b349a` applies the projected movement condition.
A further boundary regression at `b7ba8c8` proves exact left and right viewport contact still leaves the focused window hidden during animation.
Engine `97d7ac9` requires positive visible width before accepting the projected tolerance.
Both full modes pass at that head: 51 configuration plus 433 engine tests with Lua, and 40 plus 353 without Lua.
Both Clippy modes and formatting pass.
The maximum-tolerance changes have automated proof, while native replays use the default tolerance.
The cross-model trail audit found stale status labels, missing checkpoint rows, and a reconstructed rejected-guard receipt.
Append-only correction rows identify the current run, preserve the original observations, and mark interim final labels superseded.
The earlier cancelled source review and completed round 2 findings remain recorded separately.
Engine `6e572ea` is now pushed to samanyudas/paneru#11.
Its description records both physical passes, the speed-14 native evidence, and the remaining limits.
The engine PR is ready for review, mergeable, open, and unmerged, with auto-merge disabled.
Sam's engine merge, the Miri pin, and the final combined gate remain pending.
The trail review's seven flags and append-only responses are recorded locally.
The parent chose synchronous sizing after native experiments, and no completed design judge approved that final pivot.
Source review R4 assessed the final implementation and found no production defects.
The optional follow-up diagnosis initially hit the Claude API rate limit, then completed after T3 resumed it.
Claude Opus 5.5 traced the fixed-edge ECS x=5 versus native x=8 observation to the existing odd-size conversion in `irect_from`.
The parent independently verified that conversion against all 32 fixture observations in eight saved snapshots.
The conversion is unchanged from published base `0010611` and also explains observations from the earlier `51f0c5c` run.
Odd integer dimensions lose one point when the rectangle is rebuilt from its rounded centre and integer half-size.
The native left edge remains correct, but the observed gap is seven points instead of eight.
A new speed-14 replay reports exact ECS x=4 and native x=8 because its native widths are even.
The exact origin of the odd width and the native event that refreshed the cached frame remain inferred.
The existing precision defect is tracked separately in [#28](https://github.com/samanyudas/miri/issues/28) and does not block this engine PR.
The source diagnosis and parent verification are `.audit/pr27-fixed-edge-one-point-diagnosis-completed.json` and `.audit/pr27-fixed-edge-rounding-parent-verification.json`.

1. Find out whether macOS tiling halves windows for #13, for example after a lock and unlock with an external display.
   To see every engine resize, log the old and new size in `WindowOS::resize` in `vendor/paneru/src/manager/windows.rs`.
2. Repeat the full live app run with an external display connected.
3. Verify focused-window stacking in both directions on hardware, starting from a stack of three windows.
   The 16 October shortcut run covered stacking and pop-out in both directions with single-window columns only.
4. Build the remaining v1 controls: the shortcut recorder and reset action, the gesture test, and pointer-targeted swipes.
5. After Sam merges engine PR #11, pin its published engine and rerun `make setup`, `make check`, and hosted CI.
   Both display arrangements passed, and the original configuration and laptop-left arrangement are restored.
6. Decide Q6, the release duration, at the final check before publishing v1.
7. Move to Rust 1.99 when the product is ready. samanyudas/paneru#6 fixes the two `assert_is_empty` Clippy errors in `src/lua/runtime.rs`. Branch `chore/rust-1.99-engine` holds the earlier attempt.

## Blockers

- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

The final local Stop parser suite at `5b9ac13` passes 84 Swift tests in 14 suites.
Engine `51f0c5c` passes both test modes, lint, and the native replays recorded above.
Engine `97d7ac9` passes both test modes and lint, but the latest native evidence is from the earlier signed candidate.
The tests-only arrival regression at `6c42b1b` fails as expected while all existing tests pass.
Engine `6e572ea` passes both full test and lint modes, the exact-head native checks, and independent source review.
Native width constraints can still change the final edge after an app refuses a requested size.
The maximum-width test proves reconciliation and marker cleanup, not right-edge repair after refusal.
A transfer during an existing resize derives its destination ratio from the intermediate width.
Sam's clean vertical and horizontal results are recorded at `6e572ea` with fixture animation speed `1000`.
Native checks with Fixture 0 and TextEdit also pass in both arrangements at speed `14`.
All hosted checks pass at Miri `36bec2e`, which still pins engine `0010611`.
The engine dependency merge and the published Miri pin remain pending.
The final combined `make check` and hosted CI must run again after that pin.
The append-only decision trail is `.audit/pr27-full-stop-20261017.tsv`.
