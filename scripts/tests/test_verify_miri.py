"""Checks the verify-miri skill helper without a Mac desktop, so `make lint` catches drift on any machine."""
import importlib.machinery
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".claude/skills/verify-miri/scripts/verify-miri"


def load():
    loader = importlib.machinery.SourceFileLoader("verify_miri", str(SCRIPT))
    spec = importlib.util.spec_from_loader("verify_miri", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class VerifyMiriTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.vm = load()

    def test_arrow_chords_carry_side_bits_and_arrow_flags(self):
        code, flags = self.vm.parse_chord("ctrl+alt-leftarrow")
        self.assertEqual(code, 123)
        # Control and Option group masks, left-side bits 0x1 and 0x20, numeric-pad and Fn flags.
        self.assertEqual(flags, 0x40000 | 0x1 | 0x80000 | 0x20 | 0x200000 | 0x800000)

    def test_letter_chords_have_no_arrow_flags(self):
        self.assertEqual(self.vm.parse_chord("ctrl+alt+shift-h"), (4, 0x40000 | 0x1 | 0x80000 | 0x20 | 0x20000 | 0x2))

    def test_unknown_keys_and_modifiers_fail(self):
        with self.assertRaises(self.vm.Failure):
            self.vm.parse_chord("ctrl+alt-f13")
        with self.assertRaises(self.vm.Failure):
            self.vm.parse_chord("hyper-h")

    def test_every_default_shortcut_key_is_known(self):
        source = (ROOT / "Sources/MiriCore/Bindings.swift").read_text()
        found = set(re.findall(r'ctrlAlt\("([^"]+)"', source))
        # `ctrlAlt("\($0)")` binds the digits 1 to 9.
        keys = {key for key in found if not key.startswith("\\")} | (set("123456789") if r"\($0)" in found else set())
        self.assertTrue(keys, "found no default chords in Bindings.swift")
        self.assertEqual(keys - set(self.vm.KEYS), set())

    def test_process_patterns_match_executables_not_shell_lines(self):
        app = "/private/tmp/stack/apps/main/Miri Developer.app/Contents/MacOS/Miri"
        engine = "/tmp/stack/apps/main/Miri Developer.app/Contents/Helpers/miri-engine launch"
        self.assertEqual(self.vm.normal(self.vm.APP_PATTERN.match(app).group(1)), "/tmp/stack/apps/main/Miri Developer.app")
        self.assertEqual(self.vm.ENGINE_PATTERN.match(engine).group(1), "/tmp/stack/apps/main/Miri Developer.app")
        self.assertIsNone(self.vm.APP_PATTERN.match(f"/bin/zsh -c pgrep -f '{app}'"))
        self.assertIsNone(self.vm.ENGINE_PATTERN.match(engine.replace(" launch", " query state")))

    def test_evidence_lives_outside_the_repository(self):
        self.assertNotIn(str(ROOT), str(self.vm.HOME))

    def test_runs_on_the_macos_system_python(self):
        # T3 Code agent shells start with only the system paths on PATH, and macOS ships Python 3.9 there.
        system = "/usr/bin/python3"
        version = subprocess.run([system, "-c", "import sys; print(sys.version_info < (3, 10))"],
                                 capture_output=True, text=True) if Path(system).exists() else None
        if not version or version.stdout.strip() != "True":
            self.skipTest(f"{system} is missing or is Python 3.10 or later")
        with tempfile.TemporaryDirectory() as home:
            env = {"PATH": "/usr/bin:/bin", "HOME": os.environ["HOME"], "MIRI_LIVE_LOCK": str(Path(home, "lock"))}
            usage = subprocess.run([system, str(SCRIPT), "--help"], capture_output=True, text=True, env=env)
            self.assertEqual(usage.returncode, 0, usage.stderr)
            self.assertIn("doctor", usage.stdout)
            lock = subprocess.run([system, str(ROOT / "scripts/live-lock.py"), "status"], capture_output=True,
                                  text=True, env=env)
            self.assertEqual(lock.returncode, 0, lock.stderr)
            self.assertIn("free", lock.stdout)

    def test_end_refuses_a_run_that_another_thread_owns(self):
        with tempfile.TemporaryDirectory() as home:
            current = Path(home, "current.json")
            current.write_text(json.dumps({"id": "r1", "dir": str(Path(home, "runs/r1")), "owner": "thread A"}))
            result = subprocess.run([sys.executable, str(SCRIPT), "end", "--owner", "thread B"], capture_output=True,
                                    text=True, env={**os.environ, "MIRI_VERIFY_HOME": home})
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("thread A", result.stderr)
            self.assertTrue(current.exists(), "the other thread's run record must stay")


if __name__ == "__main__":
    unittest.main()
