#!/usr/bin/env python3
"""Check tracked documentation for broken relative links, banned characters, and map size."""
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

AGENTS_MAX_LINES = 120
BANNED = {chr(0x2014): "em dash; use a plain dash"}
SKIPPED_PREFIXES = ("vendor/",)
SKIPPED_FILES = {"LICENSE"}
TEXT_SUFFIXES = {".md", ".yml", ".yaml", ".toml", ".json", ".sh", ".py", ".swift", ".txt", ""}
PROGRESS_HEADINGS = ["Objective", "Done", "Next", "Blockers", "Last verification"]

FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`]*`")
MD_LINK = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
HTML_REF = re.compile(r"""(?:src|href)=["']([^"']+)["']""")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def slug(heading: str) -> str:
    text = re.sub(r"[`*_]|<[^>]+>", "", heading).strip().lower()
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    return re.sub(r"[^\w\- ]", "", text).replace(" ", "-")


def anchors(path: Path) -> set[str]:
    seen: dict[str, int] = {}
    result = set()
    in_fence = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        match = None if in_fence else HEADING.match(line)
        if match:
            base = slug(match.group(2))
            count = seen.get(base, 0)
            seen[base] = count + 1
            result.add(base if count == 0 else f"{base}-{count}")
    return result


def link_targets(text: str):
    in_fence = False
    for number, line in enumerate(text.splitlines(), 1):
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        line = INLINE_CODE.sub("", line)
        for match in [*MD_LINK.finditer(line), *HTML_REF.finditer(line)]:
            yield number, match.group(1)


def check_links(root: Path, relative: str, text: str) -> list[str]:
    problems = []
    source = root / relative
    for number, target in link_targets(text):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I) or target.startswith("//"):
            continue
        path_part, _, fragment = target.partition("#")
        resolved = (source.parent / unquote(path_part)).resolve() if path_part else source
        where = f"{relative}:{number}"
        if root.resolve() not in [resolved, *resolved.parents]:
            problems.append(f"{where}: link leaves the repository: {target}")
        elif not resolved.exists():
            problems.append(f"{where}: missing link target: {target}")
        elif fragment and resolved.suffix == ".md" and unquote(fragment) not in anchors(resolved):
            problems.append(f"{where}: missing heading anchor: {target}")
    return problems


def check_progress(root: Path) -> list[str]:
    path = root / "PROGRESS.md"
    if not path.exists():
        return ["PROGRESS.md: missing handoff record"]
    text = path.read_text(encoding="utf-8")
    problems = [f"PROGRESS.md: missing '## {name}' section" for name in PROGRESS_HEADINGS
                if not re.search(rf"^## {re.escape(name)}\s*$", text, re.M)]
    if not re.search(r"^Updated: \d{4}-\d{2}-\d{2}\b", text, re.M):
        problems.append("PROGRESS.md: missing 'Updated: YYYY-MM-DD' line")
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    files = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], check=True,
                           capture_output=True, text=True).stdout.split("\0")
    problems = []
    for relative in filter(None, files):
        path = root / relative
        if (relative.startswith(SKIPPED_PREFIXES) or relative in SKIPPED_FILES
                or path.suffix not in TEXT_SUFFIXES or not path.is_file()):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            for character, reason in BANNED.items():
                if character in line:
                    problems.append(f"{relative}:{number}: {reason}")
        if path.suffix == ".md":
            problems += check_links(root, relative, text)
    agents = root / "AGENTS.md"
    if not agents.exists():
        problems.append("AGENTS.md: missing agent map")
    elif len(agents.read_text(encoding="utf-8").splitlines()) > AGENTS_MAX_LINES:
        problems.append(f"AGENTS.md: longer than {AGENTS_MAX_LINES} lines; move detail into docs/")
    problems += check_progress(root)
    for problem in problems:
        print(problem)
    print(f"check-docs: {len(problems)} problem(s)", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
