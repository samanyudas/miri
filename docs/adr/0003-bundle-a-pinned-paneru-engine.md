---
status: accepted
---

# Bundle a pinned Paneru-based engine

Miri bundles a Paneru-based engine at a fixed revision rather than requiring a separate Paneru installation or replacing the engine entirely.
This keeps the app and its engine version together while reusing Paneru's scrolling window management.
Engine changes focus on app integration, isolation, and verified compatibility fixes.
Compatibility fixes are contributed upstream where possible rather than establishing a permanent Paneru fork.
Paneru's documented horizontal display limitations remain a v1 release blocker until reliable scrolling is verified.
Miri pins the latest Paneru release tag rather than a commit on `main`, and upgrades one tag at a time after a multi-monitor regression check.
Sparkle delivers engine upgrades together with app updates.
Miri's patches live in the `samanyudas/paneru` fork, included as a git submodule and rebased onto each release tag.
The engine runs as a helper process, as recorded in [ADR 0009](0009-run-the-engine-as-a-helper-process.md).
