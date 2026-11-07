# Start, stop, and restart window management

The person using Miri starts, stops, and restarts window management from the Settings window or the menu bar menu, and stops it with the Stop shortcut.
The status line says what the engine does, and Miri remembers a Stop across launches.

## Sub-features

- `stop`: `Stop Window Management` stops the engine, and the status reads `Stopped`.
- `start`: `Start Window Management` starts it, and the status reads `Managing windows`.
- `restart`: `Restart Engine` replaces the engine process.
- `stop-shortcut`: ⌃⌥Q stops window management from any app. After a Stop, the shortcut does nothing until Start.
- `saved-stop`: after a Stop, the next launch leaves windows unmanaged until Start.
- `crash-limit`: after 3 engine crashes within five minutes, the status reads `Stopped after engine failures`, with the reason `The engine stopped unexpectedly 3 times within five minutes. Miri stopped restarting it.`
- `waiting`: while a setup check blocks start, the status reads `Waiting for setup: <check title>`, and `Cancel Automatic Start` shows where Start would be. It stops Miri as `Stop Window Management` does. [Setup checks](setup-checks.md) drives it.

## How to get to it (user POV)

- The Settings sidebar button, on every page. It reads `Stop Window Management`, `Start Window Management`, `Cancel Automatic Start`, or `Restart Engine`, the same titles as the page and menu buttons.
- Settings > General: the banner buttons while management is paused, waiting for setup, or failed.
- Settings > Diagnostics: `Restart Engine` while the engine runs or restarts, and in the failure banner after it failed.
- The menu bar menu, which Sam's bar manager hides on this Mac.
  It shows the same status and buttons, and a `Configuration error on line N: …` line when `config.toml` has an error.
- The Stop shortcut, ⌃⌥Q unless `[miri].stop_shortcut` sets another chord.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md).
- `V settings` printed a status, so the Settings window is open.

- **Show General.** Run `V ax test press General`. Then `V ax test status` prints `Managing windows`.
- **Watch.** Start `V watch 90` in the background, with its output in a file, so it logs every engine `start` and `exit` during the steps below.
- **Restart.** Run `V ax test press Diagnostics "Restart Engine"`. The watch log shows the old engine's `exit` and a new engine's `start`.
- **Stop shortcut.** Run `V key ctrl+alt-q`. The status reads `Stopped`, the watch log shows the engine's `exit`, and `defaults read io.github.samanyudas.miri.dev managementStopped` prints `1`. Only `Start Window Management` shows. Press ⌃⌥Q again: nothing changes, and no engine starts.
- **Start.** Run `V ax test press "Start Window Management"`. The status returns to `Managing windows`, the watch log shows a new engine, and `managementStopped` prints `0`.
- **Stop.** Run `V ax test press "Stop Window Management"`. Within 4 s, `V ax test status` prints `Stopped`, and `managementStopped` prints `1`.
- **Saved Stop.** While stopped, run `V relaunch`. It logs `relaunched test build pid <n> with no engine`, and `V doctor` shows no engine. Run `V settings`, press `General`, and check that the status reads `Stopped`. Then press `Start Window Management`.
- **Crash limit.** Kill only the test engine three times, about 3 s apart, with `kill -9 <engine pid>`. Take each process ID from `V doctor`, or from `ps -axo pid=,comm=` where the executable is `<test bundle>/Contents/Helpers/miri-engine`. The status reads `Stopped after engine failures`, the General banner shows the reason with `Restart Engine` and `Show Logs in Finder`, and the sidebar button reads `Restart Miri`.
- **Show logs.** In the failed state, press `Show Logs in Finder` in Settings > General or the menu. Finder becomes the frontmost app, with a `Logs` window and `engine.log` selected. Close that Finder window afterwards.
- **Recover.** Press `Restart Engine`. The status reads `Managing windows`.

## Gotchas

- For timed sequences, press several buttons in one call, such as `V ax test press "Stop Window Management" "Restart Engine"`. Separate calls add about 100 ms each. `axdo` looks for each title again after the previous press, so `V ax test press General "Stop Window Management"` works from another page.
- `V settings` and `V ax test status` print the status text that Settings marks with the accessibility identifier `miri.status`, on the page that shows. Settings reopens on the last page, which can be Gestures, whose status reads `Off until tested: not tested yet`. Press `General` before you read the status.
- Never find the engine by matching a whole command line. A shell whose command holds the engine path matches too, and a `kill` then stops that shell.
- Quit the test build with `kill -TERM <test pid>` for a timed quit. `osascript quit` arrived 3.8 s late in the #234-#236 run.
- [#234](https://github.com/samanyudas/miri/issues/234), [#235](https://github.com/samanyudas/miri/issues/235), and [#236](https://github.com/samanyudas/miri/issues/236) closed on 2026-11-01.
  Stop right after Restart now keeps Miri stopped, Restart clears a saved Stop, and Restart while a setup check blocks start shows `Waiting for setup: <check title>`.
  Report any of the old results as a regression.
- Every engine restart re-applies the window session and can move Sam's windows. Keep these rounds short.
- The guard blocks `defaults write`. Clear a saved Stop with `Start Window Management` before `V end`. Never end a run while stopped: the previous build reads the same saved Stop and starts no engine, so Sam's windows stay unmanaged.
- The menu bar menu opens through System Events as `menu bar item 1 of menu bar 2` of the test app's process, even while the bar manager hides it. A System Events click on a menu item lets no app take the front, not even `Settings…`. To check which app comes to the front, open the menu that way, read the item's `position` and `size`, and click its center with a mouse event posted at the HID event tap.
