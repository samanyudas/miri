import importlib.util
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
            "git push --no-verify -u origin feature": "pre-push checks",
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

    def test_issue_create_needs_exactly_one_type_label(self):
        for command in [
            f"gh issue create -t Gap -b '{BUG}'",
            f"gh issue create -t Gap -l needs-triage -b '{BUG}'",
            f"gh issue create -t Gap -l bug,task -b '{BUG}'",
            f"gh issue new -t Gap -l bug --label enhancement -b '{BUG}'",
            f"gh issue create -t Gap --body-file - <<'EOF'\nSam's Mac.\n{BUG}\nEOF",
        ]:
            with self.subTest(command=command):
                reason = self.decide(command)
                self.assertIn("exactly one type label", reason)
                self.assertIn("bug, decision, enhancement, task", reason)

    def test_issue_create_names_each_missing_section(self):
        blocked = {
            "gh issue create -t 'fix: gap' -l bug -b 'Windows overlap.'": "Missing: Steps to reproduce, Expected result, "
            "Actual result, Acceptance criteria, Miri version or commit, macOS version and Mac model.",
            f"gh issue create -t 'fix: gap' -l bug -b '{BUG.replace('Actual result', 'Result')}'": "Missing: Actual result.",
            f"gh issue create -t 'feat: strip' -l enhancement -b '{FEATURE_WITHOUT_SOURCE}'": "Missing: Requested by, Release.",
            "gh issue create -t 'chore: gap' -l task -b '## Acceptance\n- works'": "Missing: Outcome, Acceptance criteria",
            "bash -c 'gh issue create -t \"decision: gap\" -l decision -b nothing'": "Missing: Question, Options, Acceptance criteria.",
        }
        for command, reason in blocked.items():
            with self.subTest(command=command):
                decision = self.decide(command)
                self.assertIn(reason, decision)
                self.assertIn("See File an issue in CONTRIBUTING.md", decision)

    def test_issue_create_allows_complete_issues_however_the_body_arrives(self):
        for command in [
            f"gh issue create -t 'fix: gap' -l 'bug,needs-triage' -b '{BUG}'",
            f"gh issue create --title='feat(settings): strip' --label=enhancement --body '{FEATURE}'",
            f"gh issue create -t 'chore: permission' -l task -b '{TASK}'",
            f"gh issue create --title 'decision: placement' -l decision -l needs-triage -b '{DECISION}'",
            f"gh issue create -t 'fix: gap' -l bug --body \"$(cat <<'EOF'\n{BUG}\nEOF\n)\"",
            f"gh issue create -t 'fix: gap' -l bug --body-file - <<'EOF'\nSam's Mac.\n{BUG}\nEOF",
            f"gh issue create -t \"fix: gap\" -l \"needs-triage, bug\" -F - <<'EOF'\nSam's Mac.\n{BUG}\nEOF",
            f"gh issue create -t 'chore: permission' -l task --body=\"{TASK_ESCAPED}\"",
            "gh issue create --web",
            "gh issue view 7 --comments",
            "gh issue comment 7 --body 'Reproduced on main.'",
            "gh issue edit 7 --add-label needs-info",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.decide(command), "allow")

        with tempfile.TemporaryDirectory() as directory:
            Path(directory, "bug.md").write_text(BUG)
            Path(directory, "vague.md").write_text("Windows overlap.\n")
            self.assertEqual(self.decide("gh issue create -t 'fix: gap' -l bug -F bug.md", directory), "allow")
            self.assertIn("Missing: Steps to reproduce", self.decide("gh issue create -t 'fix: gap' -l bug -F vague.md", directory))

    def test_issue_create_needs_the_template_title_prefix(self):
        blocked = {
            f"gh issue create -l bug -b '{BUG}'": "This command gives no title",
            f"gh issue create -t Gap -l bug -b '{BUG}'": "This command gives 'Gap'",
            f"gh issue create -t 'feat: gap' -l bug -b '{BUG}'": "starts with 'fix: '",
            f"gh issue create -t 'fix:gap' -l bug -b '{BUG}'": "starts with 'fix: '",
            f"gh issue create -t 'Fix: gap' -l bug -b '{BUG}'": "starts with 'fix: '",
            f"gh issue create -t 'fix(Settings): gap' -l bug -b '{BUG}'": "starts with 'fix: '",
            f"gh issue create -t 'fix: gap' -l enhancement -b '{FEATURE}'": "starts with 'feat: '",
            f"gh issue create -t Gap -l bug --body-file - <<'EOF'\nSam's Mac.\n{BUG}\nEOF": "starts with 'fix: '",
        }
        for command, reason in blocked.items():
            with self.subTest(command=command):
                decision = self.decide(command)
                self.assertIn(reason, decision)
                self.assertIn("See File an issue in CONTRIBUTING.md", decision)

    def test_every_template_sets_a_title_prefix(self):
        prefixes = {type_label: issue_type.title_prefix for type_label, issue_type in template_sections().items()}
        self.assertEqual(prefixes, {"bug": "fix", "decision": "decision", "enhancement": "feat", "task": "chore"})

    def test_every_template_section_is_required(self):
        for type_label, (prefix, sections) in template_sections().items():
            body = "\n".join(f"### {section}\nFilled in.\n" for section in sections)
            title = f"'{prefix}: title'"
            with self.subTest(type_label=type_label):
                self.assertEqual(self.decide(f"gh issue create -t {title} -l {type_label} -b '{body}'"), "allow")
            for section in sections:
                without = body.replace(f"### {section}\n", "")
                with self.subTest(type_label=type_label, section=section):
                    self.assertIn(f"Missing: {section}.",
                                  self.decide(f"gh issue create -t {title} -l {type_label} -b '{without}'"))


def template_sections() -> dict[str, list[str]]:
    spec = importlib.util.spec_from_file_location("guard_command", HOOK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.issue_types()


def sections(*pairs: str) -> str:
    return "\n\n".join(f"### {pairs[i]}\n{pairs[i + 1]}" for i in range(0, len(pairs), 2))


BUG = sections(
    "Steps to reproduce", "1. Connect a second display.\n2. Press Control-Option-Command-D.",
    "Expected result", "Every window stays on screen.",
    "Actual result", "One window moves off-screen.",
    "Acceptance criteria", "- Following the steps, every window stays reachable.",
    "Miri version or commit", "fabf16d4",
    "macOS version and Mac model", "macOS 27.0, MacBook Air M3",
)
FEATURE_WITHOUT_SOURCE = sections(
    "Problem", "One strip spans both displays.",
    "Proposed behavior", "Each display scrolls its own strip.",
    "Acceptance criteria", "- With two displays, each strip scrolls alone.",
)
FEATURE = FEATURE_WITHOUT_SOURCE + "\n\n" + sections("Requested by", "Sam", "Release", "v2")
TASK = sections(
    "Outcome", "Miri names the missing permission at launch.",
    "Acceptance criteria", "- make test passes.",
    "Verification level", "make check",
)
TASK_ESCAPED = TASK.replace("\n", "\\n")
DECISION = sections(
    "Question", "Should new windows open beside the focused window?",
    "Options", "Beside the focused window, or at the end of the strip.",
    "Acceptance criteria", "- Sam records the answer in decisions/new-window-placement.md.",
    "Recommendation", "Beside the focused window.",
)


if __name__ == "__main__":
    unittest.main()
