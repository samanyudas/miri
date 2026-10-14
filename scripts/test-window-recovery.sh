#!/bin/bash
# Strands the test fixture's window off-screen and checks that Miri's own recovery brings it back.
# It moves only the fixture window. Without an Accessibility grant it reports a skip, never a pass.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 - <<'PY'
import json
from pathlib import Path
import subprocess
import tempfile
import time

root = Path.cwd()
app = root / '.build/app/Miri Developer.app'
fixture = root / '.build/debug/AXFixture'
assert app.is_dir() and fixture.is_file(), 'Run scripts/build-app.sh first'
evidence = Path(tempfile.mkdtemp(prefix='miri-recovery-', dir='/tmp'))
ready = evidence / 'fixture.pid'
report = evidence / 'recovery.json'
fixture_process = subprocess.Popen([str(fixture), '--ready-file', str(ready)],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    end = time.monotonic() + 10
    while not ready.exists():
        assert fixture_process.poll() is None and time.monotonic() < end, 'The fixture did not start'
        time.sleep(.02)
    target = int(ready.read_text())
    subprocess.run(['open', '-n', '-W', str(app), '--args', '--recovery-selftest', str(report),
                    '--target-pid', str(target)], check=True, timeout=30)
    result = json.loads(report.read_text())
    assert result['schemaVersion'] == 1
    if not result['trusted']:
        print('skipped-ungranted. Window recovery needs the Miri Developer Accessibility grant.')
    else:
        assert 'failure' not in result, result.get('failure')
        assert result['strandedNeededRecovery'] is True, f'The fixture was not stranded: {result}'
        assert result['recoveredIsReachable'] is True, f'The fixture stayed stranded: {result}'
        assert result['summary'] == {'checked': 1, 'moved': 1}, result['summary']
        print(f"recovered. Stranded at {result['stranded']}, recovered to {result['recovered']}.")
    print(f'Evidence {evidence}')
finally:
    fixture_process.terminate()
    try:
        fixture_process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        fixture_process.kill()
PY
