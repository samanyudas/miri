# Progress

Updated: 2026-11-28 on branch `chore/upgrade-paneru-v0.5.3`, based on `main` at `333755b2`

This file records in-flight state and session handoffs only.
Product decisions live in `decisions/`, architecture in `docs/adr/`, tasks in GitHub Issues, and older session history in git log.
Keep this file short and update it when what is done or next changes.

## Objective

Reach a working v1 app that manages windows through the bundled engine, as defined in [release scope](decisions/release-scope.md).
The current milestone is the open v1 work under the [`v1 blocker` label](https://github.com/samanyudas/miri/issues?q=is%3Aopen+label%3A%22v1+blocker%22), followed by hardware checks, the public release path, and complete acceptance runs.

## Done

- App foundation, engine integration, configuration, default shortcuts, shortcut customization, gesture controls, drag insertion (hand-checked 31 Oct 2026), swipe-target hand check (13 Nov 2026, `#212`), and TLA+ engine lifecycle verification (`verification/engine-lifecycle/`) are merged.
- **28 Nov 2026 (Paneru v0.5.3 upgrade):** Merged upstream Paneru `v0.5.3` (`24edaa97`) into new fork branch `miri/v0.5.3` (`45003652`), preserving Miri's swipe physics, thumb rejection, `focus_on_close`, and `PendingWidthSettlement`, and updated Miri's submodule pin, compatibility checks, build script, and docs.
- **27 Nov 2026 (Close and quit focus direction):** Fixed closing a window or quitting an app jumping to the leftmost column or dropping focus ([#562](https://github.com/samanyudas/miri/issues/562), [engine PR #214](https://github.com/samanyudas/paneru/pull/214), `8657eeb4`), and added the **When a window closes, focus** (**Left** / **Right**) setting in Settings > Layout (`[options].focus_on_close`).
- **27 Nov 2026 (Codebase untangling):** Merged [#558](https://github.com/samanyudas/miri/pull/558) and [#559](https://github.com/samanyudas/miri/pull/559) (pinning [engine PR #213](https://github.com/samanyudas/paneru/pull/213), `6d7f6e7`), deleting unused Swift files, simplifying Miri/MiriCore/Paneru subsystems, fixing FFI/overlay/edge-slice bugs, and syncing `EngineLifecycle.tla`.
- **27 Nov 2026 (Maximize refusal and unknown bindings):** Merged [#557](https://github.com/samanyudas/miri/pull/557) ([#554](https://github.com/samanyudas/miri/issues/554), [engine PR #212](https://github.com/samanyudas/paneru/pull/212), `1af42c07`) adding a `350 ms` refusal grace window and `MaximizeRefused` recovery, and [#556](https://github.com/samanyudas/miri/pull/556) ([#555](https://github.com/samanyudas/miri/issues/555), [engine PR #211](https://github.com/samanyudas/paneru/pull/211), `8fbe890`) skipping unknown `[bindings]` commands on startup while reporting the notice.
- **25-26 Nov 2026 (Recent fixes):** Auto-floating mounted DMG installer windows ([#550](https://github.com/samanyudas/miri/issues/550), [engine PR #210](https://github.com/samanyudas/paneru/pull/210)), preserving stacked column width on relaunch ([#517](https://github.com/samanyudas/miri/issues/517), [engine PR #209](https://github.com/samanyudas/paneru/pull/209)), multilingual and fuzzy shortcut search across 22 `.lproj` localizations, menu bar Show Logs in Finder activation ([#534](https://github.com/samanyudas/miri/issues/534)), and trackpad resting thumb and palm rejection ([engine PR #208](https://github.com/samanyudas/paneru/pull/208)).

## Next

Each phase lands as its own PR or PRs.
Record every acceptance result in the [acceptance ledger](docs/acceptance-ledger.md).

1. Finish the remaining v1 features.
   - Record acceptance check S-1 on the frozen release candidate (Sam's hand check of both swipe targets passed on 13 November 2026, `#212`).
   - Run the stack overflow (S-5) and stack limit (S-7) hardware checks, and record them against the frozen release candidate.
   - Verify every Strip gestures checklist item and the settling behavior on a real trackpad.
2. Build the public release path, in parallel with phase 1.
   Integrate Sparkle updates, then production signing, notarization, the release DMG, and the Homebrew cask.
   Verify install, upgrade, and Accessibility attribution on the released bundle.
3. Freeze one release candidate, then run the complete app and multi-monitor acceptance checklists on that bundle with Accessibility granted.
4. Define the engine memory-stability rule, complete the endurance period, and have Sam decide Q6 at the final check before publishing v1.

## Blockers

- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

- **28 Nov 2026 (`chore/upgrade-paneru-v0.5.3`, engine `45003652`):** Passed `make pre-push` (`make lint`, `check-compat`, `swift-format`, `cargo fmt`), `make swift-lint`, `make engine-lint`, default-feature `cargo clippy --all-targets -- -D warnings`, `make engine-test` (1,680 tests `--no-default-features`), `cargo test` with `lua` (1,781 tests), `make build`, `make swift-test` (229 tests), `make e2e`, `make package`, and live `verify-miri` run (`20261128-024419`) verifying keyboard focus east/west, stack/unstack with `v0.5.3` `column`/`row` state, dual-display `movedisplay` (display 3 to display 1), and clean exit recovery.

- **27 Nov 2026 (`fix/close-window-focus-direction`, engine `8657eeb4`):** Passed `make check` (`make lint`, `make compat`, `make swift-lint`, `make strings` across 22 languages, `make engine-lint`, `make build`, `make swift-test`, `make engine-test`, `make e2e`, `make package`) and live `verify-miri` runs (`20261127-185203`, `20261127-185350`) covering close-window (Left), quit-app (Left and Right), Settings > Layout toggle, and `verify-miri cutoff`.
- **27 Nov 2026 (`#558`/`#559`, engine `6d7f6e7`):** Passed `make pre-push`, `make swift-test` (229 tests), `make strings`, `make engine-lint`, `make engine-test` (1,643 tests `--no-default-features`, 1,754 tests with `lua`), `make verify-engine-lifecycle` (198 states, exit 0), `make build`, `make package`, `make e2e`, and live `verify-miri` single- and dual-display runs.
- **27 Nov 2026 (`chore/trim-guard-and-lifecycle-sync`):** Passed `make pre-push` (`check-docs`, 82 harness tests, ShellCheck, `actionlint`, `check-compat`, `swift-format`, `cargo fmt`) and `make verify-engine-lifecycle` (198 states, exit 0).
  `make native` was skipped because no Swift or Rust product code changed.
- **27 Nov 2026 (`docs/trim-agent-context`):** Passed `make lint` (`check-docs`, harness tests, ShellCheck, `actionlint`, `check-compat`) and `git diff --check`.
  `make native` was skipped because only Markdown documentation and skill frontmatter changed.
