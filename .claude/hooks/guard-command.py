#!/usr/bin/env python3
"""Claude Code PreToolUse hook that blocks irreversible or outward-facing shell commands.

It also blocks `gh issue create` unless the issue has one type label and every section its template requires.
It blocks a PR on a product change, from `gh pr create` or the T3 Code `pull_request_create` tool,
unless its body has before and after media or says "No visible change".
AGENTS.md explains the policy. Exit code 2 blocks the call and shows stderr to the agent.
"""
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

PROTECTED_BRANCHES = {"main"}
WRAPPERS = {"sudo", "env", "command", "exec", "nohup", "time", "nice"}
SEPARATORS = {";", "&&", "||", "|", "&", "(", ")", "|&", ";;"}
GIT_OPTIONS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
ISSUE_TEMPLATES = Path(__file__).resolve().parents[2] / ".github/ISSUE_TEMPLATE"
ISSUE_CREATE = re.compile(r"\bgh\s+issue\s+(create|new)\b")
PR_CREATE = re.compile(r"\bgh\s+pr\s+create\b")
# Claude Code names an MCP tool mcp__<server>__<tool>. .claude/settings.json matches the same name.
PR_CREATE_TOOL = "mcp__t3-code__pull_request_create"
LABEL_OPTION = re.compile(r"(?<!\S)(?:-l|--label)[ =]+(?:'([^']*)'|\"([^\"]*)\"|(\S+))")
BASE_OPTION = re.compile(r"(?<!\S)(?:-B|--base)[ =]+(?:'([^']*)'|\"([^\"]*)\"|(\S+))")
ISSUE_HELP = "See File an issue in CONTRIBUTING.md"
PR_MEDIA_PREFIXES = ("Sources/", "vendor/paneru", "assets/")
PR_MEDIA_LINK = re.compile(
    r"(https://github\.com/user-attachments/assets/\S+|!\[[^\]]*\]\([^)]+\)|<(?:img|video)\b)",
    re.I,
)
NO_VISIBLE_CHANGE = re.compile(r"\bno visible change\b", re.I)
PR_MEDIA_HELP = (
    "a PR touching Sources/, vendor/paneru, or assets/ needs before/after media "
    "(screenshot, GIF, or video) under '## Before and after', captured with "
    "verify-miri capture/record and uploaded with verify-miri upload "
    "(or 'No visible change' if nobody can see or feel the change). "
    "See docs/AI-CONTRIBUTIONS.md#capture-evidence"
)


def segments(command: str):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    current: list[str] = []
    for token in lexer:
        if token in SEPARATORS:
            if current:
                yield current
            current = []
        else:
            current.append(token)
    if current:
        yield current


