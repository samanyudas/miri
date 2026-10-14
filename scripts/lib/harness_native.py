#!/usr/bin/env python3
"""Retain packaged diagnostic observations without changing permissions."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from harness_environment import ROOT, atomic_json


def main():
    session = subprocess.run(['launchctl', 'print', 'gui/' + str(os.getuid())], capture_output=True)
    if session.returncode:
        print('GUI session unavailable. Launch Services verification requires a logged-in macOS desktop.')
        return 3
    result = subprocess.run(['scripts/test-permission-prototype.sh'], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end='')
    if result.returncode:
        return result.returncode
    evidence = [line[len('Evidence '):] for line in result.stdout.splitlines() if line.startswith('Evidence ')]
    if len(evidence) != 1:
        raise ValueError('The permission driver did not report one evidence directory.')
    source = Path(evidence[0])
    if source.is_symlink() or source.resolve().parent != Path('/tmp').resolve() or not source.name.startswith('miri-permission-'):
        raise ValueError('Unexpected permission evidence path: ' + str(source))
    target = Path(os.environ['HARNESS_RUN']) / 'permission'
    target.mkdir()
    for path in sorted(source.iterdir()):
        if path.suffix in ['.json', '.log']:
            if path.is_symlink() or not path.is_file():
                raise ValueError('Unexpected permission artifact: ' + str(path))
            shutil.copy2(path, target / path.name)
    if not (target / 'provenance.json').is_file() or not (target / 'observation.json').is_file():
        raise ValueError('Permission evidence lacks provenance or the primary observation.')
    atomic_json(target / 'origin.json', {'path': str(source), 'scope': 'packaged diagnostic observations',
                                      'permission_attribution': 'unresolved'})
    print('Retained permission JSON and logs in ' + str(target))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
