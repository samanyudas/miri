<img src="assets/icon.svg" width="64" height="64" alt="">

# miri

Miri is a macOS scrolling window manager intended for daily use and public release as free and open-source software.
Its native app interface is designed and built from the ground up for this project.
The app bundles a pinned Paneru-based engine as a helper process.

The accepted product direction is recorded in [Release scope](decisions/release-scope.md).
Further quality-of-life candidates are recorded in the [V2 roadmap](decisions/v2-roadmap.md).

## Status

Miri has no release and does not manage windows yet.
The repository contains the product design and a native Accessibility permission prototype.
The prototype makes read-only calls from the app and its bundled engine against a harmless fixture window.
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
open .build/prototype/Miri.app
```

`make setup` checks out the pinned engine, installs the pinned Rust, and reports any missing prerequisite.
`make build` produces an ad-hoc signed `.build/prototype/Miri.app`.
The [permission procedure](docs/prototypes/helper-permission.md) explains what the prototype observes.

## Verify

```sh
make check
```

`make check` runs `make lint` and then `make native`.
`make lint` checks documentation, harness tests, shell scripts, workflows, and declared version compatibility.
`make native` lints Swift and the engine, builds the app, runs the engine unit tests, runs the end-to-end permission selftest, and packages a DMG.
CI runs the same targets on every pull request.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow.

## License

Miri is licensed under the GNU General Public License version 3 or, at your option, any later version.
The SPDX license identifier is `GPL-3.0-or-later`.
The [license text](LICENSE) is included verbatim.
The decision is recorded in [ADR 0004](docs/adr/0004-use-gpl-v3.md).

Created in [T3 Code](https://t3.codes).
