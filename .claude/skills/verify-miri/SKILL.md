---
name: verify-miri
description: Drive Miri Developer on Sam's real Mac desktop and prove a user-facing behavior end to end, such as a shortcut that focuses or moves a window, a Settings control, or a setup check. Use it to confirm a change works in the running app, to reproduce a bug before fixing it, or to verify an issue's acceptance criteria. For the TLA+ model check of engine start, stop, and quit, use verify-engine-lifecycle instead.
---

# Verify Miri Developer

Miri Developer is a menu bar app that runs a window manager engine, `miri-engine`.
A user touches it through global shortcuts, trackpad swipes, window drags, and the Settings window.
This skill drives the shortcuts and Settings the way a user does, reads the result from both the engine and macOS, and keeps the proof outside the repository.

Every command below runs from the repository root of the checkout you test.
`V` stands for `.claude/skills/verify-miri/scripts/verify-miri`.

## Rules

- There is one desktop and one Miri Developer.
  Two builds cannot run side by side, because they share the engine's Mach service, the window session file, and user defaults.
  A run therefore replaces Sam's running build, and must put it back.
- Every drive runs between `V begin` and `V end`.
  `end` and `renew` take the same `--owner` as `begin`, and refuse a run that another thread owns, because the run record is shared by every thread on this Mac.
  When `begin` fails because another thread's run is in progress, wait for the lock. Never run `end` for it.
  `begin` takes the [live-test lock](../../../docs/AI-CONTRIBUTIONS.md#take-the-live-test-lock), backs up the window session, and swaps in the test build.
  `end` puts back the session and Sam's build, and releases the lock.
  Run `end` also after a failure.
- Reading `V doctor`, `V query`, logs, or the AX tree is not a drive and needs no lock.
- Run `V doctor` right before `begin`.
  If its idle line says Sam used the Mac in the last minute and Sam did not ask for this run, ask before you drive.
  Check running T3 threads for a recent "testing live" message too. The lock covers agents, not Sam.
- Evidence stays in `~/.cache/miri/verify-miri/runs/<run id>/`.
  Never commit it, attach it, or upload it.
  [Capture evidence](../../../docs/AI-CONTRIBUTIONS.md#capture-evidence) says how Sam approves media for a PR.
- Prove behavior through the user's path: a key press, an AX press on a visible control, or an app that opens a window.
  `V send-cmd` sends engine commands directly. Use it only to set up a starting state, never as the proof.

## Launch

1. Build the test bundle with the repository's own command.
   `make build` writes `.build/app/Miri Developer.app` and `.build/debug/AXFixture`.
   On this Mac's nearly full disk, run `CARGO_INCREMENTAL=0 CARGO_PROFILE_DEV_DEBUG=0 make build`.
   A fresh worktree needs `git submodule update --init vendor/paneru` first. Its first engine build takes several minutes.
2. Run `V doctor`. Every line must be `ok`.
3. Run `V begin --owner "<thread name and id>" --minutes 15 --task "<what the run does>"`.
   Pass `--app <bundle>` to test another build.

`begin` does these steps and logs each one:

- Takes the lock, or stops and prints the holder.
- Copies `config.toml` and the app's user defaults to `<run>/backup/`.
- Records the running build's bundle path, quits it with SIGTERM, and waits for its app and engine to exit.
- Copies `state.json` (the window session) to `<run>/backup/`. The engine saves the session when it exits, so this copy comes after the quit.
- Opens the test bundle and waits until it is usable: the engine runs, logs `Session restore applied`, and answers `query active`.
  A launch prints a line such as `ready after 2.3 s: Session restore applied: matched=12, strips=2, missing=0`.

When the test build starts no engine, `begin` fails with the Settings status.
The usual causes are a saved Stop (`managementStopped = 1`) or a setup check that blocks start.
Run `V end --owner "<thread name and id>"` at once in that case.

## Doctor

`V doctor` is read-only and safe at any time. It exits 1 on any `FAIL` line and reports:

- the lock holder and the keyboard and trackpad idle time
- every running Miri Developer app and engine, an orphan engine, and an engine whose binary was rebuilt after launch
- the test bundle, its engine revision, and the checkout HEAD
- the AXFixture binary, the session file, free disk space, and the compiled helper tools
- during a run: whether the running app is this run's test build, and whether this run holds the lock
- whether the engine answers, the Settings status text, and `managementStopped`

Run it first whenever anything looks wrong.

## Drive

Each drive command logs to `<run>/log.txt` with a timestamp.

| Command | It does |
| --- | --- |
| `V fixture --count 2` | Opens AXFixture windows named `fixture-1`, `fixture-2`, and so on. Each one is wrapped in a minimal app in `<run>/fixtures/` and opened with `open`, so macOS brings it forward as when a person opens an app. Each window can resize, so the engine tiles it as a column. `--fixed` makes a window that cannot resize, which the engine floats. |
| `V key "ctrl+alt-leftarrow"` | Presses a chord, written as in `config.toml`, at the HID event tap. |
| `V focused [--wait-for fixture-1]` | Prints the engine's focused window and macOS's frontmost app, named as fixtures. With `--wait-for`, exits 1 unless both views show that fixture within `--timeout` seconds (3 by default). |
| `V snapshot <label>` | Writes `<label>.json` (the focus record and every fixture's frame, focus, visibility, and floating state) and one PNG per fixture window. |
| `V settings` | Reopens the test app, which shows Settings, as a user does from Finder or Spotlight. |
| `V ax test press "General"` | Presses Settings tabs and buttons by title. `dump` lists every element, `status` prints the General page status, and `windows` lists window numbers. |
| `V standin yabai` | Runs a harmless compiled process named `yabai`, so the Setup page reports a competing window manager. |
| `V watch 12` | Logs every Miri app and engine start and exit for 12 seconds, at 50 ms intervals. Start it in the background before a fast sequence. |
| `V query active` | Prints engine state. Window titles can be private. Never paste titles other than the fixtures'. |
| `V send-cmd window focus first` | Sends an engine command, for setup only. |
| `V renew --owner "<thread>" --minutes 15` | Extends the lock for a long run. |

Use stable handles:

- Fixtures by name and window ID, never by position or another app's title.
- Settings controls by title: tabs `General`, `Layout`, `Gestures`, `Shortcuts`, `Setup`, `Diagnostics`, and buttons such as `Start Window Management`, `Stop Window Management`, `Restart Engine`, `Check Again`, `Add Shortcut`.
- Shortcuts by the chord in `config.toml`, which [Bindings.swift](../../../Sources/MiriCore/Bindings.swift) writes.

The feature map in [features/README.md](features/README.md) has one recipe per feature.

## Evidence

A proof has these parts, all in the run folder:

- `log.txt`: every step with its time, including the build that ran, the lock, the key press, and the session restore result.
- One `snapshot` before the action and one after each action. The JSON shows both views of focus: the engine's `focused_window_id` and macOS's frontmost process.
- The fixture PNGs. The focused fixture shows colored window buttons, and the others show grey ones.
- For a side effect, a second view of it: `defaults read io.github.samanyudas.miri.dev <key>`, a `config.toml` diff against `<run>/backup/config.toml`, or engine log lines from `~/Library/Application Support/Miri Developer/Logs/engine.log`.

A proof fails when only one view changed.
For example, the engine reports a new focus while macOS keeps another app in front.
Report that as a failure. Do not wait longer or retry until it passes.

## Cleanup

`V end --owner "<thread name and id>"` does these steps, and continues past a failed step:

1. Stops the fixtures and stand-ins this run started, by recorded process ID.
2. Quits the test build with SIGTERM and waits for its engine to exit.
   If a Miri app or engine from the run still runs, `end` stops here, keeps the lock and the run record, and exits 1, because that engine can overwrite the session when it exits. Stop that process by its ID, then run `end` again.
3. Copies the session backup back to `state.json`.
4. Opens the build that ran before, and waits for its session restore line.
5. Compares `managementStopped` with the backup, and reports a difference.
   The command guard blocks `defaults write`, so put it back with the Settings button that the report names.
6. Releases the lock and deletes `~/.cache/miri/verify-miri/current.json`.

It never deletes the run folder.
After `end`, check that `log.txt` shows `matched=<n>, ... missing=0` for the restored build, the same count as at `begin`.
A lower count with `missing=0` usually means Sam closed a window during the run.

## Lessons from earlier live runs

- Quit Miri with SIGTERM to the app's process ID when timing matters.
  `osascript quit` reached the app 3.8 s late in one run, and missed a 2-second race.
- Compile a stand-in process, as `V standin` does. macOS kills a copy of an Apple binary, such as `/bin/sleep` renamed `yabai`, at launch with exit status 137.
- Synthetic shortcuts match only when the event flags carry the left-side modifier bits. Arrow keys also need the numeric-pad and Fn flags that a real keyboard sets. `V key` sets both.
- A process started from a background shell cannot become the frontmost app. Open a window through `open` on an app bundle, as `V fixture` does.
- The engine floats every window that cannot resize, and column shortcuts skip floating windows.
- Find processes by executable path with `ps -axww`, never by name. A shell whose command line contains a Miri path matches `pgrep -f`.
- Synthetic Control-Arrow does not switch Spaces, and synthetic title-bar drags and trackpad swipes do not act like Sam's hands. Ask Sam for those checks.
- macOS can renumber Spaces, for example after the Dock restarts, so a restored session can name a Space that no longer exists. Compare the restore line's `missing` count with the count at `begin` before you trust a restore.

## Helpers

| File | Role |
| --- | --- |
| [scripts/verify-miri](scripts/verify-miri) | The command above. `V --help` and `V <command> --help` list every option. |
| [scripts/tools/axdo.swift](scripts/tools/axdo.swift) | Reads and presses Accessibility elements, and lists window numbers. |
| [scripts/tools/key.swift](scripts/tools/key.swift) | Posts one key press with given flags at the HID event tap. |
| [scripts/tools/standin.c](scripts/tools/standin.c) | The sleeping stand-in process. |

`V tools` compiles the three tools into `~/.cache/miri/verify-miri/tools/`. Other commands compile them when their source changes.
[scripts/tests/test_verify_miri.py](../../../scripts/tests/test_verify_miri.py) runs in `make lint`. It checks that every key in the default shortcuts has a key code here.
The shell that runs `V` needs the macOS Accessibility permission, which T3 Code already has on this Mac.