def strip_wrappers(argv: list[str]) -> list[str]:
    while argv and (argv[0] in WRAPPERS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", argv[0])):
        argv = argv[1:]
        while argv and argv[0].startswith("-") and argv[0] != "--":
            argv = argv[1:]
    return argv


def current_branch(cwd: str) -> str:
    result = subprocess.run(["git", "-C", cwd, "symbolic-ref", "--quiet", "--short", "HEAD"],
                            capture_output=True, text=True)
    return result.stdout.strip()


def short_flags(args: list[str]) -> set[str]:
    return {c for a in args if re.match(r"^-[A-Za-z]+$", a) for c in a[1:]}


def check_git(args: list[str], cwd: str) -> str | None:
    while args and args[0].startswith("-"):
        option = args.pop(0)
        if option in GIT_OPTIONS_WITH_VALUE and args:
            value = args.pop(0)
            if option == "-C":
                cwd = os.path.join(cwd, value)
    if not args:
        return None
    sub, rest = args[0], args[1:]
    flags = short_flags(rest)
    if sub == "push":
        if "f" in flags or "--force" in rest or any(a.startswith("+") for a in rest):
            return "force push rewrites shared history; use --force-with-lease on your own branch"
        if "--no-verify" in rest:
            return "git push --no-verify skips the pre-push checks; fix what they report instead"
        for option in ("--mirror", "--tags", "--delete", "--prune"):
            if option in rest or (option == "--delete" and "d" in flags):
                return f"git push {option} changes remote refs beyond one branch"
        positional = [a for a in rest if not a.startswith("-")]
        refspecs = positional[1:]
        targets = [r.split(":")[-1].removeprefix("refs/heads/") for r in refspecs]
        if not refspecs or "HEAD" in targets:
            targets.append(current_branch(cwd))
        if any(t in PROTECTED_BRANCHES for t in targets):
            return "pushing to main skips pull request review; push a branch and open a PR"
        if any(re.match(r"^(refs/tags/)?v\d", r) for r in refspecs):
            return "pushing a version tag starts a release; releases need Sam"
    if sub == "reset" and "--hard" in rest:
        return "git reset --hard discards uncommitted work"
    if sub == "clean" and ("f" in flags or "--force" in rest):
        return "git clean -f deletes untracked files"
    if sub == "branch" and ("D" in flags or ("--delete" in rest and "--force" in rest)):
        return "git branch -D deletes unmerged commits"
    return None


def issue_types() -> dict[str, list[str]]:
    """Map each template's type label, the first entry of its `labels:` list, to its required field labels."""
    types = {}
    for template in sorted(ISSUE_TEMPLATES.glob("*.yml")):
        text = template.read_text(encoding="utf-8")
        type_label = re.search(r"^labels:\s*\[\s*([^,\]\s]+)", text, re.M)
        if not type_label:
            continue
        required = []
        for field in re.split(r"^\s*- type:", text, flags=re.M)[1:]:
            label = re.search(r"^\s*label:\s*(.+?)\s*$", field, re.M)
            if label and re.search(r"^\s*required:\s*true\s*$", field, re.M):
                required.append(label.group(1).strip("'\""))
        types[type_label.group(1).strip("'\"")] = required
    return types


def has_heading(body: str, section: str) -> bool:
    # A body passed in double quotes keeps "\n" as two characters, so accept it as a line break too.
    pattern = rf"(?:^|\\n)[ \t]*#{{1,6}}[ \t]*{re.escape(section)}[ \t]*(?:$|\\n)"
    return re.search(pattern, body, re.I | re.M) is not None


def check_issue(labels: list[str], body: str) -> str | None:
    types = issue_types()
    given = sorted({label for label in labels if label in types})
    if len(given) != 1:
        return (f"an issue needs exactly one type label, given with --label. "
                f"This command gives {', '.join(given) or 'none'}. "
                f"The type labels are {', '.join(types)}. {ISSUE_HELP}")
    missing = [section for section in types[given[0]] if not has_heading(body, section)]
    if missing:
        return (f"a {given[0]} issue needs each required template field as a Markdown heading, "
                f"such as '### {missing[0]}'. Missing: {', '.join(missing)}. {ISSUE_HELP}")
    return None


def check_issue_create(args: list[str], cwd: str, command: str) -> str | None:
    body, body_file, labels = None, None, []
    i = 0
    while i < len(args):
        name, has_value, value = args[i].partition("=")
        if name in {"-b", "--body", "-F", "--body-file", "-l", "--label"} and not has_value:
            if i + 1 >= len(args):
                break
            i += 1
            value = args[i]
        if name in {"-w", "--web"}:
            return None
        if name in {"-b", "--body"}:
            body = value
        elif name in {"-F", "--body-file"}:
            body_file = value
        elif name in {"-l", "--label"}:
            labels += [label.strip() for label in value.split(",")]
        i += 1
    if body is None and body_file:
        try:
            body = Path(cwd, body_file).read_text(encoding="utf-8") if body_file != "-" else command
        except OSError:
            # The file may be written earlier in the same command, or the body may come from stdin.
            body = command
    return check_issue(labels, body or "")


def pr_changed_files(cwd: str, base: str | None) -> list[str]:
    candidates = []
    if base:
        candidates += [f"origin/{base}", base]
    candidates += ["origin/main", "main"]
    for ref in candidates:
        probe = subprocess.run(["git", "-C", cwd, "rev-parse", "--verify", "--quiet", ref],
                               capture_output=True, text=True)
        if probe.returncode != 0:
            continue
        diff = subprocess.run(["git", "-C", cwd, "diff", "--name-only", f"{ref}...HEAD"],
                              capture_output=True, text=True)
        if diff.returncode == 0:
            return [line.strip() for line in diff.stdout.splitlines() if line.strip()]
    return []


def pr_needs_visual_evidence(cwd: str, base: str | None = None) -> bool:
    return any(
        path == "vendor/paneru" or path.startswith(PR_MEDIA_PREFIXES)
        for path in pr_changed_files(cwd, base)
    )


def extract_section(body: str, heading: str) -> str | None:
    normalized = body.replace("\\n", "\n")
    match = re.search(rf"^[ \t]*(#{{1,6}})[ \t]*{re.escape(heading)}[ \t]*$", normalized, re.I | re.M)
    if not match:
        return None
    level = len(match.group(1))
    rest = normalized[match.end():]
    next_heading = re.search(rf"^[ \t]*#{{1,{level}}}[ \t]+\S", rest, re.M)
    return rest[:next_heading.start()] if next_heading else rest


def check_pr_body(body: str) -> str | None:
    section = extract_section(body, "Before and after")
    if section is None:
        return PR_MEDIA_HELP
    # Ignore HTML comments copied from .github/PULL_REQUEST_TEMPLATE.md.
    cleaned = re.sub(r"<!--.*?-->", "", section, flags=re.S)
    if PR_MEDIA_LINK.search(cleaned) or NO_VISIBLE_CHANGE.search(cleaned):
        return None
    return PR_MEDIA_HELP


def check_pr_create(args: list[str], cwd: str, command: str) -> str | None:
    body, body_file, base = None, None, None
    i = 0
    while i < len(args):
        name, has_value, value = args[i].partition("=")
        if name in {"-b", "--body", "-F", "--body-file", "-B", "--base"} and not has_value:
            if i + 1 >= len(args):
                break
            i += 1
            value = args[i]
        if name in {"-w", "--web"}:
            return None
        if name in {"-b", "--body"}:
            body = value
        elif name in {"-F", "--body-file"}:
            body_file = value
        elif name in {"-B", "--base"}:
            base = value
        i += 1
    if not pr_needs_visual_evidence(cwd, base):
        return None
    if body is None and body_file:
        try:
            body = Path(cwd, body_file).read_text(encoding="utf-8") if body_file != "-" else command
        except OSError:
            body = command
    return check_pr_body(body or "")


def check_pr_create_tool(tool_input: dict, cwd: str) -> str | None:
    """Check a PR that a tool such as T3 Code `pull_request_create` opens without the gh CLI."""
    if not pr_needs_visual_evidence(cwd, tool_input.get("base")):
        return None
    return check_pr_body(tool_input.get("body") or "")


def check(argv: list[str], cwd: str, command: str) -> str | None:
    argv = strip_wrappers(argv)
    if not argv:
        return None
    program, args = os.path.basename(argv[0]), argv[1:]
    if program in {"bash", "sh", "zsh"} and "-c" in args and args.index("-c") + 1 < len(args):
        return check_command(args[args.index("-c") + 1], cwd)
    if program == "git":
        return check_git(list(args), cwd)
    if program == "gh" and len(args) >= 2:
        if args[0] == "issue" and args[1] in {"create", "new"}:
            return check_issue_create(args[2:], cwd, command)
        if args[:2] == ["pr", "create"]:
            return check_pr_create(args[2:], cwd, command)
        if args[:2] == ["pr", "merge"] and any(
            a == "--admin" or (a.startswith("--admin=") and a.split("=", 1)[1].lower() != "false")
            for a in args[2:]
        ):
            return "gh pr merge --admin bypasses branch protection and required checks"
        if args[0] == "release" and args[1] in {"create", "delete", "edit", "upload"}:
            return "publishing or changing a release needs Sam"
        if args[0] == "repo" and args[1] in {"delete", "edit", "archive", "rename"}:
            return "changing repository settings needs Sam"
    if program == "tccutil" and args[:1] == ["reset"]:
        return "Miri never resets privacy permissions; ask Sam to grant or revoke them"
    if program == "defaults" and args[:1] and args[0] in {"write", "delete", "rename", "import"}:
        return "Miri never changes macOS settings; ask Sam to change them in System Settings"
    return None


def check_command(command: str, cwd: str) -> str | None:
    try:
        parsed = list(segments(command))
    except ValueError:
        # An unquoted heredoc body with an apostrophe cannot be split, so check the text as written.
        if ISSUE_CREATE.search(command):
            labels = [label.strip() for match in LABEL_OPTION.finditer(command)
                      for label in "".join(match.groups(default="")).split(",")]
            return check_issue(labels, command)
        if PR_CREATE.search(command):
            base_match = BASE_OPTION.search(command)
            base = "".join(base_match.groups(default="")) if base_match else None
            if pr_needs_visual_evidence(cwd, base):
                return check_pr_body(command)
        return None
    for argv in parsed:
        reason = check(argv, cwd, command)
        if reason:
            return reason
    return None


def main() -> int:
    event = json.load(sys.stdin)
    tool_input = event.get("tool_input") or {}
    cwd = event.get("cwd") or os.getcwd()
    if event.get("tool_name") == PR_CREATE_TOOL:
        reason = check_pr_create_tool(tool_input, cwd)
    else:
        reason = check_command(tool_input.get("command", ""), cwd)
    if reason:
        print(f"Blocked by .claude/hooks/guard-command.py: {reason}.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
