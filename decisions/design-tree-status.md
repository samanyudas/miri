# Design tree status

Status: updated after Sam's interview answers on 14 October 2026.
The active product interview has one new open question about stacking scope.
The complete release decision tree remains incomplete because Q6 is held.
This report records observed documentation state and the accepted answers to Q1 through Q5 and Q7 through Q21.
Sam skipped Q6, which remains unresolved.
No app implementation or hardware validation exists in this checkout.

## Settled branches

- The product is a native macOS scrolling window manager for daily use and public FOSS release.
- The app uses SwiftUI and AppKit, with a pinned Paneru-based helper process.
- Miri requires Accessibility permission only and keeps SIP enabled.
- Each physical monitor and native Space has an independent scrolling strip.
- Display changes follow macOS Space migration, with reachable floating windows if strip re-attachment fails.
- Settings use isolated TOML configuration, apply immediately, and retain the last valid settings after errors.
- Stop persists across launches, and repeated engine crashes stop automatic retries.
- Signing, notarization, Sparkle updates, and a Homebrew cask belong to the release direction.
- Numbered jumps select columns and focus the last-focused window within a selected stack.- New windows start at 50% of display width, while existing windows retain their widths.
- Resize commands change size by five percentage points of the display's corresponding dimension, subject to window size constraints.
- Control-Option-Command with W, A, S, and D focuses monitors above, left, below, and right.
  Adding Shift moves the focused window in that monitor direction.
- V1 uses clicking and macOS window switching to access floating windows without a dedicated floating-to-tiled focus shortcut.
- Fixed-size windows and Miri's settings float automatically.
- Automatic centering occurs only when the strip overflows the display.
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

Q6 remains skipped and unresolved.
A source review on 14 October 2026 raised one new product decision about stacking scope.
See [Stacking commands](#stacking-commands).

- Decide whether **Stack focused window into left column** moves only the focused window or its whole stack.
  The pinned engine moves the whole stack, so repeated presses merge every column up to the first column into one stack.
Shared-understanding confirmation is still pending before acting on the design.

Sources: [Release scope](release-scope.md), [Configuration](configuration.md), [Keybinding reference](keybinding%20reference.md), [Setup](setup.md), and [Features and shortcuts](features%20and%20shortcuts.md).
Questions about optional controls depend on whether those controls enter v1.
The intended gesture policy is accepted.
Actual gesture usability and reliable conflict detection remain engineering and hardware checks.

## Documentation inconsistencies

The [release checklist](v1-acceptance-checklist.md) requires three consecutive full runs.
Each full run includes a two-week daily-use period.
This implies six weeks, while [Release scope](release-scope.md) describes one two-week period.
Sam skipped Q6 about this interpretation.
The question remains unresolved, and the release requirements are unchanged.

Release scope now distinguishes network-based update checks and downloads from prohibited telemetry and transmission of window-management data.
This wording aligns the existing update and privacy policies.

The keybinding table now marks the tabbed-column command as v2 only.

## Engineering prerequisites

The [helper-process ADR](../docs/adr/0009-run-the-engine-as-a-helper-process.md) requires a prototype of Accessibility permission attribution before other implementation.
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

The engine has two stacking commands only.
`stack` merges into the column on the left, and `unstack` pops the window out to a new column on the right.
The engine has no command to stack into the right column or to pop out to the left.
The [keybinding reference](keybinding%20reference.md) assigns shortcuts to both missing actions, so Miri must supply them.

`LayoutStrip::stack` in `src/ecs/layout.rs` moves the focused window's entire column, not only the window.
Its doc comment says a window already in a stack causes no action, but the code merges the stack anyway.
Repeated presses therefore move the growing stack left until it reaches the first column.
For example, three presses on D in `A | B | C | D` produce one column `[A, B, C, D]`.
In the first column, the command does nothing.
Repeated `unstack` presses are safe.
The first press pops the window out, and later presses do nothing because the window is no longer stacked.

`LayoutStrip::stack` also removes columns before it checks for the internal fullscreen column type.
If either the source or the target column is fullscreen, the function returns without restoring the removed columns.
Those windows could leave the layout, which would conflict with the rule that windows never become stranded.

## Remaining engineering work

- Prototype app and helper Accessibility attribution before other implementation, as required by ADR 0009.
- Complete the release source audit beyond the reviewed configuration, gesture, sizing, isolation, and clean-exit paths.
  Establish a reproducible app and helper build.
- Verify configuration keys, accepted types and ranges, binding syntax, gesture support, and private API fallbacks.
- Implement gesture verification and conflict handling without treating unavailable detection as a passed check or a confirmed conflict.
- Map the accepted eight-point gaps to the source-backed padding fields and select Miri's validation range after coordinate checks.
- Define command reconciliation, external configuration edit handling, and upgrade migrations under the selected product policies.
- Establish window recovery that satisfies Q12 even when the engine cannot run a clean-shutdown handler.
- Supply the missing stack-right and pop-left commands, and verify repeated stacking against the pinned engine.
- Reproduce the fullscreen column loss in `LayoutStrip::stack`, then fix it in Miri or report it upstream.
- Build the native settings window, menu bar controls, helper lifecycle, setup checker, and diagnostics.
- Define bounded log storage and a measurable engine memory-stability check.
- Configure release signing, notarization, signed update feeds, disk image packaging, and Homebrew cask delivery.
- Verify clean installation, upgrades, app behavior, and the real-hardware multi-monitor checklist.

These tasks implement or verify the accepted direction in [Release scope](release-scope.md).
The targeted source inspection is complete.
App implementation, integration fixes, native validation, and release delivery remain uncompleted.

## Acceptance gaps

The [multi-monitor checklist](v1-acceptance-checklist.md) retains its existing release requirements.
The new [app acceptance checklist](v1-app-acceptance-checklist.md) derives checks from accepted permission, shortcut, configuration, update, diagnostic, lifecycle, and layout behavior.
Neither checklist has been run against an app implementation.
The endurance requirement that engine memory stays stable has no measurable pass rule.

## Deferred branches

Tabbed columns, the minimap, inactive-window dimming, advanced rules, drag-to-reorder, virtual workspaces, and portable display layouts remain outside v1.
Focus borders, pointer-following controls, display exclusions, cross-display dragging, fixed-pixel presets, animation tuning, and Hyper-key recording are also excluded from v1.
Five-finger strip gestures are also deferred.
Alternative automatic centering modes, `never` and `always`, remain unselected proposals outside the accepted v1 controls.
Their detailed design can remain unresolved without blocking the v1 interview.
The [v2 roadmap](v2-roadmap.md) distinguishes accepted deferrals from candidate improvements.
The custom Miri dock is accepted v2 work and remains outside v1.
Its placement, single-window click behavior, and exact dimming appearance remain open v2 decisions.

## Repository state

At audit time, Git tracks only `README.md` and `assets/icon.svg`.
The decision documents, glossary, ADRs, and license remain uncommitted local files.
GitHub has no issues for this repository at audit time.
Publishing the initial commit did not publish these local documents.

These observations came from `git ls-files`, `git status --short --branch`, and `gh issue list --repo samanyudas/miri --state all`.

## Completion rule

The v1 design interview is complete when every product branch has an accepted decision or an explicit deferral.
Each pending engineering prerequisite is recorded, and any product decision that depends on its result remains open.
Sam must confirm shared understanding before implementation starts.
Implementation completion and successful hardware validation remain separate states.
