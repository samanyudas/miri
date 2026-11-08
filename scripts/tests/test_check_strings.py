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

    def test_check_fails_on_text_that_no_catalog_holds(self):
        catalog = {"sourceLanguage": "en", "version": "1.0",
                   "strings": {"Start Window Management": {}, "Use %@": {}, "Running · %1$lld %2$@": {}}}
        code, lines = self.run_checker({
            "Sources/Miri/V.swift": VIEW,
            "Sources/Miri/Localizable.xcstrings": json.dumps(catalog),
        }, "--check")
        self.assertEqual((code, lines), (1, ["Sources/Miri/V.swift:15: Two lines of text"]))

    def test_check_passes_when_every_text_is_in_a_catalog(self):
        catalog = {"strings": {"Stage Manager": {}}}
        code, lines = self.run_checker({
            "Sources/MiriCore/Checks.swift": 'let c = "Stage Manager"\n',
            "Sources/MiriCore/Resources/Localizable.xcstrings": json.dumps(catalog),
        }, "--check")
        self.assertEqual((code, lines), (0, []))


if __name__ == "__main__":
    unittest.main()
