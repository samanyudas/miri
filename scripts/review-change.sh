#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# == 1 && "$1" == --cached ]]; then
    exec python3 scripts/lib/harness_review.py --cached
elif [[ $# == 2 && "$1" != -* && "$2" != -* ]]; then
    exec python3 scripts/lib/harness_review.py "$1" "$2"
else
    echo 'Usage: scripts/review-change.sh --cached | BASE HEAD' >&2
    exit 2
fi
