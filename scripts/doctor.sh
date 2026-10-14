#!/bin/bash
# Reports missing or mismatched prerequisites. Usage: scripts/doctor.sh lint|native|all
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
pin=$(git ls-files --stage vendor/paneru | awk '{print $2}')
pinned_rust=$(sed -n 's/^channel = "\(.*\)"/\1/p' rust-toolchain.toml)

check "git: $(version git)" "Install the Xcode command-line tools." command -v git
check "engine checkout matches the pin" "git submodule update --init" \
    test "$(git -C vendor/paneru rev-parse HEAD 2>/dev/null)" = "$pin"

if [[ "$profile" != native ]]; then
    check "python3 3.11+: $(version python3)" "brew install python" \
        python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))'
    check "shellcheck 0.11.0" "brew install shellcheck, or match the version CI pins in .github/workflows/ci.yml" \
        test "$(shellcheck --version 2>/dev/null | sed -n 's/^version: //p')" = 0.11.0
    check "actionlint 1.7.12" "brew install actionlint, or match the version CI pins in .github/workflows/ci.yml" \
        test "$(actionlint --version 2>/dev/null | head -1)" = 1.7.12
fi

if [[ "$profile" != lint ]]; then
    check "Apple silicon Mac" "Native checks need an arm64 Mac." test "$(uname -sm)" = "Darwin arm64"
    check "macOS 27 or newer" "Update macOS." test "$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)" -ge 27
    check "swift: $(version swift)" "Install Xcode 27 and run xcode-select --switch." command -v swift
    check "rustc $pinned_rust from rust-toolchain.toml" "rustup toolchain install" \
        test "$(rustc --version 2>/dev/null | cut -d" " -f2)" = "$pinned_rust"
fi
exit $((failures > 0))
