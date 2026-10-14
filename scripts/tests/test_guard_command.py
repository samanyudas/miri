import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parents[2] / ".claude/hooks/guard-command.py"


class GuardCommandTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.on_main = cls.directory.name
        subprocess.run(["git", "init", "-q", "-b", "main", cls.on_main], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    def decide(self, command: str, cwd: str | None = None) -> str:
        event = {"tool_name": "Bash", "tool_input": {"command": command}, "cwd": cwd or self.on_main}
        result = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(event),
                                capture_output=True, text=True)
        self.assertIn(result.returncode, (0, 2), result.stderr)
        return "allow" if result.returncode == 0 else result.stderr.strip()

    def test_blocks_irreversible_and_outward_commands(self):
        blocked = {
            "git push --force origin feature": "force push",
            "git push -fu origin feature": "force push",
            "git push origin +feature": "force push",
            "git push origin main": "pushing to main",
            "git push origin HEAD:refs/heads/main": "pushing to main",
            "git push": "pushing to main",
            "git push origin v1.0.0": "version tag",
            "git push --tags": "--tags",
            "git push -d origin feature": "--delete",
            "cd /tmp && git -C repo reset --hard HEAD~1": "reset --hard",
            "git clean -xfd": "git clean",
            "git branch -D old": "branch -D",
            "gh pr merge 12 --squash": "merging",
            "gh release create v1.0.0": "release",
            "gh repo edit --visibility public": "repository settings",
            "sudo tccutil reset Accessibility": "privacy permissions",
            "defaults write com.apple.dock autohide -bool true": "macOS settings",
            "bash -c 'git push --force'": "force push",
            "FOO=1 env git push origin main": "pushing to main",
        }
        for command, reason in blocked.items():
            with self.subTest(command=command):
                self.assertIn(reason, self.decide(command))

    def test_allows_ordinary_development(self):
        for command in [
            "git status && git log --oneline -5",
            "git push -u origin chore/repo-harness",
            "git push --force-with-lease origin chore/repo-harness",
            "git reset --soft HEAD~1",
            "git branch -d merged-branch",
            "gh pr view 7 --comments",
            "gh release list",
            "defaults read com.apple.spaces spans-displays",
            "echo 'git push --force origin main'",
            "grep -n 'tccutil reset' docs/*.md",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.decide(command), "allow")


if __name__ == "__main__":
    unittest.main()
