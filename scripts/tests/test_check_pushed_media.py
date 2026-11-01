import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "check-pushed-media.py"
HOOK = ROOT / ".githooks" / "pre-push"


class PushedMediaTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.repo = self.root / "repo"
        subprocess.run(["git", "init", "-q", "--bare", str(self.root / "remote.git")], check=True)
        self.git("init", "-q", "-b", "main", str(self.repo), cwd=self.root)
        self.git("remote", "add", "origin", str(self.root / "remote.git"))
        self.commit({"README.md": "base\n"})
        self.git("push", "-q", "origin", "main")

    def git(self, *args: str, cwd: Path | None = None, env: dict[str, str] | None = None):
        return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", *args], cwd=cwd or self.repo,
                              env=env, check=True, capture_output=True, text=True)

    def commit(self, files: dict[str, str | None], message: str = "change") -> None:
        for name, text in files.items():
            path = self.repo / name
            if text is None:
                path.unlink()
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)

    def check(self) -> tuple[int, str]:
        result = subprocess.run([sys.executable, str(SCRIPT), "HEAD"], cwd=self.repo, capture_output=True, text=True)
        return result.returncode, result.stderr

    def assert_blocked(self, *paths: str) -> str:
        code, output = self.check()
        self.assertEqual(code, 1, output)
        for path in paths:
            self.assertIn(path, output)
        return output

    def test_recordings_are_blocked_anywhere(self):
        self.commit({"assets/demo.mov": "x", "Sources/Miri/spinner.gif": "x", "docs/clip.MP4": "x",
                     "notes/a.m4v": "x", "b.webm": "x"})
        self.assert_blocked("assets/demo.mov", "Sources/Miri/spinner.gif", "docs/clip.MP4", "notes/a.m4v", "b.webm")

    def test_screenshots_outside_app_resources_are_blocked(self):
        self.commit({"docs/shot.png": "x", "shot.jpeg": "x", ".scratch/desktop.heic": "x", "a/assets/b.tiff": "x"})
        self.assert_blocked("docs/shot.png", "shot.jpeg", ".scratch/desktop.heic", "a/assets/b.tiff")

    def test_images_under_assets_and_sources_are_allowed(self):
        self.commit({"assets/icon.png": "x", "Sources/Miri/Resources/menubar.jpg": "x", "assets/icon.svg": "x",
                     "docs/notes.md": "x"})
        self.assertEqual(self.check(), (0, ""))

    def test_media_that_sam_approved_is_allowed(self):
        self.commit({"pr-media/224/drag.mov": "x", "pr-media/224/after.png": "x"},
                    "docs: add drag recording\n\nMedia-approved-by: Sam")
        self.assertEqual(self.check(), (0, ""))
        self.commit({"pr-media/224/other.mov": "x"}, "docs: mention Media-approved-by: Sam in the body only")
        output = self.assert_blocked("pr-media/224/other.mov")
        self.assertNotIn("drag.mov", output)

    def test_media_already_on_a_remote_is_not_reported_again(self):
        self.commit({"docs/old.png": "x"})
        self.git("push", "-q", "origin", "main")
        self.assertEqual(self.check(), (0, ""))
        self.commit({"docs/new.png": "x"})
        output = self.assert_blocked("docs/new.png")
        self.assertNotIn("docs/old.png", output)

    def test_a_file_deleted_by_a_later_commit_is_still_blocked(self):
        # The pushed history keeps the file reachable by commit URL.
        self.commit({"docs/shot.png": "x"})
        self.commit({"docs/shot.png": None})
        self.assert_blocked("docs/shot.png")

    def test_a_merge_reports_only_the_files_it_adds(self):
        self.git("checkout", "-q", "-b", "side")
        self.commit({"assets/icon.png": "x"})
        self.git("checkout", "-q", "main")
        self.commit({"docs/main.md": "x"})
        self.git("merge", "-q", "--no-commit", "side")
        (self.repo / "docs").mkdir(exist_ok=True)
        (self.repo / "docs" / "resolved.gif").write_text("x")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "merge")
        output = self.assert_blocked("docs/resolved.gif")
        self.assertNotIn("assets/icon.png", output)

    def test_the_pre_push_hook_rejects_media_before_the_fast_checks(self):
        for source, target in [(HOOK, ".githooks/pre-push"), (SCRIPT, "scripts/check-pushed-media.py")]:
            (self.repo / target).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, self.repo / target)
        (self.repo / ".git" / "info" / "exclude").write_text(".githooks/\nscripts/\n")
        self.git("config", "core.hooksPath", ".githooks")
        stub = self.root / "bin" / "make"
        stub.parent.mkdir()
        stub.write_text(f"#!/bin/sh\necho \"$@\" >> '{self.root / 'make.log'}'\n")
        stub.chmod(0o755)
        env = {**os.environ, "PATH": f"{stub.parent}{os.pathsep}{os.environ['PATH']}"}

        self.commit({"docs/shot.png": "x"})
        self.commit({"docs/shot.png": None})
        with self.assertRaises(subprocess.CalledProcessError) as push:
            self.git("push", "origin", "main", env=env)
        self.assertIn("docs/shot.png", push.exception.stderr)
        self.assertFalse((self.root / "make.log").exists(), "make pre-push ran after a rejected push")
        self.assertNotEqual(self.git("rev-parse", "origin/main").stdout, self.git("rev-parse", "HEAD").stdout)

        self.git("reset", "-q", "--keep", "origin/main")
        self.commit({"assets/icon.png": "x"})
        self.git("push", "origin", "main", env=env)
        self.assertEqual((self.root / "make.log").read_text(), "--no-print-directory pre-push\n")


if __name__ == "__main__":
    unittest.main()
