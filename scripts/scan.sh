#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# != 0 ]]; then echo 'Usage: scripts/scan.sh' >&2; exit 2; fi
scripts/restore-state.sh
scripts/setup.sh --profile portable
scripts/verify.sh --level portable
