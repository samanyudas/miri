# Security policy

## Supported versions

Miri has no release yet.
Security fixes apply to the `main` branch until the first release.
After that, only the latest stable release receives fixes.

## Report a vulnerability

Report privately through [GitHub security advisories](https://github.com/samanyudas/miri/security/advisories/new).
Do not open a public issue for a vulnerability.
Include the affected version or commit, the steps to reproduce, and the impact you observed.

## Scope

Miri holds the macOS Accessibility permission, which lets it read and move other apps' windows.
If the user turns on window contents on edges next to another display, Miri also holds Screen Recording permission.
These areas are in scope:

- Any path that lets another process use Miri's Accessibility or Screen Recording permission.
- Any capture beyond the edge slices that [ADR 0002](docs/adr/0002-limit-system-access.md) allows.
- The bundled engine helper, its signature, and how the app launches it.
- Configuration parsing and migration.
- Update delivery, once Sparkle updates exist.
- Diagnostics that leak window titles, document paths, usernames, or raw configuration.

Miri sends no telemetry.
A network request other than an update check or download is a bug worth reporting.
