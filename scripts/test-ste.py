#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CHECK = Path(__file__).resolve().with_name("check-ste.py")


class WritingCheckTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ste-repo-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def check(self):
        result = subprocess.run(
            [sys.executable, str(CHECK), "--root", str(self.root), "--json"],
            cwd=self.root.parent, capture_output=True, text=True,
        )
        return result.returncode, json.loads(result.stdout)

    def test_empty_inventory_does_not_wait_for_stdin(self):
        status, report = self.check()
        self.assertEqual(status, 0)
        self.assertEqual(report["files"], [])

    def test_discovery_includes_untracked_and_spaced_paths_from_another_directory(self):
        for name in ("AGENTS.md", "docs/nested/long name.md", ".claude/agents/evaluator.md", "src/a/ARCHITECTURE.md"):
            self.write(name, "Read the file.\n")
        for name in ("harness/notes/history.md", "harness/a/ARCHITECTURE.md", "src/notes.md", "ignored.md"):
            self.write(name, "Spin up the job; stop it.\n")
        self.write(".gitignore", "ignored.md\n")
        subprocess.run(["git", "-C", str(self.root), "add", "AGENTS.md"], check=True)
        status, report = self.check()
        self.assertEqual(status, 0)
        self.assertEqual(report["files"], [".claude/agents/evaluator.md", "AGENTS.md", "docs/nested/long name.md", "src/a/ARCHITECTURE.md"])

    def test_findings_have_locations_and_do_not_hide_advisories(self):
        self.write("AGENTS.md", "The file is removed.\nSpin up the job; stop it.\n")
        status, report = self.check()
        self.assertEqual(status, 1)
        findings = {(item["rule"], item["line"]) for item in report["findings"]}
        self.assertIn(("passive-voice", 1), findings)
        self.assertIn(("semicolon", 2), findings)
        self.assertIn(("phrasal-verb", 2), findings)
        self.assertTrue(all(item["file"] == "AGENTS.md" for item in report["findings"]))

    def test_advisory_alone_is_a_finding(self):
        self.write("AGENTS.md", "The file is removed.\n")
        self.assertEqual(self.check()[0], 1)

    def test_modality_and_code_remain_untouched(self):
        self.write("AGENTS.md", "The request may have failed.\n```\nx = a; y = b\n```\n")
        self.assertEqual(self.check()[0], 0)

    def test_operational_error_keeps_other_findings(self):
        self.write("AGENTS.md", "Spin up the job.\n")
        (self.root / "README.md").write_bytes(b"\xff")
        status, report = self.check()
        self.assertEqual(status, 2)
        self.assertEqual(len(report["errors"]), 1)
        self.assertTrue(report["findings"])

    def test_deleted_tracked_document_is_skipped(self):
        self.write("AGENTS.md", "Read the file.\n")
        subprocess.run(["git", "-C", str(self.root), "add", "AGENTS.md"], check=True)
        (self.root / "AGENTS.md").unlink()
        self.assertEqual(self.check()[0], 0)

    def test_unreadable_tracked_document_keeps_later_findings(self):
        if os.geteuid() == 0:
            self.skipTest("Root bypasses directory permissions")
        self.write("docs/locked/spec.md", "Read the file.\n")
        self.write("docs/z-readable.md", "Spin up the job.\n")
        subprocess.run(["git", "-C", str(self.root), "add", "docs"], check=True)
        locked = self.root / "docs/locked"
        self.addCleanup(locked.chmod, 0o700)
        locked.chmod(0)
        status, report = self.check()
        self.assertEqual(status, 2)
        self.assertEqual(len(report["errors"]), 1)
        self.assertIn("docs/locked/spec.md", report["errors"][0])
        self.assertEqual(report["files"], ["docs/z-readable.md"])
        self.assertTrue(report["findings"])

    def test_unresolvable_root_is_an_operational_error(self):
        loop = self.root / "loop"
        loop.symlink_to("loop")
        result = subprocess.run(
            [sys.executable, str(CHECK), "--root", str(loop), "--json"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 2, result.stderr)
        report = json.loads(result.stdout)
        self.assertTrue(report["errors"])
        self.assertFalse(report["findings"])

    def test_git_failure_is_an_operational_error(self):
        (self.root / ".git").rename(self.root / "git-backup")
        status, report = self.check()
        self.assertEqual(status, 2)
        self.assertIn("File discovery failed", report["errors"][0])

    def test_external_symlink_is_an_operational_error(self):
        (self.root / "AGENTS.md").symlink_to(CHECK)
        status, report = self.check()
        self.assertEqual(status, 2)
        self.assertFalse(report["files"])

    def test_symlink_loop_is_an_operational_error(self):
        (self.root / "AGENTS.md").symlink_to("AGENTS.md")
        status, report = self.check()
        self.assertEqual(status, 2)
        self.assertEqual(len(report["errors"]), 1)

    def test_miri_decisions_are_maintained_and_vendor_is_excluded(self):
        self.write("decisions/nested/decision with spaces.md", "Read the file.\n")
        self.write("vendor/paneru/README.md", "Spin up the job; stop it.\n")
        status, report = self.check()
        self.assertEqual(status, 0)
        self.assertEqual(report["files"], ["decisions/nested/decision with spaces.md"])

    def test_advisory_mode_preserves_findings_but_fails_tool_errors(self):
        self.write("decisions/a.md", "Spin up the job; stop it.\n")
        args = [sys.executable, str(CHECK), "--root", str(self.root), "--json", "--advisory"]
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertTrue(json.loads(result.stdout)["findings"])
        (self.root / "decisions/a.md").write_bytes(b"\xff")
        result = subprocess.run(args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertTrue(json.loads(result.stdout)["errors"])

    def test_vendor_regressions(self):
        result = subprocess.run([sys.executable, str(CHECK.parent / "lib/ste_lint.py"), "--selftest"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("selftest OK", result.stdout)


if __name__ == "__main__":
    unittest.main()
