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
  Before you ask Sam for a hand check, run `end --keep-test-build` instead, so the test build stays as Sam's build.
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
- Records the running build's bundle path.
- Records every strip of the running build in `<run>/backup/layout.json`: each window by window ID and app name, with its Space, row, display, and position in the row.
- Quits the running build with SIGTERM, and waits for its app and engine to exit.
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
| `V fixture --count 2` | Opens AXFixture windows named `fixture-1`, `fixture-2`, and so on. Each one is wrapped in a minimal app in `<run>/fixtures/` and opened with `open`, so macOS brings it forward as when a person opens an app. Each window can resize, so the engine tiles it as a column. `--fixed` makes a window that cannot resize, which the engine floats. `--min-height 1100` makes a window that refuses a frame shorter than 1100 points, as an app with a minimum height does. `--width 2560 --display 3` opens a window 2560 points wide at the top left of display 3, as an app that remembers its size does. `--background` opens it without taking focus, as an app that an updater relaunches does. `--hidden` opens it hidden, as a login item set to hide does. |
| `V show fixture-1 [--timeout 2]` | Shows a hidden fixture app, as a click on its Dock icon does. Exits 1 unless the engine tiles its window within `--timeout` seconds, and logs how long it took. |
| `V key "ctrl+alt-leftarrow"` | Presses a chord, written as in `config.toml`, at the HID event tap. |
| `V focused [--wait-for fixture-1]` | Prints the engine's focused window and macOS's frontmost app, named as fixtures. With `--wait-for`, exits 1 unless both views show that fixture within `--timeout` seconds (3 by default). |
| `V snapshot <label>` | Writes `<label>.json` (the focus record and every fixture's frame, focus, visibility, and floating state) and one PNG per fixture window. |
| `V settings` | Reopens the test app, which shows Settings, as a user does from Finder or Spotlight. |
| `V relaunch [--language de]` | Quits the test build with SIGTERM and opens it again, to check what it keeps across launches, such as a saved Stop. A build that starts no engine is a result, not a failure. `--language` starts it in that language through `-AppleLanguages`, without changing the Mac's language. |
| `V ax test press "General"` | Presses Settings pages and buttons by title, accessibility description, or help text, in order. It looks for each one again after the previous press, so a page and a button on it work in one call. `dump` lists every element with its help text, `status` prints the status text of the page that shows, and `windows` lists window numbers. |
| `V empty-display` | Hides each app with a managed window on the built-in display, so the display has none. `end` shows the apps again. [Empty a display](#empty-a-display) has the steps. |
| `V standin yabai` | Runs a harmless compiled process named `yabai`, so the Setup page reports a competing window manager. |
| `V watch 12` | Logs every Miri app and engine start and exit for 12 seconds, at 50 ms intervals. Start it in the background before a fast sequence. |
| `V query active` | Prints engine state. Window titles can be private. Never paste titles other than the fixtures'. |
| `V send-cmd window focus first` | Sends an engine command, for setup only. |
| `V renew --owner "<thread>" --minutes 15` | Extends the lock for a long run. |

Use stable handles:

- Fixtures by name and window ID, never by position or another app's title.
- Settings controls by title: the sidebar pages `Setup`, `General`, `Layout`, `Shortcuts`, `Gestures`, `Diagnostics`, and buttons such as `Start Window Management`, `Stop Window Management`, `Restart Engine` (on Diagnostics), `Check Again` (on Setup).
  When several buttons share a title, use the help text that `dump` shows, such as `Add a shortcut for Focus column right`.
- Shortcuts by the chord in `config.toml`, which [Bindings.swift](../../../Sources/MiriCore/Bindings.swift) writes.

The feature map in [features/README.md](features/README.md) has one recipe per feature.

### Empty a display

Some tests need a display that has only the run's fixtures.
Since [#364](https://github.com/samanyudas/miri/issues/364), the engine keeps one strip per native Space and has no command that switches to an empty strip.
Hide the apps that have windows there instead:

1. Run `V empty-display` after `begin` and before `V fixture`.
   It hides, as Command-H does, each app that has a managed window on the built-in display, in any Space.
   Pass `--display <id>` for another display, with an ID from `V query state`.
   It then waits until `query state` shows no window on that display other than the run's fixtures, and exits 1 if one stays.
2. A new fixture opens on the display that has focus, which is now the other display.
   After each `V fixture`, move it with `V send-cmd window movedisplay <direction>`, such as `south` for the built-in display under Sam's external display.
   Check with `V query state` that each fixture names the emptied display.
3. Run the test.
4. Run `V end`. Its first step shows the hidden apps again, before it puts back the session and Sam's build.
   The layout check then proves that every window is back in the strip, display, and position it had at `begin`, and within 2 points of its width then.

A hidden app hides its windows on every display, so the other display can lose windows too.
The engine takes hidden windows out of their strips and returns each one to its old slot when the app shows again.
Engines before `4b640f7` tile the windows of an app that was hidden before the engine started, when the app still lists them over Accessibility, as Beeper does ([#374](https://github.com/samanyudas/miri/issues/374)).
A hidden fixture app is not affected, because Accessibility lists no window for it.
For an app that is already hidden, `empty-display` shows it for a moment and hides it again, and `end` leaves it hidden.
Do not move windows to another display to empty one: the session restore keeps each window on the display that macOS reports, so `end` then reports `MOVED:` lines.

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

1. Stops the fixtures and stand-ins this run started, by recorded process ID, and shows the apps that `empty-display` hid.
2. Quits the test build with SIGTERM and waits for its engine to exit.
   If a Miri app or engine from the run still runs, `end` stops here, keeps the lock and the run record, and exits 1, because that engine can overwrite the session when it exits. Stop that process by its ID, then run `end` again.
3. Copies the session backup back to `state.json`.
4. Opens the build that ran before, and waits for its session restore line.
5. Compares `managementStopped` with the backup, and reports a difference.
   The command guard blocks `defaults write`, so put it back with the Settings button that the report names.
6. Compares the restored build's strips with `layout.json`.
   It prints a `MOVED:` line for each window that is in another strip, on another display, in another position, or that floats or tiles differently.
   The tabs of one native tab group, as the session backup records them, count as one column, because the app decides their order.
   It lists windows that are no longer managed, such as a window Sam closed during the run, but does not fail for them.
   When a window moved, `end` stops here, keeps the lock and the run record, and exits 1.
7. Releases the lock and deletes `~/.cache/miri/verify-miri/current.json`.

It never deletes the run folder.

When `end` prints `MOVED:` lines, put each window back with `V send-cmd`, which reaches the restored build at this point.
For example, `window movedisplay east` moves the focused window to the display on the right, and `window swap west` moves it one column left.
Then run `end` again with the same `--owner`.
It does not relaunch anything, and checks the layout again.
Pass `--accept-layout` only when Sam says that the current layout is right.

The `matched` count in the session restore line does not prove that the windows are back.
The session restore keeps each window in the Space where macOS files it now, so `matched` also counts a window on the wrong display.
The layout check in step 6 is the proof.

## Lessons from earlier live runs

- Quit Miri with SIGTERM to the app's process ID when timing matters.
  `osascript quit` reached the app 3.8 s late in one run, and missed a 2-second race.
- Compile a stand-in process, as `V standin` does. macOS kills a copy of an Apple binary, such as `/bin/sleep` renamed `yabai`, at launch with exit status 137.
- Synthetic shortcuts match only when the event flags carry the left-side modifier bits. Arrow keys also need the numeric-pad and Fn flags that a real keyboard sets. `V key` sets both.
- A synthetic event built from the HID system state inherits any modifier that state still reports as held.
  `V key` therefore releases its modifiers after each press. Set the flags of your own synthetic clicks to none, because a click with a leftover Command and Option hides every other app.
- A process started from a background shell cannot become the frontmost app. Open a window through `open` on an app bundle, as `V fixture` does.
- The engine floats every window that cannot resize, and column shortcuts skip floating windows.
- Find processes by executable path, never by name or by a match anywhere in the command line. A shell whose command line contains a Miri path matches `pgrep -f`. In a 2026-11-05 run, such a match most likely killed the run's own shell. Compare the executable column of `ps -axo pid=,comm=` with the full path.
- Synthetic Control-Arrow does not switch Spaces, and synthetic title-bar drags and trackpad swipes do not act like Sam's hands. Ask Sam for those checks, after you launch the build under test as [Hand a check to Sam](../../../docs/AI-CONTRIBUTIONS.md#hand-a-check-to-sam) says.
- macOS can renumber Spaces, for example after the Dock restarts, so a restored session can name a Space that no longer exists. Compare the restore line's `missing` count with the count at `begin` before you trust a restore.

## Helpers

| File | Role |
| --- | --- |
| [scripts/verify-miri](scripts/verify-miri) | The command above. `V --help` and `V <command> --help` list every option. |
| [scripts/tools/axdo.swift](scripts/tools/axdo.swift) | Reads and presses Accessibility elements, lists window numbers, finds the built-in display, and hides and shows apps. |
| [scripts/tools/key.swift](scripts/tools/key.swift) | Posts one key press with given flags at the HID event tap. |
| [scripts/tools/standin.c](scripts/tools/standin.c) | The sleeping stand-in process. |

`V tools` compiles the three tools into `~/.cache/miri/verify-miri/tools/`. Other commands compile them when their source changes.
[scripts/tests/test_verify_miri.py](../../../scripts/tests/test_verify_miri.py) runs in `make lint`. It checks that every key in the default shortcuts has a key code here.
The shell that runs `V` needs the macOS Accessibility permission, which T3 Code already has on this Mac.
