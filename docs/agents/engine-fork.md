# Engine fork branches

Miri's engine comes from the `samanyudas/paneru` fork of `karinushka/paneru`.
[ADR 0003](../adr/0003-bundle-a-pinned-paneru-engine.md) records why Miri pins a release and keeps its patches in the fork.

## Long-lived branches

| Branch | Purpose |
| --- | --- |
| `main` | Mirror of the original `main`. Do not commit to it. |
| `testing` | Mirror of the original `testing`, where the original accepts contributions. Do not commit to it. |
| `miri/v<release>` | The Paneru release that Miri ships, plus Miri's patches. The `vendor/paneru` gitlink points to a commit on this branch. |

## Choose the branch for a change

A Miri-only engine change goes into Miri's release branch.

1. Start the branch from `miri/v<release>`.
2. Name it `miri/<topic>`, for example `miri/rust-1.99-clippy`.
3. Open the PR in `samanyudas/paneru` with `miri/v<release>` as the base.
4. Merge with a merge commit so that the pinned commit stays on `miri/v<release>`.
5. Update the `vendor/paneru` gitlink in Miri to that commit.

A change for the original project must not contain Miri's patches.

1. Start the branch from the original `testing`, unless the original's contributor guide allows `main` for that change.
2. Name it with a conventional prefix, for example `fix/<topic>` or `feat/<topic>`.
3. Follow the original's `AGENTS.md` before you commit, including `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, and `cargo test --all-targets`.
4. Open the PR in `karinushka/paneru` with `testing` as the base.

When one fix is necessary in both places, make two branches.
Each branch starts from its own base.

## Upgrade to a new release

When Miri moves to a new Paneru release, create `miri/v<new release>` from that release tag.
Rebase Miri's patches onto it.
Drop each patch that the release already contains, such as a fix that the original merged.
