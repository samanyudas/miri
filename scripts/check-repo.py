#!/usr/bin/env python3
"""Validate maintained paths and immutable third-party writing tools."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
from lib.harness_environment import ROOT, inventory

VENDORED = {
    'scripts/lib/ste_lint.py': '1b97b2d22ba50cde10654db56e1b98adf96d250dd3c8f693f8a81361b1084e85',
    'scripts/lib/ste_lint.LICENSE': 'd3c674e8592076c9021a59b55177adbcba6fd7e1710082becb922522b22ec672',
}


def local_path(name):
    path = ROOT / name
    path.resolve(strict=True).relative_to(ROOT)
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--syntax', action='store_true')
    args = parser.parse_args()
    names = inventory()
    errors = []
    if args.syntax:
        for name in names:
            path = ROOT / name
            if not path.is_file() or name.startswith('vendor/'):
                continue
            try:
                if path.suffix == '.py':
                    ast.parse(path.read_bytes(), filename=name)
                elif path.suffix == '.sh' or name == '.githooks/pre-commit':
                    subprocess.run(['bash', '-n', str(path)], check=True)
            except (OSError, SyntaxError, subprocess.CalledProcessError) as error:
                errors.append(str(error))
    else:
        agents = (ROOT / 'AGENTS.md').read_text()
        mapped = re.findall(r'^\| `([^`]+)` \|', agents, re.MULTILINE)
        if not mapped:
            errors.append('AGENTS.md has no repository map.')
        for prefix in mapped:
            try:
                local_path(prefix)
            except (OSError, ValueError, RuntimeError) as error:
                errors.append('Missing or escaping map path {}: {}'.format(prefix, error))
        for name in names:
            if not any(name == prefix or prefix.endswith('/') and name.startswith(prefix) for prefix in mapped):
                errors.append('Unmapped path: ' + name)
        for name, expected in VENDORED.items():
            if hashlib.sha256(local_path(name).read_bytes()).hexdigest() != expected:
                errors.append('Vendored upstream hash changed: ' + name)
        hints = json.loads((ROOT / 'scripts/review-paths.json').read_text())
        if not isinstance(hints, list):
            errors.append('Review hints must contain a list.')
        else:
            for hint in hints:
                for name in hint['paths'] + [hint['adr']]:
                    local_path(name)
        settings = json.loads((ROOT / '.claude/settings.json').read_text())
        session = settings['hooks']['SessionStart']
        expected = '"$CLAUDE_PROJECT_DIR"/scripts/restore-state.sh'
        if session != [{'hooks': [{'type': 'command', 'command': expected}]}]:
            errors.append('Tracked Claude SessionStart must run the maintained restore command.')
        for name in ['scripts/restore-state.sh', 'scripts/guard-command.sh', '.githooks/pre-commit']:
            if not os.access(local_path(name), os.X_OK):
                errors.append('Hook is not executable: ' + name)
        for name in names:
            if name.endswith('.json') and not name.startswith('vendor/') and (ROOT / name).is_file():
                json.loads(local_path(name).read_text())
    for error in errors:
        print(error, file=sys.stderr)
    if not errors:
        print('Syntax checks passed.' if args.syntax else 'Repository map, review hints, hooks, JSON, and upstream hashes passed.')
    return bool(errors)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as error:
        print('Repository check failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
