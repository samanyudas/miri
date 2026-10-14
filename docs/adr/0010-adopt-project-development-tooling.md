# ADR 0010: Adopt project development tooling

Status: Accepted.

## Context

Miri has a Swift/Rust permission prototype and established issue, product, architecture, and glossary authorities.
Its development checks need repeatable setup, explicit verification scope, and retained evidence.
The [project boilerplate](../agents/harness-upstream.md) supplies useful commands but also assumes new project registries and shared Git hook configuration.

## Decision

Adapt its shell entrypoints and keep orchestration visible in `scripts/verify.sh`.
Use one standard-library serializer for check results and one environment helper for live readiness and private worktree stamps.
Each result has a status, scope, blocking flag, exit code, duration, log, and artifact list.
Use the ordered levels `repo`, `portable`, `build`, and `gui`, with `portable` as the default.
Unavailable native requirements fail instead of becoming successful skips.

Give each run an independent evidence directory.
Serialize native checks within each checkout because the existing build and driver share local build output.
Compare both source and environment fingerprints when restoring evidence.
Keep dirty and partial handoffs visible without modifying user files.

Install optional Git hooks only through existing worktree configuration, preserving shared configuration and foreign hooks.
Track read-only Claude session restoration and make the command guard an explicit local opt-in.
Treat writing findings as advisory while failing discovery or execution errors.
Preserve and hash-check the upstream writing library and its license.

## Alternatives and synthesis

A direct shell adaptation best preserves upstream usage and native evidence behavior.
A multi-module Python dispatcher would replace most upstream command behavior without improving the existing product boundary.
The selected design borrows its typed result model and concise topic map while retaining shell orchestration.
A shared hooks directory would affect sibling worktrees, so the installer uses worktree configuration exclusively.
A separate architecture manifest or feature registry would duplicate the existing ADR and issue authorities.
Path-only review hints cite the ADRs instead.

## Consequences

Portable checks run on Ubuntu, and native checks run on an arm64 macOS 27 environment.
The `xcode-27` hosted runner is a preview dependency whose availability remains visible in maintenance reports.
Native diagnostic success does not prove manual grant attribution, distribution signing, or release hardware acceptance.
The original build and driver remain callable directly, so callers must avoid concurrent native use within one checkout.
See [development checks](../agents/harness.md) for commands and evidence limitations.
