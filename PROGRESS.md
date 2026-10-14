# Progress

Updated: 2026-10-14 by Claude on branch `chore/repo-harness`

This file records in-flight state and the handoff between sessions.
Product decisions live in `decisions/`, architecture in `docs/adr/`, and tasks in GitHub Issues.
Update it at the end of every session and in any PR that changes what is done or next.

## Objective

Reach a working v1 app that manages windows through the bundled engine, as defined in [release scope](decisions/release-scope.md).
The current milestone is a verifiable development harness on top of the permission prototype.

## Done

- The v1 specification and product decisions are merged (#3).
- The Accessibility permission prototype is merged (#4).
  Enabling only the Miri entry authorizes both the app and its engine in the development build.
- The development harness is in review on `chore/repo-harness`.
  It adds `make check`, CI, issue lifecycle automation, the command guard, and contributor documents.

## Next

1. Review and merge the harness PR.
2. Resolve product question Q6 and the stacking scope question in [design tree status](decisions/design-tree-status.md).
3. Plan the first production app slice: menu bar controls, engine start and stop, and window recovery on quit.
4. Move to Rust 1.99 when the product is ready. Fix the two `assert_is_empty` Clippy errors in `src/lua/runtime.rs` on the fork first, then repin. Branch `chore/rust-1.99-engine` holds the earlier attempt.

## Blockers

- Product decisions Q6 and stacking scope are open and block stacking behavior.
- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

See the verification section of the harness PR and [harness audit](docs/agents/harness-audit.md).
