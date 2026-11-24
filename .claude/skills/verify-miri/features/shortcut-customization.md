# Customize shortcuts

Settings > Shortcuts lists every action with its chords.
The person using Miri adds a chord by recording a key press, removes one, filters the list, and resets to the defaults.
Miri writes each change to `[bindings]` in `config.toml`, and the engine reloads it.
The Stop window manager row writes `[miri].stop_shortcut` instead.

## Sub-features

- `add`: the + button on a row shows a `Type Shortcut` chip and adds the next key press that holds Control, Option, or Command.
  Its accessibility label is `Add Shortcut for <action title>`, and its help text is `Add a shortcut for <action title>`.
  Escape without a modifier cancels, and so does switching to another app.
  Each attempt ends the recording, also a refused one, so every try needs a new + press.
- `remove`: the × button on a chip, labeled `Remove <chord in words> from <action title>`, such as `Remove Control Option H from Focus column left`, with help text `Remove <chord>` in menu symbols such as `Remove ⌃⌥H`, removes that chord. It shows while the pointer is on the row.
- `conflict`: a chord that another action holds shows the inline notice `<chord> is already used by <action title>.` and changes nothing.
  A chord that macOS holds asks in an alert, with `Use Anyway` and `Cancel`.
- `filter`: the search field, with the placeholder `Search actions or shortcuts`, narrows the list by action title or chord. With no match, the page shows `Clear Search`.
- `reset`: `Reset to Defaults…` asks `Replace all shortcuts with Miri's defaults?` with `Replace` and `Cancel`.
  `Replace` first copies the file to `config.toml.backups/<UUID>.toml` beside `config.toml`, when the reset changes the file.

## How to get to it (user POV)

- Settings > Shortcuts.
- Edit `[bindings]` in `~/Library/Application Support/Miri Developer/config.toml` by hand.

## Driving it with verify-miri

Preconditions:

- The baseline from the [index](README.md), with Settings open through `V settings`.
- `<run>/backup/config.toml` holds the starting file.

Below, `CFG` is `~/Library/Application Support/Miri Developer/config.toml`.

- **Record the start.** Check that `diff <run>/backup/config.toml "$CFG"` is empty. Save `ls "$CFG.backups"` to a file in the run folder, and count the `Reloading configuration file` lines in `engine.1.log` and `engine.log` together, because the log rotates.
- **Show the page.** Run `V ax test press Shortcuts`, then `V ax test dump | rg "Remove|Add Shortcut"`. It lists one `Remove <chord in words> from <action>` button per chord, and one `Add Shortcut for <action>` button per row with its help text.
- **Remove a chord.** Run `V ax test press "Remove ⌃⌥H"`. `diff <run>/backup/config.toml "$CFG"` shows `ctrl+alt-h` gone from `window_focus_west`, and the count of `Reloading configuration file` lines rises.
- **Prove the engine reloaded it.** Open two new fixtures. With the right one focused, `V key ctrl+alt-h` leaves focus where it is. `V key ctrl+alt-leftarrow` and `V focused --wait-for` the left fixture exit 0.
- **Cancel by switching apps.** Run `V settings` and press `"Add a shortcut for Focus column left"`. The dump shows `Type Shortcut`. Run `open "<run>/fixtures/<fixture>.app"` and `V focused --wait-for` that fixture. The dump no longer shows `Type Shortcut`.
- **Cancel with Escape.** Run `V settings`, press the + button again, then `V key escape`. The dump no longer shows `Type Shortcut`.
- **Add a chord.** Run `V settings`, so Miri is the frontmost app, and press the row's + button by its help text, such as `V ax test press "Add a shortcut for Focus column left"`. The dump shows `Type Shortcut`. Run `V key ctrl+alt-h`. The diff shows the chord added at the end of the row's list. Copy `$CFG` to `<run>/added.toml`.
- **Conflict with an action.** Run `V settings`, press `"Add a shortcut for Focus column left"` again, then `V key ctrl+alt-l`. `V ax test dump | rg "is already used by Focus column right."` matches, and `cmp <run>/added.toml "$CFG"` shows no change.
- **Conflict with macOS.** Run `V settings`, press the + button again, then `V key ctrl+cmd-space`. The dump shows an alert, `⌃⌘Space is used by macOS for Emoji and Symbols.`, with `Cancel` and `Use Anyway`. Press `Cancel`. The file does not change.
- **Reset.** Press `Reset to Defaults…`, then `Replace` in a second call. The diff shows the default `[bindings]`, and `$CFG.backups/` holds one new file, the same as `<run>/added.toml`.
- **Put it back.** Copy `<run>/backup/config.toml` over `$CFG`, check that `diff` is empty, and delete only the backup files this run added. The engine logs one more reload. Prove a restored chord with `V key` from a fixture.

## Gotchas

- `config.toml` is Sam's real configuration. Always diff it against the backup before `V end`.
- The recorder cancels when another app comes to the front. Run `V settings` right before you press a + button.
- Pressing a button in an alert can return `AXError -25205`, because the alert closes during the press. Read the dump to see whether the alert closed.
- Miri Settings is a floating window, so ⌃⌥← and ⌃⌥→ do nothing while it has focus. Prove a chord from a fixture. [Focus a window with a shortcut](focus-window-shortcut.md) explains this.
- Use ⌃⌘Space for the macOS conflict. If a press reaches macOS, it only opens the emoji picker, while a chord such as ⌃↑ opens Mission Control.
- The dump puts an invisible left-to-right mark (U+200E) on each side of the chord in the conflict notice and the macOS alert, so a match on `⌃⌥L is already used by` fails. Match the text after the chord. The `Remove` labels and help text have no marks.
- The search field shows in the dump as an `AXTextField` with no title, because its label is hidden. `axdo` cannot enter text or focus the field, so the filter is not drivable yet.
