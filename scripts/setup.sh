#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "$#:$*" in
  0:) exec python3 scripts/lib/harness_environment.py setup --profile portable ;;
  2:'--profile portable'|2:'--profile native') exec python3 scripts/lib/harness_environment.py setup "$@" ;;
  1:--install-hooks) exec python3 scripts/lib/harness_integrations.py hooks ;;
  1:--enable-claude-guard) exec python3 scripts/lib/harness_integrations.py guard ;;
  *) echo 'Usage: scripts/setup.sh [--profile portable|native | --install-hooks | --enable-claude-guard]' >&2; exit 2 ;;
esac
