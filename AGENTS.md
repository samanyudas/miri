# Agent instructions

Miri is a native macOS scrolling window manager with a bundled Paneru-based engine.
Today the repository holds the product design and a menu bar app that supervises the engine.
Read this map first, then the linked document for the area you touch.

## Start and end every session

1. Read [PROGRESS.md](PROGRESS.md). The SessionStart hook prints it with the branch and uncommitted changes.
2. Continue from its **Next** list instead of redoing items under **Done**.
3. Before you stop, update PROGRESS.md and commit or list every change. Delete temporary files.

## Where things live

| Path | Contents |
| --- | --- |
| `Sources/Miri/` | SwiftUI and AppKit app. Builds as Miri Developer, `io.github.samanyudas.miri.dev`. |
| `Sources/MiriCore/` | Testable logic: TOML editing, settings, engine supervision, window recovery, setup checks, diagnostics. |
| `Tests/MiriCoreTests/` | Swift Testing suites for `MiriCore`. |
| `Sources/AXFixture/` | Harmless window that the selftests read and move. |
| `vendor/paneru/` | Engine submodule, pinned to a commit on `samanyudas/paneru` branch `miri/v0.5.2`. |
| `scripts/` | Build, packaging, selftest, and repository checks, with tests in `scripts/tests/`. |
| `.claude/` | Project hooks: the command guard and the session-start handoff. |
| `.github/` | CI and issue and PR templates. |
| `decisions/` | Accepted product direction and open questions. |
| `docs/adr/` | Architecture decisions. |
| `docs/specs/`, `docs/prototypes/` | The v1 specification and prototype records. |
| `docs/acceptance-ledger.md` | The recorded result of every v1 acceptance check. |
| `docs/limitations.md` | Every known limitation, with its evidence. Add a confirmed limitation here, and remove it when its fix is verified. |
| `GLOSSARY.md` | Domain vocabulary. Use its terms. |

Each fact has one owner.
GitHub Issues own tasks and specs.
`decisions/` owns product behavior, and `docs/adr/` owns architecture.
PROGRESS.md owns only in-flight state and points to the others.
Read `decisions/release-scope.md` and `decisions/design-tree-status.md` before you plan or build a feature.
If your change contradicts an ADR, say so explicitly instead of overriding it.

## Commands

| Command | Runs |
| --- | --- |
| `make setup` | Engine checkout, pre-push hook, pinned Rust install, local signing identity, prerequisite report. |
| `make pre-push` | `make lint`, Swift formatting, and engine formatting in seconds. The pre-push hook runs it. |
| `make lint` | Docs links and style, harness tests, ShellCheck, actionlint, version compatibility. Works on Linux. |
| `make native` | Swift and engine lint, build, Swift and engine unit tests, end-to-end selftests, DMG packaging. Needs macOS 27 arm64. |
| `make check` | `make lint` and `make native`. This is the gate before a PR. |
| `make build`, `make test`, `make e2e`, `make package` | One stage of `make native`. `make test` is `make swift-test` and `make engine-test`. |
| `make format` | Formats Swift sources with `.swift-format`. |

Run cargo from the repository root so `rust-toolchain.toml` and `.cargo/config.toml` apply.
CI in `.github/workflows/ci.yml` runs the same make targets, with the macOS stages as parallel jobs.
Fix what the pre-push hook reports instead of skipping it.

## Definition of done

- The issue's acceptance criteria hold, and you observed them on the real artifact.
- Verify and close completed issues under the [issue lifecycle](CONTRIBUTING.md#issue-lifecycle).
- `make check` passes, or the PR names each skipped target and why.
- A bug fix includes the failing output from before the fix and the passing output after it.
- The PR description lists commands and results and names what remains untested, such as hardware or a manual permission grant.
- PROGRESS.md is current.

Automated observations, manual permission grants, and hardware checks are separate kinds of evidence.
Never report one as another.

## Rules the tools enforce

`.claude/hooks/guard-command.py` blocks these commands for agents:

- Pushing to `main`, force pushing, pushing with `--no-verify`, pushing tags, and deleting remote branches.
- `gh pr merge`, release changes, and repository setting changes. Sam merges and releases.
- `git reset --hard`, `git clean -f`, and `git branch -D`.
- `tccutil reset` and `defaults write`. Miri never changes privacy permissions or macOS settings.

If you need one of these, stop and ask Sam.
Do not work around the guard with another command.

## Writing rules

- Never use the em dash character. `make docs` rejects it.
- In Markdown, put each sentence on its own line.
- In PRs, reference an issue the PR delivers with `Refs #N`, rather than closing keywords such as `Closes`, `Fixes`, or `Resolves`.
  The [issue lifecycle](CONTRIBUTING.md#issue-lifecycle) explains why.
- Use `Part of #N` for a PR that only records decisions, changes docs, or delivers part of the issue.
- Never edit `CHANGELOG.md` or generated files by hand.

## Deeper docs

- [CONTRIBUTING.md](CONTRIBUTING.md) covers the workflow, review and merge, and the issue lifecycle.
- [docs/AI-CONTRIBUTIONS.md](docs/AI-CONTRIBUTIONS.md) covers evidence standards for agent work.
- [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md), [triage labels](docs/agents/triage-labels.md), and [domain docs](docs/agents/domain.md) cover the tracker and vocabulary.
- [docs/prototypes/helper-permission.md](docs/prototypes/helper-permission.md) covers the permission selftest and its manual procedure.
