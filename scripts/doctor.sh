#!/bin/bash
# Reports missing or mismatched prerequisites. Usage: scripts/doctor.sh lint|native|all
# shellcheck disable=SC2329 # The predicate functions below run through check "$@".
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
profile=${1:-all}
failures=0

# check <label> <fix> <command...>
check() {
    local label=$1 fix=$2
    shift 2
    if "$@" >/dev/null 2>&1; then
        printf 'ok    %s\n' "$label"
    else
        printf 'FAIL  %s\n      %s\n' "$label" "$fix"
        failures=$((failures + 1))
    fi
}
version() { "$1" --version 2>&1 | head -1; }
engine_on_pin() { [[ "$(git -C vendor/paneru rev-parse HEAD)" == "$(git ls-files --stage vendor/paneru | awk '{print $2}')" ]]; }
macos_27() { [[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 27 ]]; }
pinned=$(sed -n 's/^channel = "\(.*\)"/\1/p' rust-toolchain.toml)
rust_pinned() { rustc --version | grep -q "^rustc $pinned "; }

check "git: $(version git)" "Install the Xcode command-line tools." command -v git
check "engine checkout matches the pin" "git submodule update --init" engine_on_pin

if [[ "$profile" != native ]]; then
    check "python3 3.11+: $(version python3)" "brew install python" \
        python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'
    check "shellcheck: $(version shellcheck | tail -1)" "brew install shellcheck" command -v shellcheck
    check "actionlint: $(version actionlint)" "brew install actionlint" command -v actionlint
fi

if [[ "$profile" != lint ]]; then
    check "Apple silicon Mac" "Native checks need an arm64 Mac." test "$(uname -sm)" = "Darwin arm64"
    check "macOS 27 or newer" "Update macOS." macos_27
    check "swift: $(version swift)" "Install Xcode 27 and run xcode-select --switch." command -v swift
    check "rustc $pinned from rust-toolchain.toml" "rustup toolchain install" rust_pinned
fi
exit $((failures > 0))
