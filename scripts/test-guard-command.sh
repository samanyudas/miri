#!/usr/bin/env bash
# Regression tests for scripts/guard-command.sh: each command must be blocked or allowed as listed.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
expect() {
  local want="$1" cmd="$2" got=allow
  bash scripts/guard-command.sh --command "$cmd" 2>/dev/null || got=block
  if [[ "$got" != "$want" ]]; then
    echo "test-guard-command: expected $want, got $got: $cmd" >&2
    fail=1
  fi
}

expect block 'git commit --no-verify -m "wip"'
expect block 'git -c core.hooksPath=/dev/null commit -m x'
expect block 'git push --no-verify'
expect block 'git push --force origin feature/x'
expect block 'git push -f'
expect block 'git push origin +HEAD:main'
expect block 'git push --force-with-lease origin main'
expect block 'git push --force-with-lease origin HEAD:master'
expect block 'rm -rf /'
expect block 'rm -rf ~'
expect block 'rm -fr $HOME'
expect block 'cd /tmp && rm -rf "/"'
expect block 'rm --recursive --force ~/'
expect allow 'git commit -m "Add --no-op flag docs"'
expect allow 'git push origin main'
expect allow 'git push --force-with-lease origin feature/x'
expect allow 'rm -rf .harness/scratch'
expect allow 'rm -rf /tmp/build-123'
expect allow 'rm -rf ~/project/node_modules'
expect block 'cd repo && git push --force'
expect block 'GIT_TRACE=1 git commit --no-verify -m x'
expect block 'sudo rm -rf /'
expect block 'true; rm -rf ~'
expect allow 'echo "-f is fine here"'
expect allow 'echo git push -f'
expect allow 'git commit -m "Block --no-verify in the guard"'
expect allow 'cat > notes.md <<EOF
Never run git push --force or rm -rf / here.
EOF'
expect allow 'git log --oneline | grep push'

# The hook form reads the command from Claude Code's JSON input.
if ! echo '{"tool_input":{"command":"ls"}}' | bash scripts/guard-command.sh; then
  echo "test-guard-command: the hook form blocked 'ls'" >&2
  fail=1
fi
if echo '{"tool_input":{"command":"git push -f"}}' | bash scripts/guard-command.sh 2>/dev/null; then
  echo "test-guard-command: the hook form allowed 'git push -f'" >&2
  fail=1
fi
expect block 'bash -c "git push --force"'
expect block "git commit '--no-verify' -m x"
expect block 'rm -rf /tmp/build /'
expect allow 'git commit -m "Mention rm -rf / in documentation"'
if printf '%s' '{broken' | bash scripts/guard-command.sh 2>/dev/null; then
  echo 'test-guard-command: malformed JSON was accepted' >&2
  fail=1
fi
exit "$fail"
