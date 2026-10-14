# Harness audit

Updated: 2026-10-14 by Claude on branch `chore/repo-harness`

This record applies Sam's maintenance checklist to a real task, issue #9 and PR #10.
A checked box means the command or workflow ran successfully.
An unchecked box names what is missing.

## Executable checks

- [x] **Clean setup with pinned versions.**
  A fresh worktree from `origin/main` ran `git submodule update --init`, then `scripts/doctor.sh`.
  The doctor failed on missing ShellCheck and actionlint, then passed all 9 checks after `brew install shellcheck actionlint`.
  `rust-toolchain.toml` pins Rust 1.98.1, and the doctor rejects any other Rust, ShellCheck, or actionlint version.
  The pin is required: engine `f1df587` passes Clippy on 1.98.1 and fails on 1.99.0 with 10 `assert!` emptiness errors.
- [x] **One command runs every check, and CI runs the same commands.**
  `make check` runs docs, harness tests, ShellCheck, actionlint, compatibility, Swift lint, engine lint, build, 319 engine tests, the selftest, and DMG packaging.
  It exited 0 on macOS 27.0 arm64.
  CI runs `make lint` on `ubuntu-latest` to save macOS minutes, and the `make native` stages on the `xcode-27` runner.
  Both jobs install the same checksummed ShellCheck and actionlint versions. RUN_PLACEHOLDER
- [x] **A representative change has a definition of done, with tests before and after.**
  Issue #9 lists the acceptance criteria.
  Before the change, `scripts/check-docs.py` on `origin/main` reported `AGENTS.md: missing agent map` and `PROGRESS.md: missing handoff record`.
  After the change, it reports 0 problems.
- [x] **An end-to-end check covers what unit tests cannot.**
  `make e2e` launches the packaged app through Launch Services against a real fixture window.
  Locally and in CI it printed `observed-ungranted. Attribution unresolved. Missing-helper and aliased-path checks passed.`
  `make package` mounted the DMG and verified both signatures.
- [x] **The agent repairs a failure and reruns verification.**
  The first local `make check` failed on em dashes in the checker source, a missing doc link, and staged `__pycache__` files. The rerun passed after fixes.
  CI run 38563876490 failed because Ubuntu's ShellCheck reported SC2317 where the local 0.11.0 reports SC2329.
  The fix pinned ShellCheck and made the doctor reject other versions. Run 38564600756 passed.
- [x] **Tools enforce permissions outside prose.**
  A headless Claude Code session in the worktree ran `git push --dry-run origin HEAD:main`.
  The PreToolUse hook blocked it with `pushing to main skips pull request review`, and `origin/main` stayed at `a07d62d`.
  `scripts/tests/test_guard_command.py` covers 19 blocked and 10 allowed commands.
- [x] **The task survives a fresh session.**
  A new headless session, told to run nothing, named the branch, the finished work, the next step, and both blockers from the SessionStart hook output alone.
- [x] **Every session leaves a reviewable git state.**
  Work is committed in small commits on `chore/repo-harness`.
  `.gitignore` now excludes `.DS_Store`, `.audit/`, `work/`, and `__pycache__/`.
- [ ] **A PR runs CI and specialist review, with a risk decision.**
  CI ran, and CodeRabbit was rate limited on the free plan, so no specialist review ran.
  PR #10 is high risk, so Sam must review it.
  The `pr-risk` workflow uses `pull_request_target`, which runs only after it reaches `main`. Its first real run will be the next PR.
- [ ] **Post-release feedback reaches the reporter.**
  `issue-fix-status.yml` implements the lifecycle, but Miri has no release, so no job has fired.

## Controlled ablation test

- [ ] Not run.
  It needs a fixed model, a set of representative tasks, and repeated trials per variant.
  A suitable task set is three closed issues (#1, #2, #5) replayed from their parent commits, scored by `make check` and the issue's acceptance criteria.
  Each variant removes one of AGENTS.md, the make targets, PROGRESS.md and the SessionStart hook, the command guard, or `make setup`.

## Repository documentation

- [x] README explains what Miri is and how to install, build, run, and verify it.
- [x] AGENTS.md is an 85-line map. `make docs` fails above 120 lines.
- [x] Architecture decisions stay in `docs/adr/`, and AGENTS.md maps each directory. No ARCHITECTURE.md was needed.
- [x] PROGRESS.md holds the handoff. `make docs` requires its sections and date.
- [x] CONTRIBUTING, SECURITY, SUPPORT, and docs/AI-CONTRIBUTIONS exist. Issue forms and the PR template ask for reproduction steps, expected results, acceptance criteria, verification evidence, and release notes.

## Open choices for Sam

These defaults are in place. Each one is reversible.

- **Scope.** This audit covers `samanyudas/miri` and issue #9 only.
- **Platforms.** Lint runs on Linux to save cost. Build, tests, selftest, and packaging run on the `xcode-27` macOS runner. Hardware and multi-display checks stay manual.
- **Durable state.** PROGRESS.md, updated by whoever ends a session. Issues stay the task authority.
- **Risk.** Agents never merge. Sam reviews `risk: high` diffs and may merge `risk: low` on green CI.
- **Review and follow-up.** CodeRabbit free plan only. Fix-status asks reporters on each stable release and closes after 14 silent days.
