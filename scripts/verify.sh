#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
level=portable
if [[ $# == 2 && "$1" == --level ]]; then
    case "$2" in repo|portable|build|gui) level="$2" ;; *) echo "Unknown level: $2" >&2; exit 2 ;; esac
elif [[ $# != 0 ]]; then
    echo 'Usage: scripts/verify.sh [--level repo|portable|build|gui]' >&2
    exit 2
fi
checks=(repository:repo)
if [[ "$level" != repo ]]; then
    checks+=(portable-ready:portable syntax:portable harness-tests:portable writing-tests:portable guard-tests:portable writing:portable)
fi
if [[ "$level" == build || "$level" == gui ]]; then
    checks+=(native-ready:build native-lock:build engine-format:build engine-clippy:build engine-tests:build package:build)
fi
if [[ "$level" == gui ]]; then checks+=(permission-driver:gui); fi
source scripts/lib/runs.sh
run=$(python3 scripts/lib/harness_runs.py begin "$level" "${checks[@]}")
check_pid=''
trap finish_run EXIT
trap 'interrupt_run 130' INT
trap 'interrupt_run 143' TERM
printf 'Verifying %s in %s\n' "$level" "$run"
run_check repository python3 scripts/check-repo.py
if [[ "$level" == repo ]]; then exit 0; fi
run_check portable-ready scripts/check-ready.sh --profile portable
run_check syntax python3 scripts/check-repo.py --syntax
run_check harness-tests python3 scripts/test-harness.py
run_check writing-tests python3 scripts/test-ste.py
run_check guard-tests bash scripts/test-guard-command.sh
run_check writing python3 scripts/check-ste.py --advisory --output "$run/writing.json"
if [[ "$level" == portable ]]; then exit 0; fi
run_check native-ready scripts/check-ready.sh --profile native
run_check native-lock python3 scripts/lib/harness_runs.py lock acquire "$run" "$$"
run_check engine-format cargo fmt --manifest-path vendor/paneru/Cargo.toml --check
run_check engine-clippy env -u CARGO_BUILD_TARGET cargo clippy --manifest-path vendor/paneru/Cargo.toml --target-dir "$PWD/vendor/paneru/target" --locked --all-targets --no-default-features -- -D warnings
run_check engine-tests env -u CARGO_BUILD_TARGET cargo test --manifest-path vendor/paneru/Cargo.toml --target-dir "$PWD/vendor/paneru/target" --locked --all-targets --no-default-features
run_check package scripts/build-prototype.sh
if [[ "$level" == gui ]]; then
    run_check permission-driver python3 scripts/lib/harness_native.py
fi
