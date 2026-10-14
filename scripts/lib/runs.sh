run_check() {
    local id="$1" code
    shift
    python3 scripts/lib/harness_runs.py check "$run" "$id" "$@" &
    check_pid=$!
    if wait "$check_pid"; then code=0; else code=$?; fi
    check_pid=''
    return "$code"
}

finish_run() {
    local code=$? result
    trap - EXIT INT TERM
    python3 scripts/lib/harness_runs.py lock release "$run" "$$"
    if python3 scripts/lib/harness_runs.py finish "$run" "$code"; then result=0; else result=$?; fi
    exit "$result"
}

interrupt_run() {
    local code="$1"
    trap '' INT TERM
    if [[ -n "${check_pid:-}" ]]; then
        kill -TERM "$check_pid" 2>/dev/null || true
        wait "$check_pid" || true
    fi
    exit "$code"
}
