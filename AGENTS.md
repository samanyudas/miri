# Agent instructions

## Agent skills

### Issue tracker

Issues and specs live in GitHub Issues on `samanyudas/miri`, managed with the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage labels are used unchanged: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root.
See `docs/agents/domain.md`.

### Product decisions

`decisions/` holds accepted product direction, planned behavior, and open questions.
Read `decisions/release-scope.md` and `decisions/design-tree-status.md` before planning or building features.
Read the other files when your work touches their topic, such as setup, configuration, keybindings, or acceptance checks.

### Engine changes

Read `docs/agents/engine-fork.md` before you change the Paneru engine or open a PR to the original Paneru project.

## Development checks

Run `scripts/setup.sh --profile portable`, then `scripts/restore-state.sh` when starting work.
Run `scripts/verify.sh` before committing.
Read `docs/agents/harness.md` for native checks, optional hooks, evidence, and handoff commands.
Writing checks provide advisory ASD-STE100-inspired findings without rewriting product decisions.

## Repository map

Directory entries cover their descendants.
Add a map entry when introducing another topic directory.

| Path | Purpose |
| --- | --- |
| `AGENTS.md` | Agent instructions and repository map. |
| `CLAUDE.md` | Claude imports these instructions. |
| `README.md` | Project and development entry point. |
| `PLAN.md` | Existing prototype plan. |
| `GLOSSARY.md` | Shared domain terms. |
| `LICENSE` | Miri license. |
| `Package.swift` | Swift package definition. |
| `.gitignore` | Generated and local file exclusions. |
| `.gitmodules` | Engine source location. |
| `Sources/` | Native prototype and harmless Accessibility fixture. |
| `vendor/paneru` | Pinned engine submodule. |
| `rust-toolchain.toml` | Pinned Rust toolchain for engine checks. |
| `assets/` | Project artwork. |
| `decisions/` | Product direction and acceptance requirements. |
| `docs/agents/` | Issue, domain, and development guidance. |
| `docs/adr/` | Accepted architecture decisions. |
| `docs/prototypes/` | Prototype procedures and recorded observations. |
| `docs/specs/` | Existing detailed product specification. |
| `scripts/` | Development checks, tests, and immutable writing library. |
| `.github/` | Verification and maintenance workflows. |
| `.githooks/` | Optional worktree Git hooks. |
| `.claude/` | Session restoration and optional local guard settings. |
