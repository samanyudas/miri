<img src="assets/icon.svg" width="64" height="64" alt="">

# miri

Created in [T3 Code](https://t3.codes).

## Development prototype

Miri currently has a native Accessibility permission experiment.
It bundles a pinned Paneru fork and makes read-only calls from the app and actual engine against a harmless fixture.
It does not start window management.

```sh
git submodule update --init --recursive
./scripts/build-prototype.sh
./scripts/test-permission-prototype.sh
```

See [the permission comparison procedure](docs/prototypes/helper-permission.md) for requirements, automated observations, and the remaining manual grant comparison.
