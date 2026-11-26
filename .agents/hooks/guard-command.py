#!/usr/bin/env python3
"""Antigravity PreToolUse adapter for .claude/hooks/guard-command.py.

Delegates all policy checks to .claude/hooks/guard-command.py so Claude Code
and Antigravity share a single source of truth.
"""
import importlib.util
import json
import os
import sys
from pathlib import Path

CLAUDE_GUARD = Path(__file__).resolve().parents[2] / ".claude/hooks/guard-command.py"


def load_guard():
    spec = importlib.util.spec_from_file_location("claude_guard_command", CLAUDE_GUARD)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    event = json.load(sys.stdin)
    tool_call = event.get("toolCall") or {}
    name = tool_call.get("name", "")
    args = tool_call.get("args") or {}
    cwd = event.get("cwd") or os.getcwd()
    guard = load_guard()

    reason = None
    if name == "run_command":
        command = args.get("CommandLine") or args.get("command") or ""
        reason = guard.check_command(command, cwd)
    elif name == "mcp_t3-code_pull_request_create":
        base = args.get("base")
        if guard.pr_needs_visual_evidence(cwd, base):
            reason = guard.check_pr_body(args.get("body") or "")

    if reason:
        json.dump(
            {
                "decision": "deny",
                "reason": f"Blocked by .claude/hooks/guard-command.py: {reason}.",
            },
            sys.stdout,
        )
    else:
        json.dump({"decision": "allow"}, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
