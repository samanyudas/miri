#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import signal
import subprocess
import tempfile
import time

root = Path.cwd()
app = root / '.build/prototype/Miri Developer.app'
engine = app / 'Contents/Helpers/miri-engine'
fixture = root / '.build/debug/AXFixture'
evidence = Path(tempfile.mkdtemp(prefix='miri-permission-', dir='/tmp'))
owned_apps = {}

def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, timeout=20)

def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False

def stop(pid):
    if alive(pid):
        os.kill(pid, signal.SIGTERM)
        end = time.monotonic() + 2
        while alive(pid) and time.monotonic() < end:
            time.sleep(.02)
        if alive(pid):
            os.kill(pid, signal.SIGKILL)

def wait_file(path, process):
    end = time.monotonic() + 10
    while not path.exists():
        if process.poll() is not None or time.monotonic() >= end:
            raise RuntimeError(f'Process did not create {path}')
        time.sleep(.02)

def observe(bundle, name, target):
    report = evidence / f'{name}.json'
    with (evidence / f'{name}-launch.log').open('w') as log:
        launch = subprocess.Popen(['open', '-n', '-W', str(bundle), '--args',
                                   '--permission-observation', str(report), '--target-pid', str(target)],
                                  stdout=log, stderr=log)
        try:
            sidecar = report.with_suffix('.json.pid')
            wait_file(sidecar, launch)
            pid = int(sidecar.read_text())
            owned_apps[pid] = bundle / 'Contents/Helpers/miri-engine'
            launch.wait(timeout=12)
            assert launch.returncode == 0, 'LaunchServices failed'
            assert report.exists(), 'The app exited without an observation report'
            result = json.loads(report.read_text())
            assert result['schemaVersion'] == 1
            assert result['permissionAttribution'] == 'unresolved'
            reported_pid = result['appPid'] if 'failure' in result else result['app']['pid']
            assert reported_pid == pid, 'The report app PID differs from the launched app'
            end = time.monotonic() + 2
            while alive(pid) and time.monotonic() < end:
                time.sleep(.02)
            assert not alive(pid), 'The observed app survived its exit'
            return result
        finally:
            if launch.poll() is None:
                launch.kill()
            launch.wait(timeout=5)

assert engine.is_file() and fixture.is_file(), 'Run build-prototype.sh first'
metadata = {
    'macOS': run('sw_vers'), 'swift': run('swift', '--version'),
    'rust': run('rustc', '--version'), 'cargo': run('cargo', '--version'), 'appPath': str(app),
    'engineArchitecture': run('file', str(engine)),
    'appArchitecture': run('file', str(app / 'Contents/MacOS/MiriPrototype')),
    'engineSource': (app / 'Contents/Resources/engine-revision.txt').read_text().strip(),
    'engineSHA256': hashlib.sha256(engine.read_bytes()).hexdigest(),
    'appSHA256': hashlib.sha256((app / 'Contents/MacOS/MiriPrototype').read_bytes()).hexdigest(),
    'appSignature': run('codesign', '-dvv', str(app)),
    'engineSignature': run('codesign', '-dvv', str(engine)),
}
assert 'Identifier=io.github.samanyudas.miri.dev\n' in metadata['appSignature']
assert 'Identifier=io.github.samanyudas.miri.dev.engine\n' in metadata['engineSignature']
run('codesign', '--verify', '--strict', str(app))
run('codesign', '--verify', '--strict', str(engine))
plist_dump = run('otool', '-X', '-s', '__TEXT', '__info_plist', str(engine))
sections = []
for line in plist_dump.splitlines():
    fields = line.split()
    if fields and re.fullmatch(r'[0-9a-f]{8,16}', fields[0]):
        sections.extend(field for field in fields[1:] if re.fullmatch(r'(?:[0-9a-f]{8}|[0-9a-f]{2})', field))
