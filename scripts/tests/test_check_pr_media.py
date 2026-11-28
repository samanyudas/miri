"""Tests for scripts/check-pr-media.py."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("check_pr_media", ROOT / "scripts/check-pr-media.py")
MOD = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MOD)


class CheckPRMediaTests(unittest.TestCase):
    def test_identifies_ui_paths(self):
        paths = [
            "Sources/Miri/WindowPicker.swift",
            "Sources/MiriCore/Shortcuts.swift",
            "assets/icon.png",
            "README.md",
        ]
        self.assertEqual(MOD.ui_paths(paths), ["Sources/Miri/WindowPicker.swift", "assets/icon.png"])

    def test_accepts_github_attachment_url_and_img_and_markdown_image(self):
        self.assertTrue(
            MOD.body_satisfies_media_rule(
                '<img width="480" alt="after" src="https://github.com/user-attachments/assets/abc-123" />'
            )
        )
        self.assertTrue(MOD.body_satisfies_media_rule("https://github.com/user-attachments/assets/abc-123"))
        self.assertTrue(MOD.body_satisfies_media_rule("![after](https://example.com/after.png)"))
        self.assertTrue(MOD.body_satisfies_media_rule("https://example.com/demo.mp4"))

    def test_accepts_explicit_no_visible_change(self):
        self.assertTrue(MOD.body_satisfies_media_rule("## Before and after\n\nNo visible change.\n"))

    def test_ignores_template_html_comments(self):
        template_only = (
            "## Before and after\n"
            "<!-- Write \"No visible change\" when nobody can see or feel the change. -->\n"
            "| Before | After |\n| --- | --- |\n|  |  |\n"
        )
        self.assertFalse(MOD.body_satisfies_media_rule(template_only))

    def test_rejects_plain_text_without_media(self):
        self.assertFalse(MOD.body_satisfies_media_rule("Updated the picker layout. Passed tests."))


if __name__ == "__main__":
    unittest.main()
