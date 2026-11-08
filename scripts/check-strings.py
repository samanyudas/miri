#!/usr/bin/env python3
"""List the string literals in the app's Swift sources that read like interface text, for localization (#350).

A literal counts as interface text when it holds a letter, is not a code word such as `window_focus_west` or a URL,
and its line is not a log, assertion, or test call. Comments are skipped.
The heuristic over-reports on purpose: a person sorts the list, and nothing here decides how strings get translated.

Without options the script prints each literal as `path:line: text` and a count per file, and exits 0.
With `--check` it exits 1 when a literal is not a key in a `.xcstrings` catalog under the scanned roots.
Interpolations such as `\\(count)` and catalog placeholders such as `%lld` or `%1$@` compare as equal.
`make lint` does not run `--check` yet, because `main` has no string catalog.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOTS = ("Sources/Miri", "Sources/MiriCore")
# Copy Diagnostics stays in English so maintainers can read reports (#350).
SKIPPED_FILES = {"Sources/MiriCore/Diagnostics.swift"}
SKIPPED_LINE = re.compile(r"\b(Logger|logger|log\.|print\(|NSLog|fatalError|precondition|assert|#expect|#require)")
CODE_WORD = re.compile(r"^[a-z0-9_.+\-/:]*$|^[A-Z]{1,3}[a-z]+[A-Z]\w*$")
ESCAPE = re.compile(r"\\(u\{[0-9A-Fa-f]+\}|.)")
NOT_TEXT = re.compile(r"://|^x-apple|^com\.apple|^io\.github|\.(svg|txt|toml|plist|log)$")
PLACEHOLDER = "\u0000"
CATALOG_PLACEHOLDER = re.compile(r"%(\d+\$)?(ll|l|h)?[@dDuUxXoOfFeEgGcCsSaAp]")


def literals(source: str):
    """Yields (line, text) for each string literal outside comments, with each interpolation as PLACEHOLDER."""
    i, line, n = 0, 1, len(source)
    while i < n:
        c = source[i]
        if c == "\n":
            line += 1
            i += 1
        elif source.startswith("//", i):
            while i < n and source[i] != "\n":
                i += 1
        elif source.startswith("/*", i):
            end = source.find("*/", i + 2)
            end = n if end < 0 else end + 2
            line += source.count("\n", i, end)
            i = end
        elif c == "#" and i + 1 < n and source[i + 1] in "\"#":
            # Raw strings such as #"..."# hold regular expressions and paths, not interface text.
            hashes = len(source[i:]) - len(source[i:].lstrip("#"))
            start = source.find('"', i)
            close = '"' + "#" * hashes
            end = source.find(close, start + 1)
            end = n if end < 0 else end + len(close)
            line += source.count("\n", i, end)
            i = end
        elif c == '"':
            start_line = line
            text, i, line = read_string(source, i, line)
            yield start_line, text
        else:
            i += 1


def read_string(source: str, i: int, line: int) -> tuple[str, int, int]:
    """Reads the literal that opens at `i` and returns its text, the index after it, and the line it ends on."""
    multiline = source.startswith('"""', i)
    quote = '"""' if multiline else '"'
    i += len(quote)
    parts = []
    n = len(source)
    while i < n and not source.startswith(quote, i):
        c = source[i]
        if c == "\n":
            line += 1
            parts.append(" ")
            i += 1
        elif c == "\\" and i + 1 < n and source[i + 1] == "(":
            depth, i = 1, i + 2
            while i < n and depth:
                if source[i] == '"':
                    _, i, line = read_string(source, i, line)
                    continue
                if source[i] == "\n":
                    line += 1
                depth += {"(": 1, ")": -1}.get(source[i], 0)
                i += 1
            parts.append(PLACEHOLDER)
        elif c == "\\" and i + 1 < n:
            parts.append(source[i:i + 2])
            i += 2
        else:
            parts.append(c)
            i += 1
    return squeeze("".join(parts)), i + len(quote), line


def squeeze(text: str) -> str:
    """Joins the lines of a multiline literal, so it compares with its catalog key whatever its indentation."""
    return " ".join(text.split())


def is_interface_text(text: str) -> bool:
    words = ESCAPE.sub(" ", text.replace(PLACEHOLDER, "")).strip()
    return bool(re.search(r"[A-Za-z]", words)) and not CODE_WORD.match(words) and not NOT_TEXT.search(words)


def candidates(root: Path):
    """Yields (relative path, line, text) for each literal that reads like interface text."""
    for folder in ROOTS:
        for path in sorted((root / folder).glob("**/*.swift")):
            relative = path.relative_to(root).as_posix()
            if relative in SKIPPED_FILES:
                continue
            source = path.read_text(encoding="utf-8")
            lines = source.splitlines()
            for number, text in literals(source):
                if is_interface_text(text) and not SKIPPED_LINE.search(lines[number - 1]):
                    yield relative, number, text


def catalog_keys(root: Path) -> set[str]:
    keys = set()
    for folder in ROOTS:
        for catalog in (root / folder).glob("**/*.xcstrings"):
            strings = json.loads(catalog.read_text(encoding="utf-8")).get("strings", {})
            keys.update(squeeze(CATALOG_PLACEHOLDER.sub(PLACEHOLDER, key)) for key in strings)
    return keys


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("root", nargs="?", default=Path(__file__).resolve().parents[1], type=Path)
    parser.add_argument("--check", action="store_true", help="fail on a literal that no string catalog holds")
    arguments = parser.parse_args()
    keys = catalog_keys(arguments.root) if arguments.check else set()
    found = [item for item in candidates(arguments.root) if not arguments.check or item[2] not in keys]
    counts: dict[str, int] = {}
    for path, number, text in found:
        print(f"{path}:{number}: {text.replace(PLACEHOLDER, '%@')}")
        counts[path] = counts.get(path, 0) + 1
    label = "not in a string catalog" if arguments.check else "that read like interface text"
    print(f"{len(found)} literals {label}", file=sys.stderr)
    for path, count in sorted(counts.items(), key=lambda item: -item[1]):
        print(f"  {count:4} {path}", file=sys.stderr)
    return 1 if arguments.check and found else 0


if __name__ == "__main__":
    sys.exit(main())
