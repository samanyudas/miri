# Compare app and engine Accessibility permission

This prototype compares actual Accessibility calls from Miri and its bundled Paneru engine.
It does not start window management or request permission.
It leaves permission attribution unresolved until a manual comparison records the macOS permission entries and explicit grants.
The development bundle uses ad-hoc signatures.
Its observations do not establish Developer ID or notarized-release behavior.

## Build the packaged prototype

Use an arm64 Mac with macOS 27, Swift 6.2 or newer, Rust 1.95 or newer, Cargo, Python 3, and Xcode command-line tools.

```sh
git submodule update --init --recursive
./scripts/build-prototype.sh
./scripts/test-permission-prototype.sh
```

The build requires the engine checkout to match the recorded submodule pin and have no local changes.
During engine-patch development, use `./scripts/build-prototype.sh --allow-dirty-engine`.
The development exception records a `-dirty` suffix in the bundle and observation.
It does not permit a different engine HEAD from the recorded submodule pin.
Commit and pin the engine patch before delivering a reproducible build.

The script builds without Lua and bundles the actual engine at `.build/prototype/Miri.app/Contents/Helpers/miri-engine`.
It signs the engine with `io.github.samanyudas.miri.engine` before signing the app with `io.github.samanyudas.miri`.
The engine's embedded Info.plist uses the same engine identifier.
The bundle includes Miri's GPL license and the engine's MIT notice.

## Read the automated observation

The driver opens a harmless native fixture window and launches the packaged app through Launch Services.
The app's diagnostic mode runs the same observation as **Check permission**, writes an atomic JSON report, and quits.
The driver verifies the real process identities, executable paths, signatures, embedded engine identifier, raw AX results, and child termination.
It also launches a freshly signed app copy whose engine is actually missing.
No trust or AX result is substituted.

The engine's `miri-ax-probe --target-pid <positive-pid>` command runs before logging, configuration discovery, services, sockets, or daemon startup.
It reads `AXIsProcessTrusted()` and the fixture application's `AXRole` attribute.
The app performs the same read independently.
Neither process writes window attributes or enables the permission prompt.
Both set an AX messaging timeout of one second and record its raw return code.
The app gives its owned engine child five seconds and limits each output file to 16 KiB.
Cancellation and Quit kill and reap that child before the app exits.

The driver retains its JSON reports and provenance in the printed temporary evidence directory.
Provenance includes macOS and toolchain versions, source revision, executable hashes, signing identifiers, and the embedded engine plist.
The reported `observed-ungranted` status confirms a completed diagnostic observation with at least one denied trust result.
The reported `observed-granted` status confirms that both executing processes reported trust.
Neither status establishes which permission entry controls the engine.
A missing report, launch failure, timeout, or invalid response fails the driver.

## Compare the visible app before and after an explicit grant

The automated diagnostic mode does not establish that a visible button was clicked.
Use the following manual procedure to inspect the interface and resolve attribution.
Do not reset existing permissions to create an artificial clean state.

1. Start the fixture from the repository root.

   ```sh
   .build/debug/AXFixture &
   fixture_pid=$!
   echo "$fixture_pid"
   open .build/prototype/Miri.app
   ```

2. Enter the fixture process ID in Miri.
3. Click **Check permission**.
4. Record both trust values and raw AX read codes.
5. Click **Open Accessibility Settings**.
6. Record the exact visible permission entries and their current states.
7. Explicitly grant the relevant Miri app or engine entry yourself.
8. Quit and reopen the same packaged app.
9. Repeat the check against the same fixture process.
10. Record which entry changed, both new trust values, and both raw AX read codes.
11. If a second relevant entry exists, repeat the comparison for that entry.
12. Quit Miri and stop the fixture you started.

    ```sh
    kill "$fixture_pid"
    wait "$fixture_pid"
    ```

Record an existing grant as a limitation when it prevents the before-and-after comparison.
Equal trust values alone do not prove that the app permission entry controls the engine.
The prototype remains a prerequisite experiment until this manual comparison is complete.
Production settings, menu bar controls, lifecycle recovery, and window management are outside this change.
