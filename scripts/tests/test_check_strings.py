import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "check-strings.py"

VIEW = '''import SwiftUI
// Text("A comment is not interface text")
/* Button("Nor is a block comment") */
struct V: View {
    var body: some View {
        Text("Start Window Management")
        Button("Use \\(label)") {}
        Text("Running · \\(count) \\(count == 1 ? "display" : "displays")")
        Text(#"^\\w+ raw$"#)
        logger.info("Engine started at \\(path)")
        let key = "window_focus_west"
        let url = "https://github.com/samanyudas/miri"
        let plist = "CFBundleShortVersionString"
        let newline = "\\n"
        Text("""
            Two lines
            of text
            """)
    }
}
'''


class CheckStringsTest(unittest.TestCase):
    def run_checker(self, files: dict[str, str], *options: str) -> tuple[int, list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, text in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text, encoding="utf-8")
            result = subprocess.run([sys.executable, str(CHECKER), str(root), *options],
                                    capture_output=True, text=True)
            return result.returncode, result.stdout.splitlines()

    def test_lists_interface_text_and_skips_comments_logs_and_code_words(self):
        code, lines = self.run_checker({"Sources/Miri/V.swift": VIEW})
        self.assertEqual(code, 0)
        self.assertEqual(lines, [
            "Sources/Miri/V.swift:6: Start Window Management",
            "Sources/Miri/V.swift:7: Use %@",
            "Sources/Miri/V.swift:8: Running · %@ %@",
            "Sources/Miri/V.swift:15: Two lines of text",
        ])

    def test_scans_only_the_app_folders(self):
        code, lines = self.run_checker({
            "Sources/AXFixture/F.swift": 'let b = "Fixture window"\n',
            "Sources/MiriCore/Checks.swift": 'let c = "Stage Manager"\n',
        })
        self.assertEqual((code, lines), (0, ["Sources/MiriCore/Checks.swift:1: Stage Manager"]))

    def stringsdata(self, root: Path, source: str, entries: list[tuple[int, str]]) -> None:
        folder = root / "stringsdata"
        folder.mkdir(exist_ok=True)
        data = {"source": str(root / source), "tables": {"Localizable": [
            {"key": key, "comment": "", "location": {"startingLine": line, "startingColumn": 1}} for line, key in entries]}}
        (folder / (Path(source).stem + ".stringsdata")).write_text(json.dumps(data), encoding="utf-8")

    def run_check(self, files: dict[str, str], localized: dict[str, list[tuple[int, str]]]) -> tuple[int, list[str]]:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, text in files.items():
                (root / name).parent.mkdir(parents=True, exist_ok=True)
                (root / name).write_text(text, encoding="utf-8")
            for source, entries in localized.items():
                self.stringsdata(root, source, entries)
            result = subprocess.run([sys.executable, str(CHECKER), str(root), "--check", str(root / "stringsdata")],
                                    capture_output=True, text=True)
            return result.returncode, result.stdout.splitlines()

    def test_check_fails_on_text_that_the_compiler_did_not_localize(self):
        code, lines = self.run_check({"Sources/Miri/V.swift": VIEW}, {"Sources/Miri/V.swift": [
            (6, "Start Window Management"), (7, "Use %@"), (8, "Running · %lld %@")]})
        self.assertEqual((code, lines), (1, ["Sources/Miri/V.swift:15: Two lines of text"]))

    def test_check_fails_on_a_catalog_key_passed_where_nothing_localizes_it(self):
        # Line 1 localizes the text, but line 2 passes the same words to a String parameter.
        source = 'Text("Stop Window Management")\nsidebarButton("Stop Window Management")\n'
        code, lines = self.run_check({"Sources/Miri/S.swift": source},
                                     {"Sources/Miri/S.swift": [(1, "Stop Window Management")]})
        self.assertEqual((code, lines), (1, ["Sources/Miri/S.swift:2: Stop Window Management"]))

    def test_check_matches_escaped_quotes_with_their_characters(self):
        code, lines = self.run_check(
            {"Sources/MiriCore/Q.swift": 'let q = String(localized: "Name \\u{201C}\\(x)\\u{201D} is \\"off\\".")\n'},
            {"Sources/MiriCore/Q.swift": [(1, 'Name \u201c%@\u201d is "off".')]})
        self.assertEqual((code, lines), (0, []))

    def test_skips_regex_literals_markers_and_environment_names(self):
        code, lines = self.run_checker({"Sources/MiriCore/R.swift": """let a = text.replacing(/["']x/, with: "<path>")
let b = "PANERU_CONFIG"
let c = "Engine/state"
let g = "Contents/Helpers/miri-engine"
let h = "managementStopped"
let d = "Header for a file"  // Not interface text
// Not interface text
let e = "Another file line"
let f = "Shown to people"
// Not interface text: app names
let apps = [
    ("Rectangle", ["com.knollsoft.Rectangle"]),
    ("Magnet", []),
]
let g = "Also shown"
"""})
        self.assertEqual((code, lines), (0, ["Sources/MiriCore/R.swift:9: Shown to people",
                                             "Sources/MiriCore/R.swift:15: Also shown"]))


if __name__ == "__main__":
    unittest.main()
