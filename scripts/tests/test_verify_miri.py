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

    @staticmethod
    def state(*strips):
        """A `query state` reply. Each strip is (Space, row, [(window ID, display, floating), ...]) in column order."""
        return {"virtual_workspaces": [
            {"native_workspace_id": space, "number": row, "windows": [
                {"window_id": wid, "app_name": f"App{wid}", "title": "private", "display_id": display, "floating": floating}
                for wid, display, floating in windows]}
            for space, row, windows in strips]}

    def test_layout_records_strips_by_window_id_without_titles(self):
        layout = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, None, False), (12, 1, True)])))
        self.assertEqual(layout, [
            {"window_id": 10, "app": "App10", "space": 6, "row": 1, "display": 1, "position": 0},
            {"window_id": 11, "app": "App11", "space": 6, "row": 1, "display": 1, "position": 1},
            {"window_id": 12, "app": "App12", "space": 6, "row": 1, "display": 1, "position": None},
        ])
        self.assertNotIn("private", json.dumps(layout))

    def test_an_unchanged_layout_has_no_differences(self):
        before = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, 1, False)]), (3773, 1, [(20, 3, False)])))
        self.assertEqual(self.vm.layout_differences(before, before), [])

    def test_a_floating_window_keeps_each_native_space_membership(self):
        first = (6, 1, [(10, 1, True)])
        second = (7, 1, [(10, 1, True)])
        before = self.vm.layout(self.state(first, second))
        for strips in [(first, second), (second, first)]:
            with self.subTest(strips=strips):
                after = self.vm.layout(self.state(*strips))
                self.assertEqual(self.vm.layout_differences(before, after), [])

    def test_losing_one_native_space_membership_is_reported(self):
        before = self.vm.layout(self.state((6, 1, [(10, 1, True)]), (7, 1, [(10, 1, True)])))
        after = self.vm.layout(self.state((7, 1, [(10, 1, True)])))
        differences = self.vm.layout_differences(before, after)
        self.assertEqual(len(differences), 1, differences)
        self.assertIn("Space 6 row 1 on display 1", differences[0])
        self.assertIn("Space 7 row 1 on display 1", differences[0])

    def test_a_window_on_another_display_is_reported(self):
        before = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, 1, False)]), (3773, 1, [(20, 3, False)])))
        after = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, 1, False), (20, 1, False)]), (3773, 1, [])))
        differences = self.vm.layout_differences(before, after)
        self.assertEqual(len(differences), 1, differences)
        self.assertIn("App20 window 20", differences[0])
        self.assertIn("Space 3773 row 1 on display 3", differences[0])
        self.assertIn("Space 6 row 1 on display 1", differences[0])

    def test_a_window_in_another_row_or_position_is_reported(self):
        before = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, 1, False), (12, 1, False)])))
        after = self.vm.layout(self.state((6, 1, [(11, 1, False), (10, 1, False)]), (6, 2, [(12, 1, False)])))
        differences = self.vm.layout_differences(before, after)
        self.assertEqual(len(differences), 3, differences)
        self.assertTrue(any("window 12" in line and "row 2" in line for line in differences), differences)
        self.assertTrue(any("window 10" in line and "position 1 of 2" in line for line in differences), differences)
        self.assertTrue(any("window 11" in line and "position 2 of 2" in line for line in differences), differences)

    def test_closed_and_new_windows_do_not_shift_the_others(self):
        before = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, 1, False), (12, 1, False)])))
        after = self.vm.layout(self.state((6, 1, [(99, 1, False), (11, 1, False), (12, 1, False)])))
        self.assertEqual(self.vm.layout_differences(before, after), [])

    def test_a_window_that_floats_now_is_reported(self):
        before = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, 1, False)])))
        after = self.vm.layout(self.state((6, 1, [(10, 1, False), (11, 1, True)])))
        differences = self.vm.layout_differences(before, after)
        self.assertEqual(len(differences), 1, differences)
        self.assertIn("window 11 was tiled, now floating", differences[0])

    def test_end_refuses_a_run_that_another_thread_owns(self):
        with tempfile.TemporaryDirectory() as home:
            current = Path(home, "current.json")
            current.write_text(json.dumps({"id": "r1", "dir": str(Path(home, "runs/r1")), "owner": "thread A"}))
            result = subprocess.run([sys.executable, str(SCRIPT), "end", "--owner", "thread B"], capture_output=True,
                                    text=True, env={**os.environ, "MIRI_VERIFY_HOME": home})
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertIn("thread A", result.stderr)
            self.assertTrue(current.exists(), "the other thread's run record must stay")

    def keep(self, apps, test_alive=True):
        vm = self.vm
        calls, logs = [], []
        saved = {n: getattr(vm, n) for n in ("alive", "command_of", "running_apps", "lock", "log", "CURRENT")}
        app = "/Applications/Miri Developer.app/Contents/MacOS/Miri"
        with tempfile.TemporaryDirectory() as home:
            current = Path(home, "current.json")
            current.write_text("{}")
            vm.alive = lambda pid: test_alive
            vm.command_of = lambda pid: app
            vm.running_apps = lambda: apps
            vm.lock = lambda *a: calls.append(a) or subprocess.CompletedProcess(a, 0, "released", "")
            vm.log = lambda run, line: logs.append(line)
            vm.CURRENT = current
            try:
                run = {"owner": "t", "dir": home, "test_app": "/x/Miri Developer.app", "previous_app": "/y"}
                code = vm.keep_test_build(run, 42)
                return code, calls, logs, current.exists()
            finally:
                for n, v in saved.items():
                    setattr(vm, n, v)

    def test_keep_test_build_leaves_it_running_and_releases_the_lock(self):
        code, calls, logs, current = self.keep([{"pid": 42, "bundle": "/x/Miri Developer.app"}])
        self.assertEqual(code, 0, logs)
        self.assertEqual(calls, [("release", "--owner", "t")])
        self.assertFalse(current)
        self.assertTrue(any("kept the test build" in line for line in logs), logs)

    def test_keep_test_build_refuses_when_the_test_build_stopped(self):
        code, calls, logs, current = self.keep([], test_alive=False)
        self.assertEqual(code, 1)
        self.assertEqual(calls, [])
        self.assertTrue(current, "the lock and run record must stay")

    def test_keep_test_build_refuses_when_another_build_runs(self):
        code, calls, _, current = self.keep([{"pid": 42, "bundle": "/x"}, {"pid": 7, "bundle": "/y"}])
        self.assertEqual(code, 1)
        self.assertEqual(calls, [])
        self.assertTrue(current)


if __name__ == "__main__":
    unittest.main()
