# Agent instructions

Miri is a native macOS scrolling window manager with a bundled Paneru-based engine.
Today the repository holds the product design and a menu bar app that supervises the engine.
Read this map first, then the linked document for the area you touch.

## A note from Sam

I like ambitious ideas, simple systems, and software that feels obvious.
Do not preserve complexity just because it already exists.
Do not introduce machinery because it looks architecturally impressive.
Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni".
Fight scope creep.
Try to honor the dev's intent in both a minimal and realistic fashion.

The rest of this document is meant to help you navigate the codebase and make changes effectively.
Think of these instructions less as "hard rules", more as "good defaults".
The developer's preferences should be able to override anything here.

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
| `verification/` | TLA+ models that a project skill in `.claude/skills/` checks, such as the engine lifecycle. |
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
| `make verify-engine-lifecycle` | Model-checks engine start, stop, restart, and quit. Use it when you change that code. |

Run cargo from the repository root so `rust-toolchain.toml` and `.cargo/config.toml` apply.
CI in `.github/workflows/ci.yml` runs the same make targets, with the macOS stages as parallel jobs.
Fix what the pre-push hook reports instead of skipping it.
Before any step that changes the real desktop, including `make e2e`, take the [live-test lock](docs/AI-CONTRIBUTIONS.md#take-the-live-test-lock).

## Issues

- File an issue only with exactly one type label (`bug`, `enhancement`, `task`, or `decision`) and every required section of its template in `.github/ISSUE_TEMPLATE/`.
  Write the title as one plain sentence about what changes for the person using Miri.
  File a bug only after you reproduce it yourself on the surface a user sees, and report it to Sam if you cannot.
- Before you change code for an issue, confirm that you can check each acceptance criterion.
  For a bug, also reproduce it on the current `main` build.
  If either check fails, comment with the gap, add `needs-info`, and stop.
- [File an issue](CONTRIBUTING.md#file-an-issue) and [Take up an issue](CONTRIBUTING.md#take-up-an-issue) have the full rules.
  The command guard reads the templates and blocks a `gh issue create` command that breaks these rules.

## Pull requests

- Conventional commit titles, plain language: fix(engine): stacked windows no longer go out of reach.
- Body: the problem in a sentence or two, then how you fixed it.
  End with the model and harness that did the work.
- UI changes need before/after images.
  Motion or timing needs a short video.
- Upload PR evidence to GitHub after Sam approves it, as [AI-CONTRIBUTIONS.md](docs/AI-CONTRIBUTIONS.md#capture-evidence) describes.
  Never commit PR-only screenshots or assets such as .github/pr-assets/.
- One request is one PR.
  Split it only when the maintainer asks.
  Outside contributions follow the stricter one problem per PR rule.
- Reference an issue the PR delivers with `Refs #N`, rather than closing keywords such as `Closes`, `Fixes`, or `Resolves`.
  The [issue lifecycle](CONTRIBUTING.md#issue-lifecycle) explains why.
- Use `Part of #N` for a PR that only records decisions, changes docs, or delivers part of the issue.

## Definition of done

- The issue's acceptance criteria hold, and you observed them on the real artifact.
- Verify and close completed issues under the [issue lifecycle](CONTRIBUTING.md#issue-lifecycle).
  Tick each acceptance criterion's checkbox in the issue once you verify it, before you close the issue.
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

The pre-push hook rejects new commits that add a screen recording anywhere, or an image outside `assets/` and `Sources/`.
Only a commit with a `Media-approved-by: Sam` trailer passes, and only after Sam viewed and approved those exact files.
Share window evidence as [AI-CONTRIBUTIONS.md](docs/AI-CONTRIBUTIONS.md#capture-evidence) describes.

## Writing rules

- Never use the em dash character. `make docs` rejects it.
- In Markdown, put each sentence on its own line.
- Never edit `CHANGELOG.md` or generated files by hand.

## Deeper docs

- [CONTRIBUTING.md](CONTRIBUTING.md) covers the workflow, review and merge, and the issue lifecycle.
- [docs/AI-CONTRIBUTIONS.md](docs/AI-CONTRIBUTIONS.md) covers evidence standards for agent work.
- [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md), [triage labels](docs/agents/triage-labels.md), and [domain docs](docs/agents/domain.md) cover the tracker and vocabulary.
- [docs/prototypes/helper-permission.md](docs/prototypes/helper-permission.md) covers the permission selftest and its manual procedure.
