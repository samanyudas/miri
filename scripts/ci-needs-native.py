#!/usr/bin/env python3
"""Decide which macOS CI jobs need to run for the diff since the given revision.

Outputs `swift`, `engine`, `app`, and `native` booleans for GITHUB_OUTPUT.
Any unrecognized path or empty diff enables all macOS jobs so CI never silently skips a check.
"""
import subprocess
import sys

# The Linux lint job still checks these. Anything else, including a path this list forgets, runs macOS jobs.
DOC_PREFIXES = ("docs/", "decisions/", ".github/ISSUE_TEMPLATE/", ".claude/")

SWIFT_ONLY_PREFIXES = ("Tests/",)
SWIFT_ONLY_FILES = {
    ".swift-format",
    "scripts/sync-strings.sh",
    "scripts/check-strings.py",
}

SWIFT_AND_APP_PREFIXES = ("Sources/", "Localization/")
SWIFT_AND_APP_FILES = {"Package.swift"}

ENGINE_AND_APP_PREFIXES = ("vendor/paneru/", ".cargo/")
ENGINE_AND_APP_FILES = {"vendor/paneru", "rust-toolchain.toml", ".gitmodules"}

APP_ONLY_PREFIXES = ("assets/",)
APP_ONLY_FILES = {
    "LICENSE",
    "scripts/build-app.sh",
    "scripts/package-dmg.sh",
    "scripts/test-permission-prototype.sh",
    "scripts/test-window-recovery.sh",
    "scripts/live-lock.py",
}

ALL_JOBS = frozenset({"swift", "engine", "app"})


def jobs_for_path(path: str) -> frozenset[str]:
    if path.endswith(".md") or path.startswith(DOC_PREFIXES):
        return frozenset()
    if path.startswith(SWIFT_ONLY_PREFIXES) or path in SWIFT_ONLY_FILES:
        return frozenset({"swift"})
    if path.startswith(SWIFT_AND_APP_PREFIXES) or path in SWIFT_AND_APP_FILES:
        return frozenset({"swift", "app"})
    if path.startswith(ENGINE_AND_APP_PREFIXES) or path in ENGINE_AND_APP_FILES:
        return frozenset({"engine", "app"})
    if path.startswith(APP_ONLY_PREFIXES) or path in APP_ONLY_FILES:
        return frozenset({"app"})
    return ALL_JOBS


def needed_jobs(paths: list[str]) -> set[str]:
    if not paths:
        return set(ALL_JOBS)
    selected: set[str] = set()
    for path in paths:
        selected.update(jobs_for_path(path))
    return selected


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: ci-needs-native.py BASE_REVISION", file=sys.stderr)
        return 2
    # Without --no-renames, a file moved into docs/ would hide the source path it removed.
    diff = subprocess.run(["git", "diff", "--name-only", "--no-renames", sys.argv[1], "HEAD"],
                          capture_output=True, text=True)
    if diff.returncode != 0:
        print(diff.stderr, end="", file=sys.stderr)
        return 1
    paths = diff.stdout.splitlines()
    selected = needed_jobs(paths)
    for path in paths:
        jobs = sorted(jobs_for_path(path))
        label = ",".join(jobs) if jobs else "none"
        print(f"runs {label}: {path}", file=sys.stderr)
    print(f"native={'true' if selected else 'false'}")
    for job in ("swift", "engine", "app"):
        print(f"{job}={'true' if job in selected else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
