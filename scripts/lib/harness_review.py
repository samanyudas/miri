#!/usr/bin/env python3
"""Report topic pointers for the requested Git diff without imposing new policy."""
import json
import os
import subprocess
import sys
from harness_environment import ROOT


def main():
    revisions = sys.argv[1:]
    if revisions != ['--cached']:
        for revision in revisions:
            subprocess.run(['git', 'rev-parse', '--verify', revision + '^{commit}'], cwd=ROOT,
                           stdout=subprocess.DEVNULL, check=True)
    raw = subprocess.check_output(['git', 'diff', '--name-only', '-z', *revisions, '--'], cwd=ROOT)
    paths = [os.fsdecode(item) for item in raw.split(b'\0') if item]
    print('Review scope: ' + ('staged index' if revisions == ['--cached'] else ' '.join(revisions)))
    print('\n'.join(paths) or '(no changed paths)')
    for hint in json.loads((ROOT / 'scripts/review-paths.json').read_text()):
        if any(path == prefix or prefix.endswith('/') and path.startswith(prefix)
               for path in paths for prefix in hint['paths']):
            print('{}: read {}'.format(hint['component'], hint['adr']))
    print('Path hints are advisory. Check the actual diff and the cited decisions.')


if __name__ == '__main__':
    main()
