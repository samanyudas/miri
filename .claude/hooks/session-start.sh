#!/bin/bash
# Prints the handoff record and working-tree state so a fresh session resumes instead of restarting.
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}" || exit 0
printf 'Branch: %s\n' "$(git branch --show-current 2>/dev/null || echo detached)"
changes=$(git status --short 2>/dev/null)
if [[ -n "$changes" ]]; then
    printf 'Uncommitted changes:\n%s\n' "$(head -20 <<<"$changes")"
fi
[[ -f PROGRESS.md ]] && printf '\n%s\n' "$(cat PROGRESS.md)"
exit 0
