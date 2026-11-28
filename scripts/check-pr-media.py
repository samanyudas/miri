#!/usr/bin/env python3
"""Require uploaded media (or an explicit 'No visible change') on PRs that touch Miri's UI."""

from __future__ import annotations

import os
import re
import subprocess
import sys

UI_PREFIXES = ("Sources/Miri/", "assets/")
COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
MEDIA_RE = re.compile(
    r"https://github\.com/user-attachments/assets/"
    r"|<img\b[^>]*\bsrc="
    r"|!\[[^\]]*\]\([^)]+\)"
    r"|https?://\S+\.(?:png|jpe?g|gif|webp|mp4|mov)\b",
    re.IGNORECASE,
)
NO_VISIBLE_CHANGE_RE = re.compile(r"\bno visible change\b", re.IGNORECASE)


def ui_paths(paths: list[str]) -> list[str]:
    return [path for path in paths if path.startswith(UI_PREFIXES)]


def body_satisfies_media_rule(body: str) -> bool:
    visible = COMMENT_RE.sub("", body or "")
    return bool(MEDIA_RE.search(visible) or NO_VISIBLE_CHANGE_RE.search(visible))


def changed_files(base: str) -> list[str]:
    out = subprocess.check_output(["git", "diff", "--name-only", base, "HEAD"], text=True)
    return [line.strip() for line in out.splitlines() if line.strip()]


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check-pr-media.py <base-ref>", file=sys.stderr)
        return 2
    touched = ui_paths(changed_files(argv[1]))
    if not touched:
        print("check-pr-media: no UI files changed")
        return 0
    body = os.environ.get("PR_BODY", "")
    if body_satisfies_media_rule(body):
        print(f"check-pr-media: ok ({len(touched)} UI file(s) changed)")
        return 0
    sample = ", ".join(touched[:5])
    if len(touched) > 5:
        sample += f", ... (+{len(touched) - 5} more)"
    print(
        f"check-pr-media: PR touches UI files ({sample}) without attached media.\n"
        "Capture disposable windows with `verify-miri capture --settings` or `verify-miri record`, "
        "upload them with `verify-miri upload --pr <number>`, and add them to the PR description "
        "(see docs/AI-CONTRIBUTIONS.md#capture-evidence).\n"
        'If nobody can see or feel the change, write "No visible change" in the PR description.',
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
