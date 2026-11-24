import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "ci-needs-native.py"


class CiNeedsNativeTest(unittest.TestCase):
    def decide(self, changes: dict[str, str | None], base: dict[str, str] | None = None) -> dict[str, str]:
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
            return dict(line.split("=", 1) for line in result.stdout.strip().splitlines())

    def test_documentation_alone_skips_all_macos_jobs(self):
        changes = {"README.md": "new\n", "docs/adr/0001.md": "x\n", "decisions/release-scope.md": "x\n",
                   ".github/ISSUE_TEMPLATE/task.yml": "x\n", ".claude/hooks/guard-command.py": "x\n"}
        self.assertEqual(
            self.decide(changes),
            {"native": "false", "swift": "false", "engine": "false", "app": "false"},
        )

    def test_swift_sources_run_swift_and_app_without_engine(self):
        for code in ["Sources/MiriCore/Bindings.swift", "Localization/Localizable.xcstrings", "Package.swift"]:
            with self.subTest(code=code):
                self.assertEqual(
                    self.decide({"docs/notes.md": "x\n", code: "x\n"}),
                    {"native": "true", "swift": "true", "engine": "false", "app": "true"},
                )

    def test_swift_tests_and_format_run_swift_only(self):
        for code in ["Tests/MiriCoreTests/BindingsTests.swift", ".swift-format",
                     "scripts/sync-strings.sh", "scripts/check-strings.py"]:
            with self.subTest(code=code):
                self.assertEqual(
                    self.decide({code: "x\n"}),
                    {"native": "true", "swift": "true", "engine": "false", "app": "false"},
                )

    def test_engine_changes_run_engine_and_app_without_swift(self):
        for code in ["vendor/paneru", "rust-toolchain.toml", ".cargo/config.toml"]:
            with self.subTest(code=code):
                self.assertEqual(
                    self.decide({"docs/notes.md": "x\n", code: "x\n"}),
                    {"native": "true", "swift": "false", "engine": "true", "app": "true"},
                )

    def test_app_packaging_changes_run_app_only(self):
        for code in ["assets/icon.svg", "LICENSE", "scripts/build-app.sh", "scripts/package-dmg.sh"]:
            with self.subTest(code=code):
                self.assertEqual(
                    self.decide({code: "x\n"}),
                    {"native": "true", "swift": "false", "engine": "false", "app": "true"},
                )

    def test_shared_or_unknown_files_run_all_macos_jobs(self):
        for code in ["Makefile", ".github/workflows/ci.yml", "scripts/doctor.sh", "unknown.txt"]:
            with self.subTest(code=code):
                self.assertEqual(
                    self.decide({"docs/notes.md": "x\n", code: "x\n"}),
                    {"native": "true", "swift": "true", "engine": "true", "app": "true"},
                )

    def test_mixed_swift_and_engine_changes_run_all_macos_jobs(self):
        self.assertEqual(
            self.decide({"Sources/Miri/App.swift": "x\n", "vendor/paneru": "x\n"}),
            {"native": "true", "swift": "true", "engine": "true", "app": "true"},
        )

    def test_moving_code_into_documentation_runs_its_macos_jobs(self):
        # Git reports a rename by its destination only, which would hide the removed source file.
        code = {"Sources/MiriCore/Bindings.swift": "struct Bindings {}\n"}
        moved = {"Sources/MiriCore/Bindings.swift": None, "docs/Bindings.md": "struct Bindings {}\n"}
        self.assertEqual(
            self.decide(moved, base=code),
            {"native": "true", "swift": "true", "engine": "false", "app": "true"},
        )

    def test_an_empty_diff_runs_all_macos_jobs(self):
        self.assertEqual(
            self.decide({}),
            {"native": "true", "swift": "true", "engine": "true", "app": "true"},
        )

    def test_a_bad_revision_fails_instead_of_skipping(self):
        result = subprocess.run([sys.executable, str(SCRIPT), "no-such-revision"], cwd=tempfile.gettempdir(),
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("native=false", result.stdout)


if __name__ == "__main__":
    unittest.main()
