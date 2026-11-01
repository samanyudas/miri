---
name: verify-engine-lifecycle
description: Model-check how Miri starts, stops, restarts, and quits its engine with the TLA+ model in verification/engine-lifecycle. Use when a change touches EngineSupervisor, CrashPolicy, AppModel start, stop, restart, or quit, the setup poll, the Stop shortcut, a control that starts or stops management, or applicationShouldTerminate, and before you fix one of the lifecycle findings below.
---

# Verify the engine lifecycle

Tests check the orders of events that someone wrote down.
This check tries every order of clicks, timers, engine exits, and setup changes in a small model of the lifecycle code, and reports the shortest order that breaks a rule.

## Run it

From the repository root:

```sh
make verify-engine-lifecycle
```

It runs `scripts/verify-engine-lifecycle.py --mutants` and takes about 3 seconds after the first run, which downloads the tools.
It checks 318 distinct states.
The first run downloads TLC 1.7.4 and a Temurin 21 Java runtime, both pinned by SHA-256, into `~/.cache/miri/verification`.
Set `JAVA` and `TLA2TOOLS` to use your own Java 11 or later and `tla2tools.jar` instead.

It prints one line for each rule, then the path of each finding and of each unexpected result.
Add `--traces` to the script to see each mutant's path too.

The script's exit status, which `make` prints as `Error 1`, `Error 2`, or `Error 3` and turns into exit status 2:

