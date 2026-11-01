#!/usr/bin/env python3
"""Reject a push whose new commits add a screen recording, or a still image outside the app's resources.

GitHub keeps every pushed file reachable by commit URL after its branch is deleted, so this reads every commit that
is not yet on a remote, not only the final tree. The pre-push hook passes the local objects it pushes.
A commit with a `Media-approved-by:` trailer passes, because Sam viewed and approved its files.
"""
import subprocess
import sys
from pathlib import PurePosixPath
from typing import NamedTuple

APPROVAL_TRAILER = "Media-approved-by"


class Rule(NamedTuple):
    extensions: frozenset[str]
    allowed_prefixes: tuple[str, ...]
    reason: str


RULES = (
    Rule(frozenset({".mov", ".mp4", ".m4v", ".webm", ".gif"}), (),
         "recordings stay local, so describe what they show in text"),
    Rule(frozenset({".png", ".jpg", ".jpeg", ".heic", ".tif", ".tiff"}), ("assets/", "Sources/"),
         "images belong only under assets/ or Sources/, so attach an approved screenshot to the PR instead"),
)


def violation(path: str) -> str | None:
    suffix = PurePosixPath(path).suffix.lower()
    for rule in RULES:
        if suffix in rule.extensions and not path.startswith(rule.allowed_prefixes):
            return rule.reason
    return None


def git(*args: str) -> str:
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def added_paths(commit: str) -> list[str]:
    # -c reports what a merge adds itself, and skips files that a merged parent already had.
    output = git("diff-tree", "-r", "-c", "--root", "--no-commit-id", "--no-renames", "--diff-filter=A",
                 "--name-only", "-z", commit)
    return [path for path in output.split("\0") if path]


def approved(commit: str) -> bool:
    return bool(git("log", "-1", f"--format=%(trailers:key={APPROVAL_TRAILER},valueonly)", commit).strip())


def main(objects: list[str]) -> int:
    if not objects:
        return 0
    try:
        problems = [(commit, path, reason)
                    for commit in git("rev-list", *objects, "--not", "--remotes").split()
                    if not approved(commit)
                    for path in added_paths(commit)
                    if (reason := violation(path))]
    except subprocess.CalledProcessError as error:
        print(f"check-pushed-media: {error.stderr.strip()}", file=sys.stderr)
        return 1
    if not problems:
        return 0
    print("pre-push: these files would stay public on GitHub even after a later commit deletes them:", file=sys.stderr)
    for commit, path, reason in problems:
        print(f"  {path} in {commit[:12]}: {reason}", file=sys.stderr)
    print("Remove them from the unpushed commits, for example with git rebase, then push again.", file=sys.stderr)
    print(f"If Sam viewed and approved them, commit them with a '{APPROVAL_TRAILER}: Sam' trailer.", file=sys.stderr)
    print("docs/AI-CONTRIBUTIONS.md#capture-evidence says how to share window evidence.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
