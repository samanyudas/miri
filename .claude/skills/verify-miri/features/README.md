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
| [Focus a window with a shortcut](focus-window-shortcut.md) | Yes, on 2026-11-02 at `main` 38b851c8, with arrow and letter chords. Run `20261102-003047`. |
| [Start, stop, and restart window management](window-management-controls.md) | Not yet with `V`. The #234-#236 reproduce run on 2026-11-01 drove the same controls with the same tools. |
| [Setup checks](setup-checks.md) | Not yet with `V`. The #236 run drove the `yabai` stand-in with the same tools. |
| [Customize shortcuts](shortcut-customization.md) | Not yet. Recording a chord was driven by hand-built tools on 2026-10-26. |