- `0`: every rule gives its expected result, and the covered code is unchanged since the sync commit.
- `1`: a rule gives a result that differs from the expected one. Read [Read the result](#read-the-result).
- `2`: a tool or a TLC run failed, or TLC ran longer than 120 seconds. The output has TLC's message. A run past the limit means that the model has no bound on some value, as when a change lets an action queue completions without `Step`.
- `3`: the results are as expected, but covered code changed after the sync commit. Do [Keep the model in step](#keep-the-model-in-step) before you trust the results.

## The rules

Each rule is a TLA+ definition at the end of `verification/engine-lifecycle/EngineLifecycle.tla`.

| Rule | It means | The harm when it breaks |
| --- | --- | --- |
| `StopStands` | No engine starts after you stop Miri, until you start or restart it. | Miri moves windows after you told it to stop. |
| `SavedStopMatches` | Miri's saved Stop matches your last Start, Stop, or Restart. | The Stop shortcut does nothing while the engine runs, and the next launch leaves windows unmanaged. |
| `QuitLeavesNoEngine` | When Miri finishes quitting, no engine runs. | An engine outlives the app, and Miri does not recover its windows. |
| `OneEngine` | At most one engine process runs. | Two engines fight over windows and the Mach service. |
| `StoppedMeansNoEngine` | When the status says stopped or failed, no engine runs. | The status hides an engine that still moves windows. |
| `WaitingIsShown` | While Miri waits for setup to start the engine, the status says it is waiting. | The status says the engine failed, and no button can cancel the wait. |
| `QuitFinishes` | A quit always finishes. | Quit hangs. |

### Known findings

The model found four findings on 2026-11-01, and a live run on a `main` build at `bbe31c28` checked each one the same day.
The current code still breaks the rules of the findings that are not marked fixed.
`KNOWN_FINDINGS` in the script lists those rules, so they print as `finding` and do not fail the run.

1. `StopStands`: you press Restart and then Stop within 3 seconds, or you press Stop and the keyboard layout changes within 3 seconds. Either way a stop is in flight, `engineState` is still `.running`, and `restartManually()` queues `start` in `stopCompletions`. The engine exits, `exited(status:)` runs every queued completion, and the queued `start` launches an engine after your Stop.
   Reproduced live: [#234](https://github.com/samanyudas/miri/issues/234).
   Fixed by the fix for #234: `restartManually()` now records the restart in `restartAfterStop`, a later `stop()` clears it, and `keyboardLayoutChanged()` restarts only while the user has not stopped Miri.
2. `SavedStopMatches`: you press Stop, then Restart within 3 seconds. `AppModel.restart()` sees `engineState` still `.running` and calls `supervisor.restartManually()` directly, so `stoppedByUser` stays `true` while the engine runs again. `stopFromShortcut()` then ignores the Stop shortcut, and the next launch does not start management.
   Reproduced live, with both harms: [#235](https://github.com/samanyudas/miri/issues/235).
3. `QuitLeavesNoEngine`: you press Restart, then quit within 3 seconds. `stopCompletions` holds `start` and then the quit reply. The engine exits, the queued `start` launches a new engine, and then the app quits with that engine running.
   Reproduced in part: the engine log showed Miri launching an engine after SIGTERM, but that engine was gone within 50 ms of the app's exit. It has no issue of its own, because it has the same cause as #234.
   Fixed by the fix for #234: the quit's `stop(completion:)` clears `restartAfterStop`.
4. `WaitingIsShown`: the engine is `.failed`, a setup check blocks start, and you press Restart. `AppModel.start()` begins the setup poll, but `engineState` stays `.failed`, so `statusText` says "Stopped after repeated engine failures" and the menu shows no Stop button to cancel the wait.
   Reproduced live: [#236](https://github.com/samanyudas/miri/issues/236).

Findings 1 to 3 had one cause: for up to 3 seconds after a stop begins, `engineState` stays `.running`, and a restart in that time queued a `start` that no later Stop or Quit removed.
When a fix lands, the rule it fixes prints `UNEXPECTED ... holds`.
Then remove that rule from `KNOWN_FINDINGS` and record the fix in the coverage section below.

## Read the result

Read every result with the pstack `/statechart` skill, typed as `/pstack:statechart` in Claude Code.
Give it `verification/engine-lifecycle/EngineLifecycle.tla` and `EngineLifecycle.cfg`.
It gives the shortest path to each broken rule in plain steps, and a chart of the states when every rule holds.
Write its view module in a scratch folder outside the repository.
The script's own trace lists the TLA+ action of each step and the main fields, which is enough to map a step to code.

When a rule breaks unexpectedly, decide which kind of break it is:

- **A real bug.** Every step of the path is something the Swift code allows. Check each step against the code that the comment above its action names. Report the path in the code's words, with the rule and the harm from the table. Do not weaken the rule or change the model to make it pass. Do not change product code to fix it unless the user asks.
- **A modeling error.** A step does something the code cannot do, or two things happen in one step that the code does in separate main-actor jobs. Fix the model so that it matches the code, and say which step was wrong.

A mutant that prints `UNEXPECTED ... holds` means the rule can no longer fail on the change it guards against, so the check is weaker than before. Find out why before you go on.

## Keep the model in step

Each action in the model is one main-actor job or one operating system event, as in the code.
The comment above each operator names the Swift function and line that it describes.
Every action sets the next state with `Step(...)`, which keeps the state space finite. A new action must use it too.

When the script exits with `3`, or when you change covered code on purpose:

1. Run `git diff <sync-commit> -- <covered files>` with the values below, and read each change.
2. For each change that alters what a lifecycle step does, or adds a step, change the matching operator or action in `EngineLifecycle.tla`. A new control that calls `start()`, `stop()`, or `restart()` is a new action, guarded by when the control shows. Update the line numbers in the comments.
3. Run `make verify-engine-lifecycle` again and read the result as above.
4. Commit the code and the model. Then set `sync-commit` below to that commit, in a later commit. Move it only after you checked that the model describes the covered code at that commit.

A change that touches a covered file but no lifecycle step, such as a new label in `Views.swift`, still needs step 4 after you read it.

### Coverage

```text
sync-commit: 4b744c9a
covers: Sources/MiriCore/Engine.swift
covers: Sources/MiriCore/EngineProcess.swift
covers: Sources/Miri/AppModel.swift
covers: Sources/Miri/App.swift
covers: Sources/Miri/Views.swift
covers: Sources/Miri/StopShortcut.swift
covers: Sources/Miri/SettingsWindow.swift
```

The script reads these lines.
The model describes these parts of the files:

- `Engine.swift`: `CrashPolicy`, `EngineState`, and `EngineSupervisor.start()`, `restartManually()`, `stop(completion:)`, and `exited(status:)`.
- `EngineProcess.swift`: `ProcessEngineLauncher.launch(onExit:)`, whose termination handler sends the exit to the main actor, and `RunningEngine.kill()`.
- `AppModel.swift`: `launch()`, `keyboardLayoutChanged()`, `start()`, `stop()`, `stopFromShortcut()`, `restart()`, `prepareToQuit(completion:)`, `pollSetupUntilReady()`, and `cancelSetupPoll()`.
- `App.swift`: `applicationDidFinishLaunching`, `applicationShouldTerminate`, and `quitOnTerminationSignal()`.
- `Views.swift`: `MenuContent` and `GeneralSettings`, which decide when Start, Stop, and Restart show, and `statusText`.
- `StopShortcut.swift`: the hot key handler that calls `stopFromShortcut()`.
- `SettingsWindow.swift` does not exist at the sync commit. When it lands with its Start, Stop, and Restart button, model that button.

## What the check does not cover

- Bounds: 3 process identities, at most 3 stop completions waiting at once (`Step` drops a step that would queue a fourth), and the crash limit of 3. All crashes count as inside the 5-minute window, so a crash never expires.
- The model assumes that the app exits inside `reply(toApplicationShouldTerminate:)`, so completions after the quit reply never run. If AppKit returns first, the later completions run too, and finding 3 still holds because `start` runs before the reply.
- After you choose Quit, the model allows no more clicks or keyboard layout changes.
- The model does not cover window recovery, the engine's own cleanup, `PANERU_PARENT_PID`, orphaned engines at launch, configuration loading, or the gesture test.
- A pass covers this model. It is not a test of the Swift code. Keep the model in step with the code, or the pass means nothing.
