# App and engine permission prototype

This first implementation addresses ADR 0009 before broader app implementation.
Sam authorized implementation and pull requests on 14 October 2026.
It does not resolve the open stacking or release-duration decisions.

## Contract

- Use the real Paneru executable from the existing fork, based on the selected `v0.5.2` revision.
- Pin the exact patched engine commit as `vendor/paneru`.
- Package a native Swift app with bundle ID `io.github.samanyudas.miri`.
- Embed and sign the engine with identity `io.github.samanyudas.miri.engine`.
- Query actual Accessibility trust in both processes.
- Perform only a read-only Accessibility operation against a controlled fixture process.
- Never start window management, load standalone configuration, install services, write window attributes, reset permissions, or request permission automatically.
- A denied permission result is an observation, not successful permission-attribution validation.
- Record raw Accessibility results, process identities, and executable provenance.
- Bound helper execution and reap only owned children.
- Launch the packaged app through Launch Services for automated observations.
- Preserve a manual comparison of System Settings entries and results before and after an explicit user grant.
- Stop before production settings, lifecycle, recovery, or window-management implementation while permission attribution remains unresolved.

## Design

SwiftPM owns native compilation.
One packaging script owns the app bundle and signs the engine before the enclosing app.
A diagnostic command inside Paneru owns its real Accessibility calls and JSON response.
The Swift app owns one complete observation and presents its result.
An enum represents idle, observation in progress, observed report, and failure states.
One packaged process driver creates a harmless native fixture and validates process outcomes and the observation report.
The driver does not substitute permission results or establish that a visible button was clicked.

## Synthesis

Two architecture candidates compared a command in the actual engine with a separate Swift permission helper.
The independent judge selected the engine command because the surrogate helper cannot establish Paneru permission attribution.
Both candidates selected SwiftPM packaging over an Xcode project for this bounded experiment.
The selected design also records explicit executable and signature evidence from the other candidate.
The alternative Xcode project would add target configuration without removing the required Rust provenance and runtime checks.

## Throughput checkpoint

- Blocking first steps were source inspection, a baseline engine build, and independent architecture comparison.
- Architecture candidates wrote separate temporary artifacts.
- One implementation owner holds this isolated worktree and its engine checkout.
- App and engine implementation stay together because their diagnostic schema and package identity must agree.
- Independent review starts after the implementation owner stops.
- Engine and app commits are verified and published separately.

## Verification and completion

Build and sign the actual app and engine.
Run the packaged observation against the actual native fixture.
Verify missing-helper failure behavior without substituting an Accessibility result.
Record observed trust and read outcomes separately from manual attribution results.
Review the source independently before publishing the engine and app pull requests.
The prototype can be reviewable while the human permission-grant comparison remains pending.
Ad-hoc development signing does not establish Developer ID or notarized-release behavior.
