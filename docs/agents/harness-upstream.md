# Development tooling provenance

Source: [samanyudas/ai-coding-project-boilerplate](https://github.com/samanyudas/ai-coding-project-boilerplate/tree/bf34a4d2d73e3a5f36f8b28e3d2eb426d00375f0).
Reviewed revision: `bf34a4d2d73e3a5f36f8b28e3d2eb426d00375f0`.
Adaptation scope: [Miri issue 6](https://github.com/samanyudas/miri/issues/6).

| Upstream files | Miri treatment |
| --- | --- |
| `scripts/setup.sh`, `check-ready.sh` | Preserve command names and add live portable/native validation with private worktree stamps. |
| `scripts/verify.sh`, `restore-state.sh`, `end-session.sh` | Preserve lifecycle commands and add named levels, isolated logs, exact source fingerprints, and honest partial scope. |
| `scripts/review-change.sh`, `scan.sh` | Keep advisory review and maintenance without another task registry or status document. |
| `.githooks/pre-commit`, `.claude/settings.json` | Preserve session restoration and opt-in checks with worktree-safe hook installation. |
| `scripts/guard-command.sh`, `test-guard-command.sh` | Preserve guard intent and upstream cases, replace jq/shell parsing with Python standard-library parsing, and add wrapper/invalid-input checks. |
| `scripts/check-ste.py`, `test-ste.py` | Preserve all 13 upstream regression tests, add `decisions/` discovery and an advisory report mode. |
| `scripts/lib/ste_lint.py`, `scripts/lib/ste_lint.LICENSE` | Copy byte-for-byte, including the MIT notice, and verify SHA-256 hashes. |

The immutable files have these SHA-256 values.

```text
1b97b2d22ba50cde10654db56e1b98adf96d250dd3c8f693f8a81361b1084e85  scripts/lib/ste_lint.py
d3c674e8592076c9021a59b55177adbcba6fd7e1710082becb922522b22ec672  scripts/lib/ste_lint.LICENSE
```

The adopted command structure uses shell entrypoints and focused Python standard-library helpers.
Miri does not adopt the template's feature registry, progress/decision files, unfilled verification slots, harness chapters, or document-size limits.
GitHub Issues, `decisions/`, `docs/adr/`, and `GLOSSARY.md` retain their existing authority.
The tooling does not modify app source, the pinned engine, the package manifest, or the existing native build and driver scripts.
