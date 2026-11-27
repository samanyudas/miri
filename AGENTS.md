# Agent instructions

Miri is a native macOS scrolling window manager (`Miri Developer`, `io.github.samanyudas.miri.dev`) with a bundled Paneru-based engine.
Read this map first, then the linked document for the area you touch.

## A note from Sam

I like ambitious ideas, simple systems, and software that feels obvious.
Do not preserve complexity just because it already exists.
Do not introduce machinery because it looks architecturally impressive.
Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni".
Fight scope creep.
Honor the developer's intent, minimally and realistically.

Think of the instructions below less as "hard rules", more as "good defaults".
The developer's preferences should be able to override anything here.

## Session handoff

1. Read [PROGRESS.md](PROGRESS.md) (printed by the Claude Code SessionStart hook) and continue from **Next** instead of redoing **Done**.
2. Before you stop, update `PROGRESS.md`, commit or list every change, and delete temporary files.

## Non-obvious locations and ownership

| Path | Role / gotcha |
| --- | --- |
| `Sources/AXFixture/` | Harmless window that selftests read and move. |
| `vendor/paneru/` | Engine submodule pinned on `samanyudas/paneru` branch `miri/v0.5.2`. Start engine PRs from `miri/v0.5.2`, not from `testing` in `vendor/paneru/AGENTS.md`. |
| `verification/` | TLA+ models checked via `.claude/skills/verify-engine-lifecycle/`. |
| `docs/acceptance-ledger.md` | Recorded result of every v1 acceptance check. |
| `docs/limitations.md` | Confirmed limitations with evidence; add when confirmed, remove when verified fixed. |
| `GLOSSARY.md` | Domain vocabulary; use its terms. |

Each fact has one owner: GitHub Issues own tasks and specs, `decisions/` owns product behavior, `docs/adr/` owns architecture, and `PROGRESS.md` holds only in-flight state.
Read `decisions/release-scope.md` and `decisions/design-tree-status.md` before planning or building a feature.
If your change contradicts an ADR, state it explicitly instead of overriding it.

## Commands

| Command | Runs |
| --- | --- |
| `make setup` | Engine checkout, pre-push hook, pinned Rust, local signing identity, prerequisite report. |
| `make pre-push` | `make lint`, Swift formatting, and engine formatting (run by the pre-push hook). |
| `make lint` | Docs links/style, harness tests, ShellCheck, actionlint, version compatibility (works on Linux). |
| `make native` | Swift/engine lint, build, unit tests, e2e selftests, DMG packaging (needs macOS 27 arm64). |
| `make check` | `make lint` + `make native` (gate before a PR). |
| `make build`, `make test`, `make e2e`, `make package` | Individual `make native` stages (`make test` = `make swift-test` + `make engine-test`). |
| `make format` | Formats Swift sources with `.swift-format`. |
| `make verify-engine-lifecycle` | Model-checks engine start, stop, restart, and quit. |

Run `cargo` from the repo root (including engine checks from `vendor/paneru/AGENTS.md`) so `rust-toolchain.toml` and `.cargo/config.toml` apply.
Fix pre-push hook failures instead of skipping them.
Before any step that touches the real desktop (including `make e2e`), take the [live-test lock](docs/AI-CONTRIBUTIONS.md#take-the-live-test-lock).

## Issues and pull requests

- Follow [File an issue](CONTRIBUTING.md#file-an-issue) (one type label: `bug`, `enhancement`, `task`, or `decision`, all template sections, plain-sentence title; reproduce bugs on the user surface first) and [Take up an issue](CONTRIBUTING.md#take-up-an-issue) (confirm you can check every acceptance criterion and reproduce bugs on `main` before editing; otherwise comment, add `needs-info`, and stop).
- PRs: conventional commit titles in plain language, problem-first body ending with the model and harness, one request per PR, `Refs #N` for delivered issues (not `Closes`/`Fixes`/`Resolves`) and `Part of #N` for partial or docs-only PRs.
  UI changes need before/after images and motion needs short video, uploaded to GitHub with only disposable windows ([capture evidence](docs/AI-CONTRIBUTIONS.md#capture-evidence)); never commit PR-only media.

## Definition of done

- Acceptance criteria hold on the real artifact, `make check` passes (or skipped targets are named with reasons), bug fixes include before/after output, `PROGRESS.md` is updated, and completed issues follow the [issue lifecycle](CONTRIBUTING.md#issue-lifecycle) (tick criteria checkboxes before closing).
- Keep automated observations, manual permission grants, and hardware checks separate in reports.

## Hard boundaries

`.claude/hooks/guard-command.py` blocks these in Claude Code, and all other agents must honor them without workarounds:

- No pushing to `main`, force pushing, `--no-verify`, pushing tags, or deleting remote branches.
- No `gh pr merge --admin`, `gh pr create` or `pull_request_create` without before/after media on product changes, release changes, or repository setting changes (Sam releases).
- No `git reset --hard`, `git clean -f`, or `git branch -D`.
- No `tccutil reset` or `defaults write` (Miri never changes privacy permissions or macOS settings).
- No committing screen recordings anywhere or images outside `assets/` and `Sources/` without a `Media-approved-by: Sam` trailer after Sam approves those exact files.

If you need any of these, stop and ask Sam.

## Writing rules

- Never use the em dash character (`make docs` rejects it).
- Put each sentence on its own line in Markdown.
- Never edit `CHANGELOG.md` or generated files by hand.

## Deeper docs

- [CONTRIBUTING.md](CONTRIBUTING.md) - workflow, review/merge, issue lifecycle.
- [docs/AI-CONTRIBUTIONS.md](docs/AI-CONTRIBUTIONS.md) - evidence standards and live-test lock.
- [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md), [triage labels](docs/agents/triage-labels.md), and [domain docs](docs/agents/domain.md).
- [docs/prototypes/helper-permission.md](docs/prototypes/helper-permission.md) - permission selftest and manual procedure.
