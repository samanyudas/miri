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
With `--translations CATALOG` it exits 1 when a key lacks a translation in one of LANGUAGES, or when a translation's
placeholders differ from the English text's. A draft marked `needs_review` counts as a translation.
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
# The languages Miri ships, as string catalog codes. Sam chose them on 8 November 2026 (#350).
LANGUAGES = ("en", "zh-Hans", "zh-Hant", "es", "fr", "de", "ja", "ko", "pt-BR", "pt-PT", "it",
             "ru", "ar", "hi", "nl", "tr", "pl", "id", "vi", "th", "uk", "sv")
TRANSLATED = ("translated", "needs_review")


def scan(source: str) -> tuple[list[tuple[int, str]], dict[int, str]]:
    """Returns string literals as (line, text) and non-string, non-comment code per line."""
    found: list[tuple[int, str]] = []
    code: dict[int, list[str]] = {}
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
        elif c == "#" and i + 1 < n and source[i + 1] in '"#':
            # Raw strings such as #"..."# hold regular expressions and paths, not interface text.
            j = i
            while j < n and source[j] == "#":
                j += 1
            if j < n and source[j] == '"':
                close = '"' + "#" * (j - i)
                end = source.find(close, j + 1)
                end = n if end < 0 else end + len(close)
                line += source.count("\n", i, end)
                i = end
            else:
                code.setdefault(line, []).append(c)
                i += 1
        elif c == "/" and is_regex_start(source, i):
            # A regex literal such as /["']x/ can hold quotes that do not open a string.
            i = regex_end(source, i)
        elif c == '"':
            start_line = line
            text, nested, i, line = read_string(source, i, line, code)
            found.append((start_line, text))
            found.extend(nested)
        else:
            code.setdefault(line, []).append(c)
            i += 1
    return found, {number: "".join(chars) for number, chars in code.items()}


def literals(source: str):
    """Yields (line, text) for each string literal outside comments, with each interpolation as PLACEHOLDER."""
    yield from scan(source)[0]


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


def read_string(source: str, i: int, line: int,
                code: dict[int, list[str]]) -> tuple[str, list[tuple[int, str]], int, int]:
    """Reads the literal at `i`, returning its text, nested literals inside interpolations, next index, and end line."""
    multiline = source.startswith('"""', i)
    quote = '"""' if multiline else '"'
    i += len(quote)
    parts = []
    nested: list[tuple[int, str]] = []
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
                    nested_line = line
                    nested_text, inner, i, line = read_string(source, i, line, code)
                    nested.append((nested_line, nested_text))
                    nested.extend(inner)
                    continue
                if source.startswith("//", i):
                    while i < n and source[i] != "\n":
                        i += 1
                    continue
                if source.startswith("/*", i):
                    end = source.find("*/", i + 2)
                    end = n if end < 0 else end + 2
                    line += source.count("\n", i, end)
                    i = end
                    continue
                if source[i] == "\n":
                    line += 1
                else:
                    code.setdefault(line, []).append(source[i])
                depth += {"(": 1, ")": -1}.get(source[i], 0)
                i += 1
            parts.append(PLACEHOLDER)
        elif c == "\\" and i + 1 < n:
            parts.append(source[i:i + 2])
            i += 2
        else:
            parts.append(c)
            i += 1
    return squeeze("".join(parts)), nested, i + len(quote), line


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
            skipped = marked_lines(source.splitlines())
            found, code_lines = scan(source)
            for number, text in found:
                if (is_interface_text(text) and not SKIPPED_LINE.search(code_lines.get(number, ""))
                        and number not in skipped):
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


def placeholders(text: str) -> list[tuple[int, str]]:
    """The placeholders in catalog text as sorted (position, type) pairs, so `%@ %lld` equals `%2$lld %1$@`."""
    found = []
    for number, match in enumerate(CATALOG_PLACEHOLDER.finditer(text.replace("%%", "")), start=1):
        position = int(match.group(1)[:-1]) if match.group(1) else number
        found.append((position, (match.group(2) or "") + match.group(0)[-1]))
    return sorted(found)


def forms(localization: dict) -> dict[str, dict]:
    """The string units of one language: one for plain text, or one per plural form."""
    if "stringUnit" in localization:
        return {"": localization["stringUnit"]}
    plural = localization.get("variations", {}).get("plural", {})
    return {name: variation.get("stringUnit", {}) for name, variation in plural.items()}


def translation_problems(catalog: dict) -> list[str]:
    """Each missing or broken translation in the catalog, as `language: problem: key`."""
    problems = []
    for key, entry in sorted(catalog["strings"].items()):
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        english = forms(localizations["en"]) if "en" in localizations else {"": {"value": key}}
        expected = placeholders(english.get("", english.get("other", {})).get("value", key))
        for language in LANGUAGES[1:]:
            units = forms(localizations.get(language, {}))
            if not units:
                problems.append(f"{language}: missing: {key}")
                continue
            if "" not in units and "other" not in units:
                problems.append(f"{language}: plural form other missing: {key}")
            for name, unit in units.items():
                value = unit.get("value", "")
                if unit.get("state") not in TRANSLATED or not value.strip():
                    problems.append(f"{language}: missing: {key}")
                elif placeholders(value) != expected and not (
                        name in ("zero", "one", "two") and set(placeholders(value)) <= set(expected)):
                    problems.append(f"{language}: placeholders differ from the English text: {key}")
    extra = {language for entry in catalog["strings"].values() for language in entry.get("localizations", {})}
    problems += [f"{language}: not in LANGUAGES" for language in sorted(extra - set(LANGUAGES))]
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("root", nargs="?", default=Path(__file__).resolve().parents[1], type=Path)
    parser.add_argument("--check", metavar="STRINGSDATA", type=Path,
                        help="fail on a literal that the compiler did not localize, from this .stringsdata folder")
    parser.add_argument("--translations", metavar="CATALOG", type=Path,
                        help="fail on a key that lacks a translation in one of LANGUAGES, in this string catalog")
    arguments = parser.parse_args()
    if arguments.translations:
        problems = translation_problems(json.loads(arguments.translations.read_text(encoding="utf-8")))
        for problem in problems:
            print(problem)
        print(f"{len(problems)} translations missing or broken in {len(LANGUAGES)} languages", file=sys.stderr)
        return 1 if problems else 0
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
