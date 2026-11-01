#!/usr/bin/env python3
"""Claude Code PreToolUse hook that blocks irreversible or outward-facing shell commands.

It also blocks `gh issue create` when the body lacks the sections that CONTRIBUTING.md requires.
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
ISSUE_CREATE = re.compile(r"\bgh\s+issue\s+(create|new)\b")
ACCEPTANCE = re.compile(r"(^|\\n)#{1,6} *Acceptance criteria\b", re.I | re.M)
REPRODUCE = re.compile(r"(^|\\n)#{1,6} *Steps to reproduce\b", re.I | re.M)
BUG_LABEL = re.compile(r"(-l|--label)[ =]['\"]?[^'\"\s]*\bbug\b")
ISSUE_HELP = "see File an issue in CONTRIBUTING.md"


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


def check_issue_body(body: str, bug: bool) -> str | None:
    if not ACCEPTANCE.search(body):
        return f"an issue needs an '## Acceptance criteria' section; {ISSUE_HELP}"
    if bug and not REPRODUCE.search(body):
        return f"a bug issue needs a '## Steps to reproduce' section with steps you ran; {ISSUE_HELP}"
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
    return check_issue_body(body or "", "bug" in labels)


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
        if args[:2] == ["pr", "merge"]:
            return "merging is Sam's decision; see Review and merge in CONTRIBUTING.md"
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
        # An unquoted heredoc body with an apostrophe cannot be split, so check the issue text as written.
        if ISSUE_CREATE.search(command):
            return check_issue_body(command, bool(BUG_LABEL.search(command)))
        return None
    for argv in parsed:
        reason = check(argv, cwd, command)
        if reason:
            return reason
    return None


def main() -> int:
    event = json.load(sys.stdin)
    command = event.get("tool_input", {}).get("command", "")
    reason = check_command(command, event.get("cwd") or os.getcwd())
    if reason:
        print(f"Blocked by .claude/hooks/guard-command.py: {reason}.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
