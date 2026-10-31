import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "ci-needs-native.py"


class CiNeedsNativeTest(unittest.TestCase):
    def decide(self, changes: dict[str, str | None], base: dict[str, str] | None = None) -> str:
        with tempfile.TemporaryDirectory() as directory:
            def git(*args: str) -> None:
                subprocess.run(["git", "-C", directory, "-c", "user.name=t", "-c", "user.email=t@t", *args],
                               check=True, capture_output=True)

            git("init", "-q", "-b", "main")
            for name, text in {"README.md": "base\n", **(base or {})}.items():
                path = Path(directory, name)
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            git("add", "-A")
            git("commit", "-q", "-m", "base")
            for name, text in changes.items():
                path = Path(directory, name)
                if text is None:
                    path.unlink()
                    continue
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            git("add", "-A")
            git("commit", "-q", "--allow-empty", "-m", "change")
            result = subprocess.run([sys.executable, str(SCRIPT), "HEAD^"], cwd=directory,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout.strip()

    def test_documentation_alone_skips_the_macos_job(self):
        changes = {"README.md": "new\n", "docs/adr/0001.md": "x\n", "decisions/release-scope.md": "x\n",
                   ".github/ISSUE_TEMPLATE/task.yml": "x\n", ".claude/hooks/guard-command.py": "x\n"}
        self.assertEqual(self.decide(changes), "native=false")

    def test_one_code_file_among_documentation_runs_the_macos_job(self):
        # A change hidden among documentation must still run the macOS job instead of passing unbuilt.
        for code in ["Sources/MiriCore/Bindings.swift", "LICENSE", "Makefile", "rust-toolchain.toml",
                     "assets/icon.svg", ".github/workflows/ci.yml", "scripts/build-app.sh", "vendor/paneru"]:
            with self.subTest(code=code):
                self.assertEqual(self.decide({"docs/notes.md": "x\n", code: "x\n"}), "native=true")

    def test_moving_code_into_documentation_runs_the_macos_job(self):
        # Git reports a rename by its destination only, which would hide the removed source file.
        code = {"Sources/MiriCore/Bindings.swift": "struct Bindings {}\n"}
        moved = {"Sources/MiriCore/Bindings.swift": None, "docs/Bindings.md": "struct Bindings {}\n"}
        self.assertEqual(self.decide(moved, base=code), "native=true")

    def test_an_empty_diff_runs_the_macos_job(self):
        self.assertEqual(self.decide({}), "native=true")

    def test_a_bad_revision_fails_instead_of_skipping(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "no-such-revision"], cwd=tempfile.gettempdir(),
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("native=false", result.stdout)


if __name__ == "__main__":
    unittest.main()
