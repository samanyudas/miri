# Start, stop, and restart window management

The person using Miri starts, stops, and restarts window management from Settings > General or the menu bar menu, and stops it with the Stop shortcut.
The status line says what the engine does, and Miri remembers a Stop across launches.

## Sub-features

- `stop`: `Stop Window Management` stops the engine, and the status reads `Stopped`.
- `start`: `Start Window Management` starts it, and the status reads `Managing windows`.
- `restart`: `Restart Engine` replaces the engine process.
- `stop-shortcut`: ⌃⌥Q stops window management from any app.
- `saved-stop`: after a Stop, the next launch leaves windows unmanaged until Start.
- `crash-limit`: after 3 engine crashes within five minutes, the status reads `Stopped after repeated engine failures`.

## How to get to it (user POV)

- Settings > General: the buttons under the status line.
- The menu bar menu, which Sam's bar manager hides on this Mac.
- The Stop shortcut, ⌃⌥Q unless `[miri].stop_shortcut` sets another chord.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md).
- `V settings` printed a status, so the Settings window is open.

- **Show General.** Run `V ax test press General`. Then `V ax test status` prints `Managing windows`.
- **Stop.** Start `V watch 12 &`, then run `V ax test press "Stop Window Management"`. Within 4 s, `V ax test status` prints `Stopped`, the watch log shows the engine's `exit`, and `defaults read io.github.samanyudas.miri.dev managementStopped` prints `1`.
- **Start.** Run `V ax test press "Start Window Management"`. The status returns to `Managing windows`, the watch log shows a new engine, and `managementStopped` prints `0`.
- **Restart.** Run `V ax test press "Restart Engine"`. The watch log shows the old engine's `exit` and a new engine's `start`.
- **Stop shortcut.** Run `V key ctrl+alt-q`. The status reads `Stopped`. Press `Start Window Management` again afterwards.
- **Saved Stop.** Press Stop, then end the run with `V end`. `end` reports the changed `managementStopped` and names the button that puts it back.
- **Crash limit.** Kill only the test engine three times, about 3 s apart. Find its process ID with `V doctor`, or by the path `<test bundle>/Contents/Helpers/miri-engine`, then run `kill -9 <engine pid>`. The status reads `Stopped after repeated engine failures`, and only `Restart Engine` and `Show Logs in Finder` show.
- **Show logs.** In the failed state, press `Show Logs in Finder` in Settings > General or the menu. Finder shows a `Logs` window with `engine.log` selected, and Finder becomes the frontmost app.

## Gotchas

- For timed sequences, press several buttons in one call, such as `V ax test press "Stop Window Management" "Restart Engine"`. Separate calls add about 100 ms each.
- Quit the test build with `kill -TERM <test pid>` for a timed quit. `osascript quit` arrived 3.8 s late in the #234-#236 run.
- Open bugs change the expected results: [#234](https://github.com/samanyudas/miri/issues/234) (Restart then Stop starts the engine again), [#235](https://github.com/samanyudas/miri/issues/235) (Stop then Restart leaves a saved Stop), and [#236](https://github.com/samanyudas/miri/issues/236) (Restart while setup blocks start shows the failed status). Check whether each is fixed before you report one of them as a new defect.
- Every engine restart re-applies the window session and can move Sam's windows. Keep these rounds short.
- The guard blocks `defaults write`. Clear a saved Stop with `Start Window Management` before `V end`.
- The menu bar menu can be driven through System Events as `menu bar item 1 of menu bar 2` of the test app's process, even while the bar manager hides it. Those clicks let no app take the front, not even `Settings…`, so check which app comes to the front from Settings instead.