embedded = plistlib.loads(b''.join(bytes.fromhex(word)[::-1] for word in sections).rstrip(b'\x00'))
assert embedded['CFBundleIdentifier'] == 'io.github.samanyudas.miri.dev.engine'
metadata['engineEmbeddedPlist'] = embedded
(evidence / 'provenance.json').write_text(json.dumps(metadata, indent=2))
fixture_process = None
try:
    ready = evidence / 'fixture.pid'
    fixture_process = subprocess.Popen([str(fixture), '--ready-file', str(ready)],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    wait_file(ready, fixture_process)
    target = int(ready.read_text())
    assert target == fixture_process.pid
    tmp_app = evidence / 'PathAlias.app'
    shutil.copytree(app, tmp_app)
    assert tmp_app != tmp_app.resolve(), 'The regression requires the macOS /tmp path alias'
    observations = []
    for bundle, name in [(app, 'observation'), (tmp_app, 'tmp-path'),
                         (tmp_app.resolve(), 'physical-tmp-path')]:
        result = observe(bundle, name, target)
        assert 'failure' not in result, f'{name}: {result.get("failure")}'
        assert Path(result['bundlePath']).is_absolute()
        assert Path(result['bundlePath']).resolve(strict=True) == bundle.resolve(strict=True)
        assert result['engineRevision'] == metadata['engineSource']
        for key, identifier, executable in [
            ('app', 'io.github.samanyudas.miri.dev', bundle / 'Contents/MacOS/MiriPrototype'),
            ('engine', 'io.github.samanyudas.miri.dev.engine', bundle / 'Contents/Helpers/miri-engine'),
        ]:
            value = result[key]
            assert value['schemaVersion'] == 1 and value['targetPid'] == target
            assert type(value['trusted']) is bool and type(value['readCode']) is int
            assert value['bundleIdentifier'] == identifier
            assert Path(value['executable']).is_absolute()
            assert Path(value['executable']).resolve(strict=True) == executable.resolve(strict=True)
            assert value['pid'] != target
            assert not alive(value['pid']), f'{key} process survived its observation'
            if value['readCode'] == 0:
                assert value['role'] == 'AXApplication'
        observations.append(result)
    result = observations[0]
    hostile = os.environ.copy()
    hostile['PANERU_CONFIG'] = str(evidence / 'must-not-create-config' / 'hostile.toml')
    probe = subprocess.run([str(engine), 'miri-ax-probe', '--target-pid', str(target)],
                           env=hostile, capture_output=True, text=True, timeout=5, check=True)
    assert len(probe.stdout) <= 16_384 and not probe.stderr
    assert json.loads(probe.stdout)['targetPid'] == target
    assert not (evidence / 'must-not-create-config').exists()
    for arguments in [[], ['--target-pid', '0'], ['--target-pid', '-1'],
                      ['--target-pid', str(target), '--launch']]:
        rejected = subprocess.run([str(engine), 'miri-ax-probe', *arguments],
                                  env=hostile, capture_output=True, timeout=5)
        assert rejected.returncode != 0 and not rejected.stdout
    broken = evidence / 'MissingEngine.app'
    shutil.copytree(app, broken)
    (broken / 'Contents/Helpers/miri-engine').unlink()
    run('codesign', '--force', '--sign', '-', str(broken))
    run('codesign', '--verify', '--strict', str(broken))
    failure = observe(broken, 'missing-helper', target)
    assert failure['failure'] == 'The bundled engine is missing or is not executable.'
    status = 'observed-granted' if result['app']['trusted'] and result['engine']['trusted'] else 'observed-ungranted'
    print(f'{status}. Attribution unresolved. Missing-helper and aliased-path checks passed.')
    print(f'Evidence {evidence}')
finally:
    for pid, bundled_engine in owned_apps.items():
        if alive(pid):
            children = run('ps', '-axo', 'pid=,ppid=,comm=').splitlines()
            for child in children:
                fields = child.strip().split(maxsplit=2)
                if (len(fields) == 3 and int(fields[1]) == pid
                        and Path(fields[2]).resolve() == bundled_engine.resolve()):
                    stop(int(fields[0]))
            stop(pid)
    if fixture_process is not None:
        if fixture_process.poll() is None:
            fixture_process.terminate()
        try:
            fixture_process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            fixture_process.kill()
            fixture_process.wait(timeout=3)
PY
