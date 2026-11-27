import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HOOK = Path(__file__).resolve().parents[2] / ".claude/hooks/guard-command.py"
ADAPTER = Path(__file__).resolve().parents[2] / ".agents/hooks/guard-command.py"


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
            "git push -d origin main": "deleting main",
            "git push --delete origin main": "deleting main",
            "git push origin :main": "deleting main",
            "git push origin :refs/heads/main": "deleting main",
            "git push origin v1.0.0": "version tag",
            "git push --tags": "--tags",
            "git push --mirror origin": "--mirror",
            "git push --prune origin": "--prune",
            "git push --no-verify -u origin feature": "pre-push checks",
            "cd /tmp && git -C repo reset --hard HEAD~1": "reset --hard",
            "git clean -xfd": "git clean",
            "gh pr merge 12 --admin": "branch protection",
            "gh pr merge 12 --squash --admin=true": "branch protection",
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

    def test_allows_ordinary_development_and_cleanup(self):
        for command in [
            "git status && git log --oneline -5",
            "git push -u origin chore/repo-harness",
            "git push --force-with-lease origin chore/repo-harness",
            "git push -d origin feat/temp-probe",
            "git push --delete origin feat/temp-probe",
            "git push origin :feat/temp-probe",
            "git reset --soft HEAD~1",
            "git branch -d merged-branch",
            "git branch -D scratch-branch",
            "gh issue create -t 'Short bug title' -b 'Repro notes.'",
            "gh pr create -t 'fix: x' -b 'Fixed it.'",
            "gh pr view 7 --comments",
            "gh pr merge 12 --merge",
            "gh release list",
            "defaults read com.apple.spaces spans-displays",
            "echo 'git push --force origin main'",
            "grep -n 'tccutil reset' docs/*.md",
            "python3 - << 'EOF'\nmsg = \"Sam's note mentioning gh issue create and gh pr create\"\nprint(msg)\nEOF",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.decide(command), "allow")

    def test_antigravity_adapter_delegates_shell_commands(self):
        def run_adapter(tool_name: str, args: dict) -> dict:
            event = {"toolCall": {"name": tool_name, "args": args}, "cwd": self.on_main}
            result = subprocess.run([sys.executable, str(ADAPTER)], input=json.dumps(event),
                                    capture_output=True, text=True, check=True)
            return json.loads(result.stdout)

        denied_merge = run_adapter("run_command", {"CommandLine": "gh pr merge 12 --admin"})
        self.assertEqual(denied_merge["decision"], "deny")
        self.assertIn("branch protection", denied_merge["reason"])

        allowed_pr = run_adapter("run_command", {"CommandLine": "gh pr create -t 'fix: x' -b 'Body.'"})
        self.assertEqual(allowed_pr["decision"], "allow")


if __name__ == "__main__":
    unittest.main()
