# Design tree status

Status: reconciled with `main` at `e516edd` on 20 October 2026.
This report records the accepted answers to Q1 through Q5 and Q7 through Q21, and the stack and settling rules Sam accepted on 19 October 2026.
Sam deferred Q6 to the final check before publishing v1.
No product question blocks implementation.
This document owns product decision state only.
[PROGRESS.md](../PROGRESS.md) owns implementation state, and the [acceptance ledger](../docs/acceptance-ledger.md) owns acceptance results.
The native app is implemented, but no complete acceptance run has passed.

## Settled branches

- The product is a native macOS scrolling window manager for daily use and public FOSS release.
- The app uses SwiftUI and AppKit, with a pinned Paneru-based helper process.
- Miri requires Accessibility permission only and keeps SIP enabled.
- Each physical monitor and native Space has an independent scrolling strip.
- Display changes follow macOS Space migration, with reachable floating windows if strip re-attachment fails.
- Settings use isolated TOML configuration, apply immediately, and retain the last valid settings after errors.
- Stop persists across launches, and repeated engine crashes stop automatic retries.
- Signing, notarization, Sparkle updates, and a Homebrew cask belong to the release direction.
- Numbered jumps select columns and focus the last-focused window within a selected stack.
- Stacking into the left or right column moves only the focused window.
  The other windows of its old stack stay in place.
  Each further press moves the window one more column in that direction.
  In the first or last column, the command does nothing.
- New windows start at 50% of display width, while existing windows retain their widths.
- Resize commands change size by five percentage points of the display's corresponding dimension, subject to window size constraints.
- Control-Option-Command with W, A, S, and D focuses monitors above, left, below, and right.
  Adding Shift moves the focused window in that monitor direction.
- V1 uses clicking and macOS window switching to access floating windows without a dedicated floating-to-tiled focus shortcut.
- Fixed-size windows and Miri's settings float automatically.
- When focus moves, the strip moves only as far as needed to show the focused column fully.
  Sam replaced the earlier rule, which centered the focused column whenever the strip overflowed, on 19 October 2026.
