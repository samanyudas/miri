# Compare app and engine Accessibility permission

This prototype compares actual Accessibility calls from Miri and its bundled Paneru engine.
It does not start window management or request permission.
Each automated report leaves permission attribution unresolved because it cannot observe the macOS permission entries or explicit grants.
The manual comparison recorded below resolves attribution for the tested development bundle.
The development bundle uses a self-signed local identity or ad-hoc signatures.
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

The script builds without Lua and bundles the actual engine at `.build/prototype/Miri Developer.app/Contents/Helpers/miri-engine`.
It builds the engine with the `miri-developer` feature and signs it as `io.github.samanyudas.miri.dev.engine` before signing the app as `io.github.samanyudas.miri.dev`.
The engine's embedded Info.plist uses the same engine identifier.
It signs with the **Miri Developer Local Signing** identity from `scripts/setup-signing.sh` when it exists, and ad-hoc otherwise.
The bundle includes Miri's GPL license and the engine's MIT notice.

## Read the automated observation

The driver opens a harmless native fixture window and launches the packaged app through Launch Services.
The app's diagnostic mode runs the same observation as **Check permission**, writes an atomic JSON report, and quits.
The driver verifies the real process identities, executable paths, signatures, embedded engine identifier, raw AX results, and child termination.
Reported executable paths must resolve to the expected bundled executables.
The driver also launches a signed bundle copy through both the macOS `/tmp` alias and its physical `/private/tmp` path.
It verifies missing-engine failure with a freshly signed app copy whose engine is actually missing.
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
   open ".build/prototype/Miri Developer.app"
   ```

2. Enter the fixture process ID in Miri.
3. Click **Check permission**.
4. Record both trust values and raw AX read codes.
5. Click **Open Accessibility Settings**.
6. Record the exact visible permission entries and their current states.
7. Explicitly grant the relevant Miri Developer app or engine entry yourself.
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
The prototype remains a prerequisite experiment until this manual comparison is complete for the bundle being evaluated.
Production settings, menu bar controls, lifecycle recovery, and window management are outside this change.

## Recorded development-bundle result on 14 October 2026

This result predates the Miri Developer identity.
The tested bundle used the release identifiers `io.github.samanyudas.miri` and `io.github.samanyudas.miri.engine`.

Sam tested the visible packaged app against fixture process `87151`.
Sam confirmed that only **Miri** was enabled in Accessibility Settings during both grant attempts and that no other entry was enabled.
The manual Settings observations and button results below are user-reported.

| Observation | Miri trusted | Miri AX read | Miri role | Engine trusted | Engine AX read | Engine role |
| --- | --- | --- | --- | --- | --- | --- |
| Before the successful grant | `false` | `-25211` | none | `false` | `-25211` | none |
| After enabling only Miri | `true` | `0` | `AXApplication` | `true` | `0` | `AXApplication` |

The reported engine process changed from `89218` to `94087` between these observations.
The denied observation takes precedence over an assumption that the earlier grant attempt had already taken effect.
The comparison shows that enabling the Miri entry authorizes both the app and its bundled engine in this development setup.
A separate engine grant was not required.
This completes the development prototype prerequisite in ADR 0009.

An agent-run `./scripts/test-permission-prototype.sh` then returned `observed-granted` and passed the missing-helper check.
Its JSON report recorded `trusted: true`, `readCode: 0`, and `role: AXApplication` for both processes.
The fresh fixture, app, and engine process IDs were `96518`, `96520`, and `96524`.
The driver verified executable identities, signatures, and process termination.
The fresh automated observation confirms successful reads after the grant but does not independently inspect Settings.

The tested bundle was `.build/prototype/Miri.app` in `/Users/sam/.t3/worktrees/miri/helper-permission-prototype`.
The source revision was `45b46ef43db75f5e071be70fdf6b3d716a42277f`.
The bundled engine revision was `f1df5873832c980c046fa6d55f7745c8b715e39c`.
The environment was arm64 macOS `27.0`, build `26A428`.
Both executable signatures were ad-hoc, with identifiers `io.github.samanyudas.miri` and `io.github.samanyudas.miri.engine`.
The app executable SHA-256 was `0bc1363700b5c20989bc6c05545c5aa151418cda1ab95e95be21cf17614139e9`.
The engine executable SHA-256 was `d2a63337280d2e95061ae7d4c84a4158ff6d680e0d1523505e9953c4be8c2b77`.
The driver retained `observation.json` and `provenance.json` in `/var/folders/t3/2vf22cfx5llfz64b8719044m0000gn/T/miri-permission-td9ngj7e`.
That temporary evidence directory is local and may be removed by macOS.

The interface still displays **Attribution unresolved** because each report describes only process-level results.
The recorded manual comparison supplies the Settings evidence that the interface cannot obtain.
Developer ID signing, notarized distribution, upgrades, and other macOS versions still require their own permission checks.
