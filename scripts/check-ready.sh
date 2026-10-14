#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "$#:$*" in
  0:) exec python3 scripts/lib/harness_environment.py check --profile portable ;;
  2:'--profile portable'|2:'--profile native') exec python3 scripts/lib/harness_environment.py check "$@" ;;
  *) echo 'Usage: scripts/check-ready.sh [--profile portable|native]' >&2; exit 2 ;;
esac
