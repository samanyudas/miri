import importlib.util
import re
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "verify-engine-lifecycle.py"
spec = importlib.util.spec_from_file_location("verify_engine_lifecycle", SCRIPT)
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class VerifyEngineLifecycleTest(unittest.TestCase):
    """Checks that the script, the skill, and the TLA+ spec agree. These tests need no Java."""

    def test_every_rule_and_mutant_the_script_checks_is_in_the_spec(self):
        spec_text = verify.SPEC.read_text(encoding="utf-8")
        for rule in verify.INVARIANTS + verify.PROPERTIES:
            self.assertRegex(spec_text, rf"(?m)^{rule} ==", rule)
        for mutant in verify.MUTANTS:
            self.assertIn(f'"{mutant}"', spec_text.split("Mutants ==", 1)[1].split("\n", 1)[0])
        self.assertLessEqual(verify.KNOWN_FINDINGS, set(verify.INVARIANTS + verify.PROPERTIES))

    def test_the_combined_config_lists_every_rule(self):
        config = (verify.MODEL / "EngineLifecycle.cfg").read_text(encoding="utf-8")
        listed = set(re.findall(r"(?m)^(?:INVARIANT|PROPERTY) (\w+)$", config))
        self.assertEqual(listed, set(verify.INVARIANTS + verify.PROPERTIES))

    def test_the_skill_names_a_sync_commit_and_the_engine_supervisor(self):
        sync, files = verify.coverage()
        self.assertRegex(sync, r"^[0-9a-f]{7,40}$")
        self.assertIn("Sources/MiriCore/Engine.swift", files)

    def test_every_file_with_a_start_stop_or_restart_control_is_covered(self):
        _, files = verify.coverage()
        callers = {
            str(path.relative_to(verify.ROOT))
            for path in (verify.ROOT / "Sources").rglob("*.swift")
            if re.search(r"\bmodel\.(start|stop|restart|stopFromShortcut)\(\)", path.read_text(encoding="utf-8"))
        }
        self.assertTrue(callers, "found no lifecycle controls, so the pattern no longer matches the code")
        self.assertLessEqual(callers, set(files), "model these controls in EngineLifecycle.tla, then cover their files")

    def test_a_trace_prints_one_line_for_each_step(self):
        output = """Error: Invariant StopStands is violated.
State 1: <Initial predicate>
s = [ app |-> "launching",
  engine |-> "stopped",
  completions |-> <<>>,
  alive |-> {} ]

State 2: <YouPressStop line 1, col 1 to line 1, col 2 of module EngineLifecycle>
s = [ app |-> "open",
  engine |-> "running",
  completions |-> <<"none", "start">>,
  alive |-> {1, 2} ]
"""
        self.assertEqual(
            verify.trace(output),
            [
                '1. Initial: app="launching", engine="stopped", alive={}, completions=<<>>',
                '2. YouPressStop: app="open", engine="running", alive={1, 2}, completions=<<"none", "start">>',
            ],
        )


if __name__ == "__main__":
    unittest.main()
