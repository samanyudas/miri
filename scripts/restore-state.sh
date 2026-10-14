#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 0 ]]; then echo 'Usage: scripts/restore-state.sh' >&2; exit 2; fi
exec python3 scripts/lib/harness_runs.py restore
