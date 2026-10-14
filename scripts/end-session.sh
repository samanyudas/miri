#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
level=portable
note=''
while [[ $# -gt 0 ]]; do
    case "$1" in
        --level) [[ $# -ge 2 ]] || exit 2; level="$2"; shift 2 ;;
        --note) [[ $# -ge 2 ]] || exit 2; note="$2"; shift 2 ;;
        *) echo 'Usage: scripts/end-session.sh [--level repo|portable|build|gui] [--note TEXT]' >&2; exit 2 ;;
    esac
done
case "$level" in repo|portable|build|gui) ;; *) echo "Unknown level: $level" >&2; exit 2 ;; esac
export HARNESS_HANDOFF=1 HARNESS_HANDOFF_NOTE="$note"
exec scripts/verify.sh --level "$level"
