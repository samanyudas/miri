<img src="assets/icon.svg" width="64" height="64" alt="">

# miri

Created in [T3 Code](https://t3.codes).

## Development checks

Start with portable tooling checks.

```sh
scripts/setup.sh --profile portable
scripts/restore-state.sh
scripts/verify.sh
```

On an arm64 Mac with macOS 27, Swift 6.2 or later, and rustup, run the native checks.
Rustup installs the Rust version that `rust-toolchain.toml` pins.

```sh
scripts/setup.sh --profile native
scripts/verify.sh --level gui
```

See [development guidance](docs/agents/harness.md) for verification levels, evidence, hooks, and session handoff.

## Development prototype

Miri currently has a native Accessibility permission experiment.
It bundles a pinned Paneru fork and makes read-only calls from the app and actual engine against a harmless fixture.
It does not start window management.

```sh
git submodule update --init --recursive
./scripts/build-prototype.sh
./scripts/test-permission-prototype.sh
```

See [the permission comparison procedure](docs/prototypes/helper-permission.md) for requirements, automated observations, and the recorded development-bundle grant comparison.
Developer ID and notarized-release permission behavior remain unverified.