- After a swipe or modifier scroll, the strip settles on a column, as [Release scope](release-scope.md) describes.
- Trackpad scrolling moves the strip under the pointer by default, and a setting chooses the focused strip instead.
- [Stacks](release-scope.md#stacks) keep equal heights after membership changes and never overlap while they fit.
  An overflowing stack overlaps each window below the top bar of the window above, and the focused window comes to the front.
- Dragging a tiled window moves it into a column or to a new column at the drop position, on any display.
- The stack limit is an engine option that defaults to 5, never exceeds what fits on the display, and a Stack command past it starts a new column.
- The layout reserves space for the visible Dock without a separate v1 setting.
- V2 includes an optional custom Miri dock that can be enabled or disabled.
  The Miri dock is enabled by default.
  The Miri dock dims when inactive-window dimming is enabled.
  A stack containing windows from multiple apps shows multiple app icons in its dock entry.
  The [Miri dock plan](v2-roadmap.md#miri-dock) defines column entries, same-app window-count badges, and a window-title picker for individual window selection.
- Reduce Motion or the disable-animation setting makes strip movement instant.
- All managed windows must remain accessible after Miri stops, quits, or experiences an unrecoverable engine failure.
  Never leave windows stranded off-screen.
- Configuration migrations back up the file and preserve user values.
  A migration that cannot preserve those values leaves the file untouched and reports an error.
- Shortcut recording rejects bindings assigned to a different Miri action, warns about known macOS conflicts, and never silently replaces another binding.
- An unavailable setup check shows **Not checked** with manual instructions and is never presented as passed.
  Unavailable gesture conflict detection instead shows **Unable to verify** and offers a gesture test.
- Diagnostics contain versions, monitor setup, permission status, engine status, and redacted logs, with a preview before copying.
  Window titles, document paths, usernames, and raw configuration are excluded by default.
- Strip gestures support three fingers, four fingers, and Off.
  Initial setup recommends four fingers but enables it only when the gesture is verified as usable without a macOS conflict.
  Otherwise, strip gestures default to Off.
- The strip follows finger movement by default, with a persistent setting to reverse direction.
- A confirmed known macOS gesture conflict disables Miri's conflicting strip gesture and preserves keyboard window management.
  Miri provides manual setup instructions and never modifies macOS settings automatically.
- Five-finger support is deferred.
- When automatic conflict detection is unavailable, consistent real strip movement without unintended macOS actions and explicit user confirmation count as **Verified by user test**.
  Miri persists the gesture preference and provides an option to retest.
  This result does not claim automatic verification of the underlying macOS gesture configuration.
  Known confirmed conflicts still prevent enablement, and failed or inconclusive tests leave the gesture Off.
- User-test results remain valid across ordinary restarts.
  A finger-count or direction change, a macOS or bundled-engine upgrade, or a detected or user-reported change to relevant macOS gestures invalidates the result.
  Miri preserves the preference, keeps the gesture Off until another successful test and explicit confirmation, and preserves keyboard window management.

These decisions appear in [Release scope](release-scope.md) and [ADRs 0001 through 0009](../docs/adr/).
Accepted decisions do not establish tested behavior.

## Open product decisions

Q6, the release duration, is deferred to the final check before publishing v1.
Sam decides it then, together with the other release steps.
Until then, the release scope and the release checklist both keep their current requirements.
Q6 does not block implementation.
See [Documentation inconsistencies](#documentation-inconsistencies).

Sources: [Release scope](release-scope.md), [Configuration](configuration.md), [Keybinding reference](keybinding%20reference.md), [Setup](setup.md), and [Features and shortcuts](features%20and%20shortcuts.md).
Questions about optional controls depend on whether those controls enter v1.
The intended gesture policy is accepted.
Actual gesture usability and reliable conflict detection remain engineering and hardware checks.

## Documentation inconsistencies

The [release checklist](v1-acceptance-checklist.md) requires three consecutive full runs.
Each full run includes a two-week daily-use period.
This implies six weeks, while [Release scope](release-scope.md) describes one two-week period.
Sam deferred Q6 about this interpretation to the final check before publishing v1.
The release requirements are unchanged until then.

Release scope now distinguishes network-based update checks and downloads from prohibited telemetry and transmission of window-management data.
This wording aligns the existing update and privacy policies.

The keybinding table now marks the tabbed-column command as v2 only.

## Engineering prerequisites

The [helper-process ADR](../docs/adr/0009-run-the-engine-as-a-helper-process.md) requires a prototype of Accessibility permission attribution before other implementation.
The [recorded prototype comparison](../docs/prototypes/helper-permission.md#recorded-development-bundle-result-on-14-october-2026) completes that prerequisite for the tested ad-hoc development bundle on macOS 27.0.
Sam reported that enabling only Miri changed both processes from denied trust and reads to granted trust and successful reads.
A fresh packaged check also verified granted trust and successful reads from both processes.
Developer ID and notarized-release permission behavior remain unverified.
The [earlier engine assessment](engine-assessment.md) reviewed a commit that is not the selected release dependency.
The [pinned-release assessment](engine-v0.5.2-assessment.md) now reviews `v0.5.2` at `b1b6abbd3f1a4be138152b6f0389c9ff1b27a269`.
This source inspection does not establish native or hardware behavior.

The source review corrects earlier assumed gap and gesture key names.
It also identifies integration gaps for pointer-targeted swipes, fixed resize increments, new-window-only widths, configuration isolation, and recovery after abrupt engine failure.
The accepted Miri behavior remains unchanged.

Unverified behavior includes configuration isolation, command reconciliation, undocumented APIs, setup checks, gestures, fullscreen return, and display-edge handling.
Engine and hardware experiments resolve these facts.
They are not questions for Sam to answer from memory.

### Stacking commands

This finding comes from source inspection of `v0.5.2` at `b1b6abbd3f1a4be138152b6f0389c9ff1b27a269`.
No one has run these commands against the engine or on hardware.
The engine fork change samanyudas/paneru#6 resolves every finding in this section in unit tests.
It adds `stack east` and `unstack west`, moves only the focused window, and checks for fullscreen columns before it changes the layout.

The engine has two stacking commands only.
`stack` merges into the column on the left, and `unstack` pops the window out to a new column on the right.
The engine has no command to stack into the right column or to pop out to the left.
The [keybinding reference](keybinding%20reference.md) assigns shortcuts to both missing actions, so Miri must supply them.

`LayoutStrip::stack` in `src/ecs/layout.rs` moves the focused window's entire column, not only the window.
Its doc comment says a window already in a stack causes no action, but the code merges the stack anyway.
Repeated presses therefore move the growing stack left until it reaches the first column.
For example, three presses on D in `A | B | C | D` produce one column `[A, B, C, D]`.
In the first column, the command does nothing.
This conflicts with the accepted rule that stacking moves only the focused window.
Repeated `unstack` presses are safe.
The first press pops the window out, and later presses do nothing because the window is no longer stacked.

`LayoutStrip::stack` also removes columns before it checks for the internal fullscreen column type.
If either the source or the target column is fullscreen, the function returns without restoring the removed columns.
Those windows could leave the layout, which would conflict with the rule that windows never become stranded.

## Remaining engineering work

This list holds only work that has no implementation on `main` at `e516edd`.
[PROGRESS.md](../PROGRESS.md) records what is implemented and what is verified.

- Add pointer-default and focused-strip gesture targeting to the engine, the configuration, and Settings.
- Implement dragging windows into columns and to new columns, on one display and across displays ([#43](https://github.com/samanyudas/miri/issues/43)).
- Run the stack limit hardware check, S-7 in the [acceptance ledger](../docs/acceptance-ledger.md).
  The engine option and its Settings control are built, pending that check ([#44](https://github.com/samanyudas/miri/issues/44)).
- Implement overlapping overflow that keeps every top bar visible ([#42](https://github.com/samanyudas/miri/issues/42)).
- Integrate Sparkle updates with the accepted update policy.
- Configure Developer ID signing, notarization, signed update feeds, the release disk image, and the Homebrew cask.
- Recheck app and helper Accessibility attribution on the Developer ID signed, notarized bundle.
- Define a measurable engine memory-stability rule.
- Complete the release source audit beyond the reviewed configuration, gesture, sizing, isolation, and clean-exit paths.
  Establish a reproducible app and helper build.
- Review configuration keys, accepted types and ranges, and private API fallbacks against the pinned engine.

## Acceptance gaps

The [acceptance ledger](../docs/acceptance-ledger.md) records every required check, and all of them are pending.
Selected checks ran on earlier builds, as PROGRESS.md records, but no release candidate is frozen.
No real trackpad result is recorded.
The endurance requirement that engine memory stays stable has no measurable pass rule.

## Deferred branches

Tabbed columns, the minimap, inactive-window dimming, advanced rules, virtual workspaces, and portable display layouts remain outside v1.
Dragging windows into columns, to new columns, and between displays is v1 work.
Focus borders, pointer-following controls, display exclusions, fixed-pixel presets, animation tuning, and Hyper-key recording are also excluded from v1.
Five-finger strip gestures are also deferred.
Alternative automatic centering modes, `never` and `always`, remain unselected proposals outside the accepted v1 controls.
Their detailed design can remain unresolved without blocking the v1 interview.
The [v2 roadmap](v2-roadmap.md) distinguishes accepted deferrals from candidate improvements.
The custom Miri dock is accepted v2 work and remains outside v1.
Its placement, single-window click behavior, and exact dimming appearance remain open v2 decisions.

## Repository state

[PROGRESS.md](../PROGRESS.md) records the current repository and task state.
GitHub Issues record individual tasks.
This document records only the state of product decisions.

## Completion rule

The v1 design interview is complete when every product branch has an accepted decision or an explicit deferral.
Each pending engineering prerequisite is recorded, and any product decision that depends on its result remains open.
Sam must confirm shared understanding before implementation starts.
Implementation completion and successful hardware validation remain separate states.
