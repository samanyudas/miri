# Progress

Updated: 2026-10-14 by Claude on branch `feat/developer-identity`

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
- The development harness is in review in #10 on `chore/repo-harness`, tracked by #9.
  It adds `make check`, CI, issue lifecycle automation, the command guard, and contributor documents.
  `make check` passes locally, and a live Claude session showed the guard blocking a push to `main`.
- Development builds become **Miri Developer** (`io.github.samanyudas.miri.dev`) with a stable local signing identity. This is in review as the PR stacked on #10, with engine change samanyudas/paneru#4.

## Next

1. Sam reviews and merges #10. Then check that `pr-risk` and `issue-fix-status` run on the next PR, because `pull_request_target` workflows only run from `main`.
2. Sam merges samanyudas/paneru#4. CI on the Miri Developer PR stays red until then, because `make compat` requires the engine pin on `miri/v0.5.2`. Then merge that PR.
3. Sam checks System Settings > Accessibility for a **Miri Developer** entry. The first selftest of the new identity reported `observed-granted` before any known grant, and the cause is unknown.
4. Resolve product question Q6 and the stacking scope question in [design tree status](decisions/design-tree-status.md).
5. Plan the first production app slice: menu bar controls, engine start and stop, and window recovery on quit.
6. Move to Rust 1.99 when the product is ready. Fix the two `assert_is_empty` Clippy errors in `src/lua/runtime.rs` on the fork first, then repin. Branch `chore/rust-1.99-engine` holds the earlier attempt.

## Blockers

- Product decisions Q6 and stacking scope are open and block stacking behavior.
- Developer ID enrollment is pending and blocks signed, notarized releases.

## Last verification

See the verification section of #10.
