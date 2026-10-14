#!/usr/bin/env bash
set -euo pipefail
exec python3 "$(dirname "$0")/lib/harness_guard.py" "$@"
