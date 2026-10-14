#!/usr/bin/env python3
"""Serialize verification results and retain the exact scope of each run."""
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
from typing import List, Literal, Optional

from harness_environment import ROOT, atomic_json, observe, source_state

CheckStatus = Literal['passed', 'failed', 'unavailable', 'interrupted', 'not_run']


@dataclass
class CheckResult:
    id: str
    level: str
    blocking: bool = True
    status: CheckStatus = 'not_run'
    exit_code: Optional[int] = None
    elapsed_seconds: float = 0
    scope: str = 'working-tree'
    log: Optional[str] = None
    artifacts: List[str] = field(default_factory=list)


def now():
    return datetime.now(timezone.utc).isoformat()


def read(run):
    return json.loads((run / 'summary.json').read_text())


def save(run, summary):
    atomic_json(run / 'summary.json', summary)


def begin(level, checks):
    parent = ROOT / '.harness/runs'
    parent.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S-'), dir=parent))
    state = source_state()
    environment = observe('native' if level in ['build', 'gui'] else 'portable')
    atomic_json(run / 'environment.json', environment)
    summary = {
        'schema': 1, 'run': run.name, 'scope': 'working-tree', 'requested_level': level,
        'worktree': str(ROOT), 'started_at': now(), 'finished_at': None,
        'status': 'not_run', 'source': state, 'engine': environment['engine'],
        'environment_fingerprint': environment['fingerprint'],
        'environment': 'environment.json',
        'checks': [asdict(CheckResult(*item.split(':'))) for item in checks],
    }
    if os.environ.get('HARNESS_HANDOFF') == '1':
        summary['handoff'] = {'note': os.environ.get('HARNESS_HANDOFF_NOTE', ''), 'dirty': state['dirty']}
    save(run, summary)
    print(run)


def execute(run, identifier, argv):
    summary = read(run)
    check = next(item for item in summary['checks'] if item['id'] == identifier)
    check['log'] = identifier + '.log'
    save(run, summary)
    started = time.monotonic()
    interrupted = []
    process = None

    def stop(signum, frame):
        interrupted.append(signum)
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGTERM)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    with (run / check['log']).open('w') as log:
        try:
            process = subprocess.Popen(argv, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True, env=dict(os.environ, HARNESS_RUN=str(run)))
            while True:
                try:
                    code = process.wait(timeout=0.2)
                    break
                except subprocess.TimeoutExpired:
                    if interrupted:
                        try:
                            code = process.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            os.killpg(process.pid, signal.SIGKILL)
                            code = process.wait()
                        break
        except OSError as error:
            log.write(str(error) + '\n')
            code = 3
    if interrupted:
        code = 128 + interrupted[0]
        status = 'interrupted'
    else:
        status = 'passed' if code == 0 else 'unavailable' if code == 3 else 'failed'
    check.update(status=status, exit_code=code, elapsed_seconds=round(time.monotonic() - started, 3))
    if identifier == 'writing':
        try:
            report = json.loads((run / 'writing.json').read_text())
            check['findings'] = len(report['findings'])
            check['artifacts'].append('writing.json')
        except (OSError, ValueError, KeyError):
            pass
    if identifier == 'permission-driver' and (run / 'permission').is_dir():
        check['artifacts'].append('permission/')
    save(run, summary)
    print('{}: {} ({})'.format(identifier, status, check['log']), flush=True)
    if code:
        print((run / check['log']).read_text(errors='replace'), end='')
    return code


def finish(run, code):
    summary = read(run)
    summary['finished_at'] = now()
    summary['exit_code'] = code
    summary['status'] = 'passed' if code == 0 else 'unavailable' if code == 3 else 'interrupted' if code >= 128 else 'failed'
    summary['source_at_finish'] = source_state()
    summary['source_changed_during_run'] = summary['source'] != summary['source_at_finish']
    if code == 0 and summary['source_changed_during_run']:
        summary['status'] = 'failed'
        summary['exit_code'] = 1
        print('Source changed during verification. Run the checks again.', file=sys.stderr)
    save(run, summary)
    print('Evidence ' + str(run / 'summary.json'))
    return summary['exit_code']


def restore():
    current = source_state()
    print('HEAD ' + current['head'])
    print('Dirty files:\n' + (current['dirty'] or '(none)'))
    print('Tasks: https://github.com/samanyudas/miri/issues')
    print('Product: decisions/; architecture: docs/adr/; terms: GLOSSARY.md')
    completed = []
    for path in (ROOT / '.harness/runs').glob('*/summary.json'):
        try:
            summary = json.loads(path.read_text())
            if summary.get('finished_at'):
                completed.append((summary['finished_at'], path, summary))
        except (OSError, ValueError):
            continue
    if not completed:
        print('No completed verification evidence in this worktree.')
        return
    _, path, summary = max(completed, key=lambda item: item[0])
    profile = 'native' if summary['requested_level'] in ['build', 'gui'] else 'portable'
    live = observe(profile)
    same_source = (summary['source']['head'] == current['head'] and
                   summary['source']['tree_fingerprint'] == current['tree_fingerprint'] and
                   not summary.get('source_changed_during_run'))
    fresh = same_source and summary['environment_fingerprint'] == live['fingerprint'] and not live['errors']
    print('Latest completed evidence: {}. {} at level {}.'.format(
        'current' if fresh else 'stale', summary['status'], summary['requested_level']))
    print('Tested HEAD ' + summary['source']['head'])
    print('Tested dirty tree: ' + ('yes' if summary['source']['dirty'] else 'no'))
    print(str(path))


def native_lock(action, run, owner):
    lock = ROOT / '.harness/native.lock'
    if action == 'acquire':
        try:
            lock.mkdir()
        except FileExistsError:
            print('Native output is owned by another run: ' + str(lock), file=sys.stderr)
            print('Inspect owner.json and process liveness before removing a stale lock.', file=sys.stderr)
            return 3
        atomic_json(lock / 'owner.json', {'pid': int(owner), 'run': str(run)})
    else:
        try:
            held = json.loads((lock / 'owner.json').read_text())
            if held == {'pid': int(owner), 'run': str(run)}:
                (lock / 'owner.json').unlink()
                lock.rmdir()
        except FileNotFoundError:
            pass
    return 0


def main():
    action, *args = sys.argv[1:]
    if action == 'begin':
        begin(args[0], args[1:])
    elif action == 'check':
        return execute(Path(args[0]), args[1], args[2:])
    elif action == 'finish':
        return finish(Path(args[0]), int(args[1]))
    elif action == 'restore':
        restore()
    elif action == 'lock':
        return native_lock(args[0], Path(args[1]), args[2])
    else:
        raise ValueError('Unknown run action: ' + action)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print('Run evidence error: ' + str(error), file=sys.stderr)
        sys.exit(1)
