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

A merged `Refs` labels the issue `fixed (pending release)`, and a merged `Part of` changes nothing.

## Review and merge

Sam reads the diff and the verification evidence of every pull request.
Hardware-dependent behavior needs Sam's hardware result.

Agents never merge.
The command guard blocks `gh pr merge`, and Sam decides every merge.
CodeRabbit posts a summary on each pull request.
Treat its findings as input, not as a review verdict.

## Issue lifecycle

The [issue fix status workflow](.github/workflows/issue-fix-status.yml) keeps each report open until its fix reaches the reporter.

1. A pull request that uses `Closes #N` or `Fixes #N` gets one comment that asks for `Refs #N` instead.
2. When a pull request with `Refs #N` merges, the issue gets the `fixed (pending release)` label and a comment.
   `Part of #N` and `Related to #N` never label an issue.
3. When Sam publishes a stable release, each waiting issue gets `please confirm close`, and its reporter is asked to test that version.
4. If nobody replies in 14 days, the workflow closes the issue as completed.
5. A later comment on that issue reopens it with `needs-triage`.

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
