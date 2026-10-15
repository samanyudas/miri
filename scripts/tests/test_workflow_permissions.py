import re
import unittest
from pathlib import Path

WORKFLOWS = Path(__file__).resolve().parents[2] / ".github/workflows"

# A job that makes one of these calls needs one of the scopes, or GitHub answers 403 only after the event fires.
SCOPE_CALLS = [
    (re.compile(r"repos/\$GH_REPO/pulls/|\bgh pr "), {"pull-requests"}),
    (re.compile(r"repos/\$GH_REPO/issues/|\bgh issue "), {"issues"}),
    (re.compile(r"\bgh label "), {"issues", "pull-requests"}),
]
WRITES = re.compile(r"\bgh (issue|pr) (comment|create|edit|close|reopen)\b|\bgh label (create|edit|delete)\b"
                    r"|\bgh api\b.* (-f|-F|--field|--raw-field|-X (POST|PATCH|PUT|DELETE))\b")


def scopes(block: list[str], indent: int) -> dict[str, str] | None:
    for index, line in enumerate(block):
        if line == " " * indent + "permissions:":
            found = {}
            for entry in block[index + 1:]:
                match = re.fullmatch(r" {%d}([a-z-]+): (read|write)" % (indent + 2), entry)
                if not match:
                    break
                found[match.group(1)] = match.group(2)
            return found
    return None


def jobs(text: str) -> tuple[dict[str, str], dict[str, list[str]]]:
    lines = text.splitlines()
    start = lines.index("jobs:")
    workflow = scopes(lines[:start], 0) or {}
    found: dict[str, list[str]] = {}
    for line in lines[start + 1:]:
        match = re.fullmatch(r"  ([a-z0-9_-]+):", line)
        if match:
            found[match.group(1)] = []
        elif found:
            found[next(reversed(found))].append(line)
    return workflow, found


def missing_scopes(text: str) -> list[str]:
    workflow, found = jobs(text)
    problems = []
    for name, block in found.items():
        granted = scopes(block, 4)
        granted = workflow if granted is None else granted
        for line in block:
            level = "write" if WRITES.search(line) else "read"
            for call, accepted in SCOPE_CALLS:
                allowed = {scope for scope in accepted if granted.get(scope) in ("write", level)}
                problem = f"{name}: needs {' or '.join(sorted(accepted))} {level}"
                if call.search(line) and not allowed and problem not in problems:
                    problems.append(problem)
    return problems


class WorkflowPermissionsTest(unittest.TestCase):
    def test_every_job_has_the_scopes_its_api_calls_need(self):
        for path in sorted(WORKFLOWS.glob("*.yml")):
            with self.subTest(workflow=path.name):
                self.assertEqual(missing_scopes(path.read_text(encoding="utf-8")), [])

    def test_job_permissions_replace_the_workflow_permissions(self):
        text = """permissions:
  issues: write

jobs:
  inherits:
    steps:
      - run: gh api "repos/$GH_REPO/pulls/1"
  overrides:
    permissions:
      pull-requests: read
    steps:
      - run: gh issue comment 1 --body hi
"""
        self.assertEqual(missing_scopes(text), ["inherits: needs pull-requests read", "overrides: needs issues write"])

    def test_a_read_scope_does_not_allow_a_write(self):
        text = """jobs:
  labels:
    permissions:
      issues: read
    steps:
      - run: |
          gh issue list --label bug
          gh api "repos/$GH_REPO/issues/1/labels" -f "labels[]=bug" --silent
"""
        self.assertEqual(missing_scopes(text), ["labels: needs issues write"])


if __name__ == "__main__":
    unittest.main()
