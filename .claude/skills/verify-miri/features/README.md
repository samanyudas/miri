# Miri Developer verification map

This directory is the maintained source for proving Miri Developer's user-facing behavior on the real desktop.
Read the index, then use the matching feature file as the recipe.
`V` is `.claude/skills/verify-miri/scripts/verify-miri`, run from the checkout under test.

## Baseline preconditions

- A test bundle built by `make build` in the checkout under test, or one passed with `V begin --app`.
- `V doctor` reports every line `ok`.
- `V begin --owner "<thread>"` succeeded, so this run holds the live-test lock and the test build runs.
- Management runs: the Settings status is `Managing windows`, and `managementStopped` is `0`.
- Sam's configuration keeps the default shortcuts that a recipe names. Check `[bindings]` in `~/Library/Application Support/Miri Developer/config.toml` and use the chord it lists.

## Driving conventions

- Start every recipe from the baseline. Open new fixtures for each recipe instead of reusing another recipe's windows.
- Drive only fixtures and Miri's own windows. Never focus, move, or close Sam's windows on purpose.
- Name fixtures by `fixture-N` and window ID, Settings controls by title, and shortcuts by their `config.toml` chord.
- Snapshot before the action and after each action.
- End every run with `V end`, also after a failure.

## Proof and skip reporting

- Proof is the run folder in `~/.cache/miri/verify-miri/runs/<run id>/`: `log.txt`, the snapshots, and any second view of a side effect.
- A focus or layout proof needs the engine's view and macOS's view to agree.
- Report an entry point you could not drive as skipped, with the command you tried and the unmet precondition.
  Do not report it as verified through a different entry point.
- Trackpad swipes, title-bar drags, and Space switches need Sam's hands. List them as hand checks for Sam.

## Features

| Feature | Proven by this skill |
| --- | --- |
| [Focus a window with a shortcut](focus-window-shortcut.md) | Yes, on 2026-11-05 at `main` c4ba432e, run `20261105-160539`: column, letter, number, stack, and monitor above and below. Monitor left and right were proved in run `20261104-225455`. |
| [Start, stop, and restart window management](window-management-controls.md) | Yes, on 2026-11-05 at `main` c4ba432e, run `20261105-160539`: every sub-feature, the menu bar menu excepted. |
| [Setup checks](setup-checks.md) | Yes, on 2026-11-05 at `main` c4ba432e, run `20261105-160539`: the `yabai` stand-in, Waiting, and auto-start. |
| [Customize shortcuts](shortcut-customization.md) | Yes, on 2026-11-05 at `main` c4ba432e, run `20261105-160539`: remove, add, both conflicts, and reset. Not the filter. |

## Surfaces without a map entry

These user-facing surfaces have no recipe yet.
`axdo press` reaches buttons, tabs, and radio buttons only, so a control marked "config" needs a `config.toml` edit as setup and a `V ax test dump` or `V snapshot` as proof.

- Configuration error: the menu line and the Settings banner with `Show Configuration File in Finder` ([Views.swift](../../../../Sources/Miri/Views.swift), [Settings.swift](../../../../Sources/MiriCore/Settings.swift)). Drivable with a broken `config.toml`.
- Diagnostics page and `Copy Diagnostics…` window ([SettingsPages.swift](../../../../Sources/Miri/SettingsPages.swift), [Views.swift](../../../../Sources/Miri/Views.swift)). Drivable with `ax press`.
- Window recovery: windows that management stops leave on screen ([WindowRestorer.swift](../../../../Sources/Miri/WindowRestorer.swift)). Drivable with fixtures and Stop.
- Layout page: gaps, width presets, `Animate window movement`, windows per stack, maximized window side, and the shared-edge switch ([SettingsPages.swift](../../../../Sources/Miri/SettingsPages.swift)). Config. The shared-edge switch also needs Screen Recording permission and two displays.
- General page: `Launch at login` ([SettingsPages.swift](../../../../Sources/Miri/SettingsPages.swift)). Never drive `Launch at login`, which changes Sam's login items.
- Gestures page and `Test Gesture…` ([GestureSettings.swift](../../../../Sources/Miri/GestureSettings.swift)). The test needs Sam's trackpad.
- Initial setup, the Set Up Miri window on first launch ([InitialSetup.swift](../../../../Sources/Miri/InitialSetup.swift)). Showing it again needs the launch argument `-initialSetupDone NO`, which `V begin` does not pass.
- The menu bar menu ([Views.swift](../../../../Sources/Miri/Views.swift)). `axdo` cannot open it. [Start, stop, and restart](window-management-controls.md) has the System Events route.
