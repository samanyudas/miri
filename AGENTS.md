# Agent instructions

Miri is a native macOS scrolling window manager with a bundled Paneru-based engine.
Today the repository holds the product design and an Accessibility permission prototype.
Read this map first, then the linked document for the area you touch.

## Start and end every session

1. Read [PROGRESS.md](PROGRESS.md). The SessionStart hook prints it with the branch and uncommitted changes.
2. Continue from its **Next** list instead of redoing items under **Done**.
3. Before you stop, update PROGRESS.md and commit or list every change. Delete temporary files.

## Where things live

| Path | Contents |
| --- | --- |
| `Sources/MiriPrototype/` | SwiftUI permission prototype app. |
| `Sources/AXFixture/` | Harmless window that the selftest observes. |
| `vendor/paneru/` | Engine submodule, pinned to a commit on `samanyudas/paneru` branch `miri/v0.5.2`. |
| `scripts/` | Build, packaging, selftest, and repository checks, with tests in `scripts/tests/`. |
| `.claude/` | Project hooks: the command guard and the session-start handoff. |
| `.github/` | CI, issue lifecycle, risk labeling, and issue and PR templates. |
| `decisions/` | Accepted product direction and open questions. |
| `docs/adr/` | Architecture decisions. |
| `docs/specs/`, `docs/prototypes/` | The v1 specification and prototype records. |
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
| `make setup` | Engine checkout, pinned Rust install, prerequisite report. |
| `make lint` | Docs links and style, harness tests, ShellCheck, actionlint, version compatibility. Works on Linux. |
| `make native` | Swift and engine lint, build, engine unit tests, end-to-end selftest, DMG packaging. Needs macOS 27 arm64. |
| `make check` | `make lint` and `make native`. This is the gate before a PR. |
| `make build`, `make test`, `make e2e`, `make package` | One stage of `make native`. |
| `make format` | Formats Swift sources with `.swift-format`. |

Run cargo from the repository root so `rust-toolchain.toml` applies.
CI in `.github/workflows/ci.yml` runs the same make targets.

## Definition of done

- The issue's acceptance criteria hold, and you observed them on the real artifact.
- `make check` passes, or the PR names each skipped target and why.
- A bug fix includes the failing output from before the fix and the passing output after it.
- The PR description lists commands and results and names what remains untested, such as hardware or a manual permission grant.
- PROGRESS.md is current.

Automated observations, manual permission grants, and hardware checks are separate kinds of evidence.
Never report one as another.

## Rules the tools enforce

`.claude/hooks/guard-command.py` blocks these commands for agents:

- Pushing to `main`, force pushing, pushing tags, and deleting remote branches.
- `gh pr merge`, release changes, and repository setting changes. Sam merges and releases.
- `git reset --hard`, `git clean -f`, and `git branch -D`.
- `tccutil reset` and `defaults write`. Miri never changes privacy permissions or macOS settings.

If you need one of these, stop and ask Sam.
Do not work around the guard with another command.

## Writing rules

- Never use the em dash character. `make docs` rejects it.
- In Markdown, put each sentence on its own line.
- In PRs, reference issues with `Refs #N`, never `Closes` or `Fixes`. The [issue lifecycle](CONTRIBUTING.md#issue-lifecycle) explains why.
- Never edit `CHANGELOG.md` or generated files by hand.

## Deeper docs

- [CONTRIBUTING.md](CONTRIBUTING.md) covers the workflow, risk classes, and issue lifecycle.
- [docs/AI-CONTRIBUTIONS.md](docs/AI-CONTRIBUTIONS.md) covers evidence standards for agent work.
- [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md), [triage labels](docs/agents/triage-labels.md), and [domain docs](docs/agents/domain.md) cover the tracker and vocabulary.
- [docs/agents/harness-audit.md](docs/agents/harness-audit.md) records how this harness was verified.
- [docs/prototypes/helper-permission.md](docs/prototypes/helper-permission.md) covers the permission selftest and its manual procedure.
