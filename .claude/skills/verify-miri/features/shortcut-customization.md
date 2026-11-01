# Customize shortcuts

Settings > Shortcuts lists every action with its chords.
The person using Miri adds a chord by recording a key press, removes one, filters the list, and resets to the defaults.
Miri writes each change to `[bindings]` in `config.toml`, and the engine reloads it.

## Sub-features

- `add`: `Add Shortcut` on a row records the next chord and adds it.
- `remove`: `Remove <chord>` removes one chord from a row.
- `conflict`: a chord that another action holds asks `Replace`, and one that macOS holds asks `Use Anyway`.
- `filter`: the `Filter` field narrows the list.
- `reset`: `Reset to Defaults…` restores every default chord.

## How to get to it (user POV)

- Settings > Shortcuts.
- Edit `[bindings]` in `~/Library/Application Support/Miri Developer/config.toml` by hand.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md), with Settings open through `V settings`.
- `<run>/backup/config.toml` holds the starting file.

- **Show the page.** Run `V ax test press Shortcuts`, then `V ax test dump | rg "Remove|Add Shortcut"`. It lists one `Remove <chord>` button per chord.
- **Remove a chord.** Run `V ax test press "Remove <chord>"` with a label from the dump. `diff <run>/backup/config.toml "$HOME/Library/Application Support/Miri Developer/config.toml"` shows the chord gone.
- **Prove the engine reloaded it.** Open two fixtures and press the removed chord with `V key`. Focus does not move. Press a remaining chord, and focus moves.
- **Add a chord.** Not drivable yet: every row has its own `Add Shortcut` button with the same title, and `axdo press` takes the first one. Filtering first needs text entry, which `axdo` cannot do yet.
- **Put it back.** Copy `<run>/backup/config.toml` back before `V end`, or press `Reset to Defaults…` only if the backup had the defaults.

## Gotchas

- This map entry was not run with `V`. The 2026-10-26 run used a separate AX tool, and AppleScript `entire contents` returned nothing on this page.
- `config.toml` is Sam's real configuration. Always diff it against the backup before `V end`.
