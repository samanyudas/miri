<img src="assets/icon.svg" width="64" height="64" alt="">

# miri

Miri is a macOS scrolling window manager intended for daily use and public release as free and open-source software.
Its native app interface is designed and built from the ground up for this project.
The app bundles a pinned Paneru-based engine as a helper process.

The accepted product direction is recorded in [Release scope](decisions/release-scope.md).
Further quality-of-life candidates are recorded in the [V2 roadmap](decisions/v2-roadmap.md).

## Status

Miri has no release.
The app runs from the menu bar, starts and stops the bundled engine, and owns its configuration file.
It checks macOS setup, recovers stranded windows when the engine stops, and previews redacted diagnostics.
Development builds have run on Sam's Mac with the built-in display and an external display.
The full v1 acceptance checklists have not run.
[Known limitations](docs/limitations.md) lists every known limitation, with its evidence and workaround.
[PROGRESS.md](PROGRESS.md) records the current work and next steps.

## Requirements

- An Apple silicon Mac running macOS 27 or later.
- Xcode 27, which provides Swift 6.2 or newer.
- [rustup](https://rustup.rs).
  The repository pins Rust 1.98.1 in `rust-toolchain.toml`, and `make setup` installs it.
- Python 3.11 or newer, [ShellCheck](https://www.shellcheck.net), and [actionlint](https://github.com/rhysd/actionlint).
  Install the last two with `brew install shellcheck actionlint`.

## Build and run

```sh
git clone --recurse-submodules https://github.com/samanyudas/miri.git
cd miri
make setup
make build
open ".build/app/Miri Developer.app"
```

Opening the app starts window management when Accessibility permission is granted and no setup check blocks it.
To open it without managing windows, run `open ".build/app/Miri Developer.app" --args -managementStopped YES`.
The configuration file is `~/Library/Application Support/Miri Developer/config.toml`.

`make setup` checks out the pinned engine, installs the pinned Rust, creates a local signing identity, and reports any missing prerequisite.
`make build` produces `.build/app/Miri Developer.app`.
Development builds use the name Miri Developer and their own bundle identifier, so they never replace or share permissions with an installed Miri release.
The local signing identity keeps the Accessibility grant across rebuilds.
The [permission procedure](docs/prototypes/helper-permission.md) explains what the prototype observes.

## Verify

```sh
make check
```

`make check` runs `make lint` and then `make native`.
`make lint` checks documentation, harness tests, shell scripts, workflows, and declared version compatibility.
`make native` lints Swift and the engine, builds the app, runs the Swift and engine unit tests, runs the end-to-end permission and window recovery selftests, and packages a DMG.
CI runs the same targets on every pull request.
A pull request that changes only documentation skips `make native` in CI, as `scripts/ci-needs-native.py` decides.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.

## License

Miri is licensed under the GNU General Public License version 3 or, at your option, any later version.
The SPDX license identifier is `GPL-3.0-or-later`.
The [license text](LICENSE) is included verbatim.
The decision is recorded in [ADR 0004](docs/adr/0004-use-gpl-v3.md).

Created in [T3 Code](https://t3.codes).
