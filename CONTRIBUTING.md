# Contributing to Miri

Miri is licensed under GPL-3.0-or-later, and contributions are accepted under the same license.
The project is in its design and prototype stage, so check [PROGRESS.md](PROGRESS.md) and the open issues before you start.

## Set up

Follow the requirements and build steps in the [README](README.md#requirements).
Run `make setup` after every engine pin or toolchain change.
It also creates the **Miri Developer Local Signing** identity in its own keychain, so your Accessibility grant survives rebuilds.
Development builds are named Miri Developer with bundle identifier `io.github.samanyudas.miri.dev`, so they never replace an installed Miri release.
It reports each missing prerequisite with the command that fixes it.

## Plan the change

Discuss a substantial change in an issue first, using the task or feature template.
The issue states the outcome, acceptance criteria, and the verification level.
Read [release scope](decisions/release-scope.md) and [design tree status](decisions/design-tree-status.md) before you propose product behavior.
Some features are deliberately deferred to v2.

Engine changes start on the fork's `miri/v0.5.2` branch in `samanyudas/paneru`.
Contribute compatibility fixes upstream where possible, then repin `vendor/paneru`.
Upgrade the engine one Paneru release tag at a time.

## Verify

Run `make check` before you open a pull request.
CI runs the same targets, so a local pass predicts a CI pass.

| Target | What it proves |
| --- | --- |
| `make docs` | Relative links and heading anchors resolve, no em dash appears, and the agent map and handoff record are well formed. |
| `make harness-tests` | The docs check and the command guard behave as documented. |
| `make shell`, `make actions` | Shell scripts and workflows pass ShellCheck and actionlint. |
| `make compat` | Declared macOS minimums agree, the Rust pin satisfies the engine, and the engine pin is published on the fork branch. |
| `make swift-lint`, `make engine-lint` | Swift formatting, rustfmt, and Clippy with warnings as errors. |
| `make build`, `make test` | The signed app bundle builds, and the Swift and engine unit tests pass. |
| `make e2e` | The packaged app and engine run a real Accessibility observation through Launch Services. |
| `make package` | Miri Developer packs into a DMG that mounts with valid signatures. |

`make e2e` reports `observed-ungranted` on a Mac without the Accessibility grant, which is a pass.
It never establishes which permission entry controls the engine.
That needs the manual procedure in the [permission prototype record](docs/prototypes/helper-permission.md).

Window behavior also needs hardware checks from the [v1 acceptance checklist](decisions/v1-acceptance-checklist.md).
State which displays and arrangement you tested, and state what remains untested.

## Open a pull request

Use the [template](.github/PULL_REQUEST_TEMPLATE.md).
Name the title `type(scope): imperative summary`, for example `fix(engine): keep stacked windows reachable`.
Open unfinished work as a draft and name what is missing.
Leave version bumps and release notes to the maintainer.

Reference each issue on its own line.
Use `Refs` only when the pull request delivers what the issue asks for:

```text
Refs #123
```

Use `Part of` when the pull request only records decisions, changes documentation, or delivers part of the issue:

```text
Part of #124
```

These references link the pull request to the issue without changing its status.
Use issue references rather than GitHub closing keywords such as `Closes`, `Fixes`, or `Resolves`.
Closing keywords close the issue on merge before an agent verifies the landed change.

## Review and merge

Sam reads the diff and the verification evidence of every pull request.
Hardware-dependent behavior needs Sam's hardware result.

Agents never merge.
The command guard blocks `gh pr merge`, and Sam decides every merge.
CodeRabbit posts a summary on each pull request.
Treat its findings as input, not as a review verdict.

## Issue lifecycle

Agents own issue verification and closure.
Implementation issues stay open until their changes have merged and an agent verifies every acceptance criterion on the landed code.
Investigation or decision issues can close once their required answer and evidence are recorded.
Neither a merged pull request nor a cross-reference proves completion.
GitHub Actions does not manage issue completion, and silence is never evidence of completion.

1. Read the issue's full acceptance criteria and the changes or answer that address them.
2. Record the verified artifact and, for code changes, the exact merged revision and applicable bundled engine pin.
3. Verify every criterion on that artifact.
   Follow the [evidence standards](docs/AI-CONTRIBUTIONS.md#evidence-standards) and the issue's required verification level.
   Window behavior needs the relevant native checks and any required [hardware checks](decisions/v1-acceptance-checklist.md).
   Record Sam's hardware results where required, and distinguish them from automated observations.
4. Post a concise issue comment with the verified artifact, applicable revisions, commands, observed results, evidence links, and remaining limits.
   If any criterion is incomplete, partial, or unverified, record the gaps and leave the issue open.
5. When evidence proves every criterion, close the issue with `gh issue close <number> --reason completed`.
6. Search [Known limitations](docs/limitations.md) for the issue number.
   Remove or narrow each entry that the verified fix clears, in a pull request.
   Keep the entry if the limitation remains, and add the gap that the issue comment records.

Close a verified issue without waiting for a release or reporter silence.
Release distribution acceptance, including installation and updates, remains separate from individual issue completion.
If an issue explicitly requires release distribution evidence, that criterion still needs verification before closure.
Sam continues to own merges and releases.

The legacy labels `fixed (pending release)` and `please confirm close` record historical automation state, not completion proof.
During agent re-evaluation, remove either obsolete label if present, whether the issue stays open or closes.
Use `gh issue edit <number> --remove-label "<label>"` for each obsolete label present.

New issues start with `needs-triage`.
The [triage labels](docs/agents/triage-labels.md) describe the next states.

## Releases

Miri has no release yet.
The accepted release path is a Developer ID signed and notarized DMG with Sparkle updates and a Homebrew cask.
Until that pipeline exists, CI builds an ad-hoc signed development DMG as a workflow artifact.
Pushing a tag or publishing a release is Sam's decision, and the command guard blocks both for agents.

## Agent-assisted work

See [contributing with an agent](docs/AI-CONTRIBUTIONS.md).
Report security problems privately through [SECURITY.md](SECURITY.md).
