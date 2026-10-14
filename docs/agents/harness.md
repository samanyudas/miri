# Development checks

## Start work

Run these commands from a fresh checkout.

```sh
scripts/setup.sh --profile portable
scripts/restore-state.sh
scripts/verify.sh
```

Portable setup requires Bash, Git, and Python 3.8 or later.
Setup validates live tools and records their versions, paths, and input hashes in a private Git worktree directory.
`check-ready.sh --profile portable` rechecks those inputs before trusting the stamp.
Run setup again after a tool, manifest, engine checkout, or setup script changes.
Setup does not certify a build.

For native development, use an arm64 Mac with macOS 27 or later, Swift 6.2 or later, and rustup.
The active macOS SDK must be version 27 or later.
The root `rust-toolchain.toml` pins Rust, rustfmt, and Clippy so that new lints in a later release cannot break strict checks unexpectedly.
Rustup installs the pinned toolchain on first use.
Install the Xcode packaging tools before running native setup.
Exact observed versions identify the environment but do not redefine these supported minimums.

```sh
scripts/setup.sh --profile portable
scripts/setup.sh --profile native
scripts/verify.sh --level gui
```

Native setup initializes an absent `vendor/paneru` checkout at its recorded gitlink.
It refuses a dirty or mismatched initialized engine instead of resetting it.
Native verification requires both readiness profiles.

## Choose verification scope

Levels include every earlier level.
The default is `portable`.

| Level | Checks and evidence |
| --- | --- |
| `repo` | Repository map, review pointers, JSON settings, executable hooks, and unchanged upstream writing library. |
| `portable` | Live portable readiness, shell/Python syntax, tooling regressions, upstream writing/guard regressions, and advisory writing findings. |
| `build` | Live native readiness, Rust formatting, strict no-Lua Clippy, all no-Lua engine test targets, and the existing Swift/Rust build and ad-hoc signing script. |
| `gui` | Existing packaged Launch Services driver, observation schema, aliased paths, missing helper, helper CLI, process cleanup, and retained provenance. |

The package has no Swift test target.
The native engine baseline contains 319 tests.
The harness runs actual Cargo test targets instead of inventing a Swift test step.

A successful `gui` run may report `observed-ungranted`.
That result proves the driver's diagnostic checks, not permission attribution or release acceptance.
Use the [permission procedure](../prototypes/helper-permission.md) for grant attribution and distribution-signing checks.
Use the acceptance documents in `decisions/` for hardware, monitor, and endurance requirements.
Native runtime changes require `build` and `gui` evidence before merge.

Exit codes are 0 for success, 1 for failed checks, 2 for invalid arguments, and 3 for unavailable prerequisites.
Signals retain an interrupted result and return a conventional signal exit code.
A failed check stops the run and leaves later checks as `not_run`.
Unsupported native hosts and unavailable GUI sessions fail explicitly.

## Read evidence and hand off

Every run creates its own ignored `.harness/runs/<id>/` directory.
Read `summary.json` for the requested level, source HEAD, actual working-tree fingerprint, dirty files, tool fingerprint, and individual results.
Each result records its scope, status, exit code, elapsed seconds, log, and artifacts.
`environment.json` records the actual versions, manifest hashes, engine revision, and environment problems.
Writing findings remain advisory in `writing.json`, but a discovery or tooling error fails the writing check.
Packaged JSON and logs are copied into `permission/` after the driver-reported path is validated.
`permission/origin.json` identifies the original temporary directory, which also contains copied test bundles.

`restore-state.sh` reads the newest completed run and compares source and live environment fingerprints.
It labels stale evidence and reports the exact tested scope.
It does not treat an earlier passed result as current verification.

```sh
scripts/end-session.sh --level portable --note "Tooling checks passed. Native verification remains pending."
scripts/review-change.sh --cached
scripts/review-change.sh main HEAD
```

Handoff runs the requested checks and records the note and dirty files in that run.
It does not commit, discard, or restore files.
A portable handoff does not claim native completion.
Review hints cite existing ADRs and do not define another architecture policy.
Pre-commit verifies the working tree and reports staged paths separately.
It does not prove that a partially staged commit matches the tested working tree.

Portable runs have independent evidence directories.
Native runs acquire `.harness/native.lock` because packaging shares this checkout's `.build/` and engine target directory.
Different worktrees can run native checks independently.
Do not run the original build or driver scripts concurrently with native verification in the same checkout.
If a process dies without cleanup, inspect `native.lock/owner.json` and confirm that its process has exited before removing that lock.
Delete only specific old run directories when their evidence is no longer needed.
No command prunes active evidence.

## Optional integrations

The tracked Claude `SessionStart` hook runs read-only restoration.
Enable the command guard explicitly when wanted.

```sh
scripts/setup.sh --enable-claude-guard
```

This command merges one known entry into ignored `.claude/settings.local.json`.
It preserves unrelated entries and refuses malformed settings or a conflicting guard entry.
The guard blocks common hook bypasses, forced pushes, and recursive root/home deletion.
It is a convenience check, not a security boundary or a complete shell parser.

Git hook installation requires Git's worktree configuration extension to be enabled already.
If you choose this repository-wide Git capability, enable it explicitly first.

```sh
git config extensions.worktreeConfig true
scripts/setup.sh --install-hooks
```

The installer writes only `git config --worktree core.hooksPath` with this worktree's absolute `.githooks` path.
It refuses a foreign effective hook path and never writes the shared hooks directory.
The pre-commit hook runs portable verification and staged review hints.
Run `scripts/setup.sh --profile portable` before the first hooked commit in each worktree.

## CI and maintenance

Pull requests and pushes run portable checks on Ubuntu and native checks on GitHub's `xcode-27` arm64 runner.
`xcode-27` is a preview label and can change.
The native job requires a usable GUI session and retains an unavailable failure when the session is absent.
Both jobs upload evidence even on failure.

The weekly and manual maintenance workflow runs `scripts/scan.sh` and uploads its read-only report.
The report includes prior evidence freshness, current portable checks, and writing findings.
It fetches GitHub's runner documentation to report whether the preview image remains documented.
Record actionable findings in GitHub Issues.
Maintenance does not create issues, rewrite files, update dependencies, or change permissions automatically.

See [upstream provenance](harness-upstream.md) and [ADR 0010](../adr/0010-adopt-project-development-tooling.md) for the adoption boundary.
