import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "live-lock.py"


class LiveLockTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name, "miri-live.lock")

    def lock(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, str(SCRIPT), *args], capture_output=True, text=True,
                              env={**os.environ, "MIRI_LIVE_LOCK": str(self.path)})

    def take(self, owner: str, minutes: str = "30") -> subprocess.CompletedProcess:
        return self.lock("take", "--owner", owner, "--minutes", minutes, "--task", "drag test")

    def test_a_free_lock_records_owner_task_and_expiry(self):
        self.assertEqual(self.lock("status").returncode, 0)
        self.assertEqual(self.take("thread A").returncode, 0)
        text = self.path.read_text()
        self.assertIn("owner: thread A\ntask: drag test\nstarted: ", text)
        self.assertIn("\nexpires: ", text)
        status = self.lock("status")
        self.assertEqual(status.returncode, 1)
        self.assertIn("thread A", status.stdout)

    def test_another_owner_is_refused_and_told_the_holder(self):
        self.take("thread A")
        refused = self.take("thread B")
        self.assertEqual(refused.returncode, 1)
        self.assertIn("owner: thread A", refused.stderr)
        self.assertIn("owner: thread A", self.path.read_text())

    def test_the_owner_renews_its_own_lock(self):
        self.take("thread A", "5")
        renewed = self.take("thread A", "90")
        self.assertEqual(renewed.returncode, 0)
        self.assertIn("expires in 90 min", self.lock("status").stdout)

    def test_an_expired_lock_is_replaced(self):
        self.path.write_text("owner: thread A\ntask: x\nexpires: 2020-01-01T00:00:00+00:00\n")
        self.assertEqual(self.lock("status").returncode, 0)
        taken = self.take("thread B")
        self.assertEqual(taken.returncode, 0)
        self.assertIn("expired", taken.stderr)
        self.assertIn("owner: thread B", self.path.read_text())

    def test_a_handwritten_lock_holds_for_an_hour_after_its_last_change(self):
        # Locks that agents wrote by hand before this script have one free-text line and no expiry.
        self.path.write_text("#63 thread, 2026-11-01 18:59, fixture apps, about 30 min\n")
        self.assertEqual(self.take("thread B").returncode, 1)
        old = time.time() - 61 * 60
        os.utime(self.path, (old, old))
        self.assertEqual(self.take("thread B").returncode, 0)

    def test_only_the_owner_releases(self):
        self.take("thread A")
        self.assertEqual(self.lock("release", "--owner", "thread B").returncode, 1)
        self.assertTrue(self.path.exists())
        self.assertEqual(self.lock("release", "--owner", "thread A").returncode, 0)
        self.assertFalse(self.path.exists())

    def test_run_holds_the_lock_only_while_the_command_runs(self):
        command = f"test -f '{self.path}' && exit 7"
        result = self.lock("run", "--owner", "make e2e", "--minutes", "5", "--task", "selftests", "--",
                           "sh", "-c", command)
        self.assertEqual(result.returncode, 7)
        self.assertFalse(self.path.exists())

    def test_run_does_not_start_while_another_owner_holds_the_lock(self):
        self.take("thread A")
        marker = self.path.with_name("ran")
        result = self.lock("run", "--owner", "make e2e", "--minutes", "5", "--task", "selftests", "--",
                           "touch", str(marker))
        self.assertEqual(result.returncode, 1)
        self.assertFalse(marker.exists())
        self.assertIn("owner: thread A", self.path.read_text())

    def test_run_under_the_owners_own_lock_keeps_the_lock(self):
        self.take("thread A")
        result = self.lock("run", "--owner", "thread A", "--minutes", "5", "--task", "selftests", "--", "true")
        self.assertEqual(result.returncode, 0)
        self.assertIn("owner: thread A", self.path.read_text())


if __name__ == "__main__":
    unittest.main()
