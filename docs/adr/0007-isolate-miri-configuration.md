---
status: accepted
---

# Isolate Miri configuration

Miri owns separate configuration and process identities rather than sharing a standalone Paneru installation's configuration.
This prevents Miri's settings and engine lifecycle from changing the user's standalone Paneru files.
Valid settings changes apply immediately and persist.
The single source of truth is a TOML file at `~/Library/Application Support/Miri/config.toml`.
The app reads and writes it, watches it for external edits, and users can sync it with their dotfiles.
If the file is invalid or cannot be written, the engine keeps the last valid settings.
Miri shows the error and its line in Settings and the menu bar, and never overwrites a file it could not read correctly.
The file reuses Paneru's TOML key names, with a `[miri]` section for app-only settings such as launch at login and updates.
The engine reads the file directly, and Miri passes its path explicitly so that standalone Paneru configuration is never read.
Configuration upgrades create a backup before migration and preserve user values.
If a migration cannot preserve those values, Miri leaves the file untouched and shows an error.
