# Customize shortcuts

Settings > Shortcuts lists every action with its chords.
The person using Miri adds a chord by recording a key press, removes one, filters the list, and resets to the defaults.
Miri writes each change to `[bindings]` in `config.toml`, and the engine reloads it.

## Sub-features

- `add`: the + button on a row shows a `Type Shortcut` chip and adds the next key press that holds Control, Option, or Command.
  Its accessibility label is `Add Shortcut for <action title>`, and its help text is `Add a shortcut for <action title>`.
  Escape cancels, and so does switching to another app.
- `remove`: the × button on a chip, labeled `Remove <chord> from <action title>` with help text `Remove <chord>`, with the chord in menu symbols such as `⌃⌥H`, removes that chord. It shows while the pointer is on the row.
- `conflict`: a chord that another action holds shows the inline notice `<chord> is already used by <action title>.` and changes nothing.
  A chord that macOS holds asks in an alert, with `Use Anyway` and `Cancel`.
- `filter`: the `Filter shortcuts` field narrows the list.
- `reset`: `Reset to Defaults…` asks `Replace all shortcuts with Miri's defaults?` with `Replace` and `Cancel`.
  `Replace` first copies the file to `config.toml.backups/<id>.toml` beside `config.toml`.

## How to get to it (user POV)

- Settings > Shortcuts.
- Edit `[bindings]` in `~/Library/Application Support/Miri Developer/config.toml` by hand.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md), with Settings open through `V settings`.
- `<run>/backup/config.toml` holds the starting file.

Below, `CFG` is `~/Library/Application Support/Miri Developer/config.toml`.

- **Record the start.** Save `ls "$CFG.backups"` to a file in the run folder, and count the `Reloading configuration file` lines in `engine.log`.
- **Show the page.** Run `V ax test press Shortcuts`, then `V ax test dump | rg "Remove|Add Shortcut"`. It lists one `Remove <chord> from <action>` button per chord, and one `Add Shortcut for <action>` button per row with its help text.
- **Remove a chord.** Run `V ax test press "Remove ⌃⌥H"`. `diff <run>/backup/config.toml "$CFG"` shows `ctrl+alt-h` gone from `window_focus_west`, and `engine.log` has one more `Reloading configuration file` line.
- **Prove the engine reloaded it.** Open two new fixtures. With the right one focused, `V key ctrl+alt-h` leaves focus where it is. `V key ctrl+alt-leftarrow` and `V focused --wait-for` the left fixture exit 0.
- **Add a chord.** Run `V settings`, so Miri is the frontmost app, and press the row's + button by its help text, such as `V ax test press "Add a shortcut for Focus column left"`. The dump shows `Type Shortcut`. Run `V key ctrl+alt-h`. The diff shows the chord added at the end of the row's list.
- **Conflict with an action.** Press `"Add a shortcut for Focus column left"` again, then `V key ctrl+alt-l`. The dump shows `⌃⌥L is already used by Focus column right.`, and the file does not change.
- **Conflict with macOS.** Press the + button again, then `V key ctrl+cmd-space`. The dump shows an alert, `⌃⌘Space is used by macOS for Emoji and Symbols.`, with `Cancel` and `Use Anyway`. Press `Cancel`. The file does not change.
- **Reset.** Press `Reset to Defaults…`, then `Replace` in a second call. The diff shows the default `[bindings]`, and `$CFG.backups/` holds one new file, a copy of the file before the reset.
- **Put it back.** Copy `<run>/backup/config.toml` over `$CFG`, check that `diff` is empty, and delete only the backup files this run added. The engine logs one more reload. Prove a restored chord with `V key` from a fixture.

## Gotchas

- `config.toml` is Sam's real configuration. Always diff it against the backup before `V end`.
- The recorder cancels when another app comes to the front. Run `V settings` right before you press a + button.
- Pressing a button in an alert can return `AXError -25205`, because the alert closes during the press. Read the dump to see whether the alert closed.
- Miri Settings is a floating window, so ⌃⌥← and ⌃⌥→ do nothing while it has focus. Prove a chord from a fixture. [Focus a window with a shortcut](focus-window-shortcut.md) explains this.
- Use ⌃⌘Space for the macOS conflict. If a press reaches macOS, it only opens the emoji picker, while a chord such as ⌃↑ opens Mission Control.
- The `Filter shortcuts` field needs text entry, which `axdo` cannot do. The filter is not drivable yet.
