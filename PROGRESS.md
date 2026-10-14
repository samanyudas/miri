# Progress

Updated: 2026-10-15 by Claude on branch `feat/v1-app-core`

This file records in-flight state and the handoff between sessions.
Product decisions live in `decisions/`, architecture in `docs/adr/`, and tasks in GitHub Issues.
Update it at the end of every session and in any PR that changes what is done or next.

## Objective

Reach a working v1 app that manages windows through the bundled engine, as defined in [release scope](decisions/release-scope.md).
The current milestone is the first production app slice: menu bar controls, engine start and stop, and window recovery.

## Done

- The v1 specification and product decisions are merged (#3).
- The Accessibility permission prototype is merged (#4).
  Enabling only the Miri entry authorizes both the app and its engine in the development build.
- The development harness is merged (#10), tracked by #9.
- PR #11, the Miri Developer identity, merged into `chore/repo-harness` after #10 had already merged that branch.
  Its commits never reached `main`, so `feat/v1-app-core` carries them.
- `feat/v1-app-core` adds the first production app slice:
  - `MiriCore`, a tested library with a TOML 1.0 parser that edits single values without touching the rest of the file.
  - Miri-owned `config.toml` with the accepted defaults and derived engine keys for gaps, presets, animation, and floating Settings.
  - An engine supervisor with an isolated environment, bounded logs, and a three-crashes-in-five-minutes restart limit.
  - App-side window recovery after every engine exit, verified live against the fixture window.
  - A setup checker, redacted diagnostics with a preview, and the menu bar and Settings UI.
- A live run on 15 October 2026 on the built-in display only confirmed Start, 8-point gaps on all sides and between windows, Stop, crash recovery and restart, the three-crash limit, manual restart, and Quit.

## Next

1. Sam reviews the `feat/v1-app-core` PR.
2. Patch the engine on the fork to hide its own menu bar item and to refuse fallback configuration when `PANERU_CONFIG` is missing.
   Today the engine shows a second menu bar item beside Miri's.
3. Find out why T3 Code's existing window shrank from 2048 to 1024 points after the first focus change in the live run.
   Existing windows should keep their widths.
4. Repeat the live run with an external display connected.
5. Resolve product question Q6 and the stacking scope question in [design tree status](decisions/design-tree-status.md).
6. Build the remaining v1 controls: the shortcut recorder, the gesture test, and pointer-targeted swipes.
7. Move to Rust 1.99 when the product is ready. Fix the two `assert_is_empty` Clippy errors in `src/lua/runtime.rs` on the fork first, then repin. Branch `chore/rust-1.99-engine` holds the earlier attempt.

## Blockers

- Product decisions Q6 and stacking scope are open and block stacking behavior.
- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

See the verification section of the `feat/v1-app-core` PR.
