#!/usr/bin/env python3
"""List the string literals in the app's Swift sources that read like interface text, for localization (#350).

A literal counts as interface text when it holds a letter, is not a code word such as `window_focus_west`,
`PANERU_CONFIG`, a path, or a URL, and its line is not a log, assertion, or test call. Comments are skipped.
A literal that reads like text but is not shown to people, such as a file header, carries a
`// Not interface text` comment on its line or the line above. Above a line that opens a list, it covers the list.

Without options the script prints each literal as `path:line: text` and a count per file, and exits 0.
With `--check DIR` it exits 1 when a literal is not localized where it stands. DIR holds the `.stringsdata` files that
the Swift compiler writes with `-emit-localized-strings`: one entry for each string that SwiftUI or `String(localized:)`
looks up, with its line. A literal that only matches a catalog key elsewhere, such as text passed to a `String`
parameter, is not localized. `scripts/sync-strings.sh --check` builds the files and runs this check.
Interpolations such as `\\(count)`, Swift escapes, and placeholders such as `%lld` or `%1$@` compare as equal.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOTS = ("Sources/Miri", "Sources/MiriCore")
NOT_INTERFACE = "// Not interface text"
SKIPPED_LINE = re.compile(r"\b(Logger|logger|log\.|print\(|NSLog|fatalError|precondition|assert|#expect|#require)")
CODE_WORD = re.compile(r"^[a-z0-9_.+\-/:]*$|^[A-Z]{1,3}[a-z]+[A-Z]\w*$|^[a-z]+[A-Z][A-Za-z]*$|^[A-Z0-9_]+$|^[\w-]+(/[\w-]+)+$|^<[a-z]+>$")
ESCAPE = re.compile(r"\\(u\{[0-9A-Fa-f]+\}|.)")
NOT_TEXT = re.compile(r"^\(\?|://|^x-apple|^com\.apple|^io\.github|\.(svg|txt|toml|plist|log)$")
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
        elif c == "/" and is_regex_start(source, i):
            # A regex literal such as /["']x/ can hold quotes that do not open a string.
            i = regex_end(source, i)
        elif c == '"':
            start_line = line
            text, i, line = read_string(source, i, line)
            yield start_line, text
        else:
            i += 1


def is_regex_start(source: str, i: int) -> bool:
    """Whether the slash at `i` opens a regex literal: it follows an opening bracket, a comma, or `=`."""
    before = source[:i].rstrip(" ")
    after = source[i + 1:i + 2]
    return bool(before) and before[-1] in "(,=[" and after not in ("", " ", "/", "*", "\n")


def regex_end(source: str, i: int) -> int:
    """Returns the index after the regex literal that opens at `i`, or the end of its line."""
    j = i + 1
    while j < len(source) and source[j] != "\n":
        if source[j] == "\\":
            j += 2
            continue
        if source[j] == "/":
            return j + 1
        j += 1
    return j


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


def decode(text: str) -> str:
    """Turns Swift escapes such as \\" and \\u{201C} into their characters, as the catalog key holds them."""
    simple = {"n": "\n", "t": "\t", "r": "\r", "0": "\0", '"': '"', "'": "'", "\\": "\\"}

    def character(match: re.Match) -> str:
        body = match.group(1)
        return chr(int(body[2:-1], 16)) if body.startswith("u{") else simple.get(body, body)

    return squeeze(ESCAPE.sub(character, text))


def is_interface_text(text: str) -> bool:
    words = ESCAPE.sub(" ", text.replace(PLACEHOLDER, "")).strip()
    return bool(re.search(r"[A-Za-z]", words)) and not CODE_WORD.match(words) and not NOT_TEXT.search(words)


def marked_lines(lines: list[str]) -> set[int]:
    """The line numbers that a `// Not interface text` comment covers: its own line and the next one.
    When that next line opens a bracket that it does not close, such as a list of app names, the whole list is covered."""
    covered = set()
    for index, line in enumerate(lines):
        if NOT_INTERFACE not in line:
            continue
        number = index + 1
        covered.update({number, number + 1})
        depth = 0
        for following in range(index + 1, len(lines)):
            code = lines[following].split("//")[0]
            depth += code.count("[") + code.count("(") - code.count("]") - code.count(")")
            covered.add(following + 1)
            if depth <= 0:
                break
    return covered


def candidates(root: Path):
    """Yields (relative path, line, text) for each literal that reads like interface text."""
    for folder in ROOTS:
        for path in sorted((root / folder).glob("**/*.swift")):
            relative = path.relative_to(root).as_posix()
            source = path.read_text(encoding="utf-8")
            lines = source.splitlines()
            skipped = marked_lines(lines)
            for number, text in literals(source):
                if is_interface_text(text) and not SKIPPED_LINE.search(lines[number - 1]) and number not in skipped:
                    yield relative, number, text


def localized_lines(folder: Path, root: Path) -> set[tuple[str, int, str]]:
    """Reads (relative path, line, key) for each string the compiler extracted, from the .stringsdata files in `folder`."""
    found = set()
    for path in folder.glob("*.stringsdata"):
        data = json.loads(path.read_text(encoding="utf-8"))
        source = Path(data["source"]).resolve()
        if not source.is_relative_to(root.resolve()):
            continue
        relative = source.relative_to(root.resolve()).as_posix()
        for entries in data.get("tables", {}).values():
            for entry in entries:
                key = squeeze(CATALOG_PLACEHOLDER.sub(PLACEHOLDER, entry["key"]))
                found.add((relative, entry["location"]["startingLine"], key))
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("root", nargs="?", default=Path(__file__).resolve().parents[1], type=Path)
    parser.add_argument("--check", metavar="STRINGSDATA", type=Path,
                        help="fail on a literal that the compiler did not localize, from this .stringsdata folder")
    arguments = parser.parse_args()
    localized = localized_lines(arguments.check, arguments.root) if arguments.check else set()
    found = [(path, line, text) for path, line, text in candidates(arguments.root)
             if not arguments.check or (path, line, decode(text)) not in localized]
    counts: dict[str, int] = {}
    for path, number, text in found:
        print(f"{path}:{number}: {text.replace(PLACEHOLDER, '%@')}")
        counts[path] = counts.get(path, 0) + 1
    label = "not localized where they stand" if arguments.check else "that read like interface text"
    print(f"{len(found)} literals {label}", file=sys.stderr)
    for path, count in sorted(counts.items(), key=lambda item: -item[1]):
        print(f"  {count:4} {path}", file=sys.stderr)
    return 1 if arguments.check and found else 0


if __name__ == "__main__":
    sys.exit(main())
