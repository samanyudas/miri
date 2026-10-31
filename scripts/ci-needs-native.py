#!/usr/bin/env python3
"""Print native=true unless every path changed since the given revision is documentation that the macOS job never reads."""
import subprocess
import sys

# The Linux lint job still checks these. Anything else, including a path this list forgets, runs the macOS job.
DOC_PREFIXES = ("docs/", "decisions/", ".github/ISSUE_TEMPLATE/", ".claude/")


def needs_native(paths: list[str]) -> bool:
    if not paths:
        return True
    return any(not (path.endswith(".md") or path.startswith(DOC_PREFIXES)) for path in paths)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: ci-needs-native.py BASE_REVISION", file=sys.stderr)
        return 2
    diff = subprocess.run(["git", "diff", "--name-only", sys.argv[1], "HEAD"], capture_output=True, text=True)
    if diff.returncode != 0:
        print(diff.stderr, end="", file=sys.stderr)
        return 1
    paths = diff.stdout.splitlines()
    native = needs_native(paths)
    for path in paths:
        print(f"{'runs' if needs_native([path]) else 'skips'} native: {path}", file=sys.stderr)
    print(f"native={'true' if native else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
