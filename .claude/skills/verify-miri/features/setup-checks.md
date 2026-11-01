# Setup checks

Settings > Setup lists what Miri needs before it can manage windows, such as Accessibility permission and no other window manager running.
A check that blocks start keeps the engine stopped, and Miri starts it once the problem is gone.

## Sub-features

- `competing-manager`: a running `yabai`, `AeroSpace`, or similar shows `Quit <name> before starting Miri.` and `Blocks start`.
- `check-again`: `Check Again` reruns every check.
- `auto-start`: when a blocking problem goes away, Miri starts the engine without a click.
- `permissions`: the Accessibility row. Never change it: the command guard blocks `tccutil reset`, and the permission selftest covers it.

## How to get to it (user POV)

- Settings > Setup.
- The Set Up Miri window on first launch.
- The General page status, which says when Miri waits for setup.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md), with Settings open through `V settings`.
- No real competing window manager runs. `V doctor` lists only Miri processes, so also check with `pgrep -lx yabai`.

- **Clean state.** Run `V ax test press Setup`, then `V ax test dump | rg -A2 "Other window managers"`. It shows `Passed`.
- **Add a blocker.** Run `V standin yabai`, then `V ax test press "Check Again"`. The dump shows `Quit yabai before starting Miri. Miri leaves yabai's configuration untouched.` and `Blocks start`.
- **Blocked start.** Run `V ax test press General`, then press `Stop Window Management` and `Start Window Management`. `V ax test status` prints `Waiting: <check title>`, and `V doctor` shows no engine.
- **Auto-start.** Stop the stand-in by its process ID, which `log.txt` records. Within 4 s a new engine runs, and the status reads `Managing windows`.

## Gotchas

- Never copy an Apple binary to make the stand-in. macOS kills the copy at launch with exit status 137, so the check never sees it. `V standin` compiles its own.
- A stand-in started in a tool call's background job dies when that call ends. `V standin` detaches it and records it for `V end`.
- [#236](https://github.com/samanyudas/miri/issues/236): after repeated engine failures, Restart with a blocker present keeps the failed status while Miri waits. Check its state first.
