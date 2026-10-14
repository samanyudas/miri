#!/usr/bin/env python3
"""Optional integrations never replace foreign configuration."""
import json
from pathlib import Path
import subprocess
import sys

from harness_environment import ROOT, atomic_json, command

GUARD_COMMAND = '"$CLAUDE_PROJECT_DIR"/scripts/guard-command.sh'
GUARD = {'matcher': 'Bash', 'hooks': [{'type': 'command', 'command': GUARD_COMMAND}]}


def config(key):
    result = subprocess.run(['git', 'config', '--get', key], cwd=ROOT, capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None


def install_hooks():
    managed = str(ROOT / '.githooks')
    existing = config('core.hooksPath')
    if existing is not None and existing != managed:
        raise ValueError('Refusing foreign core.hooksPath: ' + existing)
    if config('extensions.worktreeConfig') != 'true':
        raise ValueError('Worktree configuration is disabled. No hooks were installed. '
                         'Enable it explicitly with: git config extensions.worktreeConfig true')
    command('git', 'config', '--worktree', 'core.hooksPath', managed)
    print('Installed hooks for this worktree only: ' + managed)


def install_guard():
    path = ROOT / '.claude/settings.local.json'
    if path.is_symlink():
        raise ValueError('Refusing symlinked Claude local settings.')
    settings = json.loads(path.read_text()) if path.exists() else {}
    if not isinstance(settings, dict):
        raise ValueError('Claude local settings must contain an object.')
    hooks = settings.setdefault('hooks', {})
    if not isinstance(hooks, dict):
        raise ValueError('Claude hooks must contain an object.')
    entries = hooks.setdefault('PreToolUse', [])
    if not isinstance(entries, list):
        raise ValueError('Claude PreToolUse must contain an array.')
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get('hooks'), list):
            raise ValueError('Malformed foreign PreToolUse entry. Settings were preserved.')
        for hook in entry['hooks']:
            if not isinstance(hook, dict):
                raise ValueError('Malformed foreign hook. Settings were preserved.')
            if 'guard-command.sh' in str(hook.get('command', '')) and entry != GUARD:
                raise ValueError('Foreign guard-command.sh entry. Settings were preserved.')
    if GUARD not in entries:
        entries.append(GUARD)
        atomic_json(path, settings)
    print('Claude command guard enabled in ' + str(path))


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['hooks']:
            install_hooks()
        elif sys.argv[1:] == ['guard']:
            install_guard()
        else:
            raise ValueError('Expected hooks or guard.')
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
