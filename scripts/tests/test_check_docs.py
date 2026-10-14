import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check-docs.py"
PROGRESS = """# Progress

Updated: 2026-10-14 by Sam on main

## Objective
## Done
## Next
## Blockers
## Last verification
"""


class CheckDocsTest(unittest.TestCase):
    def run_checker(self, files: dict[str, str]) -> tuple[int, list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = {"AGENTS.md": "# Map\n", "PROGRESS.md": PROGRESS, **files}
            for name, text in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text, encoding="utf-8")
            subprocess.run(["git", "init", "-q", str(root)], check=True)
            subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
            result = subprocess.run([sys.executable, str(CHECKER), str(root)],
                                    capture_output=True, text=True)
            return result.returncode, result.stdout.splitlines()

    def test_clean_repository_passes(self):
        code, problems = self.run_checker({
            "docs/a b.md": "# Binding customization\n\n## Binding customization\n",
            "README.md": "[a](docs/a%20b.md#binding-customization-1) [web](https://x.test) `[no](gone.md)`\n"
                         "```\n[no](gone.md)\n```\n<img src=\"docs/a b.md\">\n",
        })
        self.assertEqual((code, problems), (0, []))

    def test_reports_each_broken_link_kind(self):
        code, problems = self.run_checker({
            "docs/target.md": "# Real heading\n",
            "README.md": "[a](docs/missing.md)\n[b](docs/target.md#fake)\n[c](../outside.md)\n",
        })
        self.assertEqual(code, 1)
        self.assertEqual(problems, [
            "README.md:1: missing link target: docs/missing.md",
            "README.md:2: missing heading anchor: docs/target.md#fake",
            "README.md:3: link leaves the repository: ../outside.md",
        ])

    def test_rejects_em_dash_outside_vendor(self):
        code, problems = self.run_checker({
            "notes.md": "fine\nnot fine " + chr(0x2014) + " here\n",
            "vendor/upstream.md": "upstream " + chr(0x2014) + " text\n",
        })
        self.assertEqual((code, problems), (1, ["notes.md:2: em dash; use a plain dash"]))

    def test_requires_short_agent_map_and_complete_progress(self):
        code, problems = self.run_checker({
            "AGENTS.md": "line\n" * 121,
            "PROGRESS.md": "# Progress\n\n## Objective\n## Done\n## Next\n## Last verification\n",
        })
        self.assertEqual(code, 1)
        self.assertEqual(problems, [
            "AGENTS.md: longer than 120 lines; move detail into docs/",
            "PROGRESS.md: missing '## Blockers' section",
            "PROGRESS.md: missing 'Updated: YYYY-MM-DD' line",
        ])


if __name__ == "__main__":
    unittest.main()
