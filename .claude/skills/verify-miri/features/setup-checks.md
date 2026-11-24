# Setup checks

Settings > Setup lists what Miri needs before it can manage windows.
Three checks block start: Accessibility permission, Displays have separate Spaces, and Other window managers.
Five checks only warn: Window-snapping apps, Stage Manager, macOS window tiling, and the four-finger and three-finger strip swipe conflicts.
A check that blocks start keeps the engine stopped when Miri starts it, at launch or from a Start or Restart button, and Miri starts it once the problem is gone.
A blocker that appears while the engine runs does not stop it.

## Sub-features

- `competing-manager`: a running Paneru, AeroSpace, Amethyst, or yabai shows `Quit <name> before starting Miri.` and `Blocks start`.
  Miri finds Paneru and AeroSpace by bundle ID or process name, Amethyst by bundle ID only, and yabai by process name only ([SetupChecker.swift](../../../../Sources/MiriCore/SetupChecker.swift)).
- `snapping-app`: a running Rectangle, Loop, or Magnet shows a warning that names it, and does not block start.
  Miri finds each app by bundle ID only, so a stand-in process cannot trigger it. Open the real app, then press `Check Again`.
  To move a window without a key press, use `open -g "rectangle://execute-action?name=maximize"` or `open -g "loop://direction/maximize"`.
- `check-again`: `Check Again` reruns every check. It only refreshes the rows, and does not stop an engine that already runs.
- `auto-start`: Miri reruns the checks every 2 s while it waits, and starts the engine without a click when no check blocks start.
- `permissions`: the Accessibility row. Never change it: the command guard blocks `tccutil reset`, and the permission selftest covers it.

## How to get to it (user POV)

- Settings > Setup.
- The Set Up Miri window on first launch, which shows the status, the checks that blocked a start, the strip swipe choice, and `Show in Dock`. `V relaunch --initial-setup` shows it.
- The General page banner while Miri waits for setup. Its title reads `Waiting for setup`, and its detail names the check, such as `Waiting for the “Other window managers” check.`
  `V ax test status` and the menu bar menu read `Waiting for setup: <title of the first blocking check>`.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md), with Settings open through `V settings`.
- No real competing window manager runs. `V doctor` lists only Miri processes, so also check with `pgrep -lx yabai`.

- **Clean state.** Run `V ax test press Setup`, then `V ax test dump | rg -A2 "Other window managers"`. It shows `Passed`.
- **Add a blocker.** Run `V standin yabai`, then `V ax test press "Check Again"`. The dump shows `Quit yabai before starting Miri. Miri leaves yabai's configuration untouched.` and `Blocks start`.
- **Check Again leaves the engine running.** Run `V ax test press General`. `V ax test status` still prints `Managing windows`.
- **Blocked start.** Run `V ax test press "Stop Window Management"`, wait until `V ax test status` prints `Stopped by you`, then run `V ax test press "Start Window Management"` in a separate call. `V ax test status` prints `Waiting for setup: Other window managers`, the General page shows `Open Setup` and `Cancel Automatic Start` instead of Start, and `V doctor` shows no engine.
- **Auto-start.** Stop the stand-in by its process ID, which `log.txt` records. Within 4 s a new engine runs, and the status reads `Managing windows`. On 2026-11-25 it took about 1 s.

## Gotchas

- Never copy an Apple binary to make the stand-in. macOS kills the copy at launch with exit status 137, so the check never sees it. `V standin` compiles its own.
- A stand-in started in a tool call's background job dies when that call ends. `V standin` detaches it and records it for `V end`.
- A stand-in cannot trigger the Amethyst check, which matches only a bundle ID.
- `V ax test status` prints nothing while the Setup page shows, because that page has no status text. Press `General` first.
- `Start Window Management` shows only after the engine has exited, up to 3 s after Stop. A press of both titles in one call fails with `no element titled Start Window Management`.
- `Check Again` reads `Checked` for 2 s after a press, so a second press within 2 s finds no `Check Again` button.
- The dump text is in the app's language. Run these checks without `--language`.
