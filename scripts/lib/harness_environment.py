#!/usr/bin/env python3
"""Live prerequisites and private worktree readiness stamps."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def command(*args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, stderr=subprocess.STDOUT, text=True).strip()


def digest(value):
    return hashlib.sha256(value).hexdigest()


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(dir=path.parent, prefix='.' + path.name)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write('\n')
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def inventory():
    raw = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT)
    return sorted(set(os.fsdecode(raw).rstrip('\0').split('\0')) - {''})


def source_state():
    entries = []
    for name in inventory():
        path = ROOT / name
        if path.is_symlink():
            value = ['symlink', os.readlink(path)]
        elif path.is_file():
            value = [path.stat().st_mode & 0o777, digest(path.read_bytes())]
        elif path.is_dir():
            value = ['gitlink', command('git', 'ls-files', '--stage', '--', name)]
        else:
            value = ['missing']
        entries.append([name, value])
    return {
        'head': command('git', 'rev-parse', 'HEAD'),
        'tree_fingerprint': digest(json.dumps(entries, ensure_ascii=True).encode()),
        'dirty': command('git', 'status', '--short', '--untracked-files=all'),
    }


def git_state_dir():
    path = Path(command('git', 'rev-parse', '--git-path', 'miri-harness'))
    return path if path.is_absolute() else ROOT / path


def observe(profile):
    errors = []
    tools = {}

    def tool(name, args, minimum=None):
        executable = shutil.which(name)
        if not executable:
            errors.append('Missing tool: ' + name)
            return ''
        try:
            version = command(executable, *args)
            tools[name] = {'path': str(Path(executable).absolute()), 'version': version}
            if minimum:
                pattern = r'(?:Apple )?Swift version (\d+)\.(\d+)(?:\.(\d+))?' if name == 'swift' else r'\b(\d+)\.(\d+)(?:\.(\d+))?'
                found = re.search(pattern, version, re.IGNORECASE)
                if not found or tuple(int(x or 0) for x in found.groups()) < minimum:
                    errors.append('{} requires at least {}'.format(name, '.'.join(map(str, minimum))))
            return version
        except (OSError, subprocess.CalledProcessError) as error:
            errors.append('{} failed: {}'.format(name, error))
            return ''

    tool('bash', ['--version'])
    tool('git', ['--version'])
    tool('python3', ['--version'], (3, 8, 0))
    host = {'system': platform.system(), 'release': platform.release(), 'machine': platform.machine()}
    pin = command('git', 'ls-files', '--stage', '--', 'vendor/paneru').split()
    engine = {'gitlink': pin[1] if len(pin) > 1 else None, 'checkout': None, 'dirty': None}
    initialized = (ROOT / 'vendor/paneru/.git').exists()
    if initialized:
        engine['checkout'] = command('git', '-C', 'vendor/paneru', 'rev-parse', 'HEAD')
        engine['dirty'] = command('git', '-C', 'vendor/paneru', 'status', '--porcelain')
    if profile == 'native':
        if host['system'] != 'Darwin' or host['machine'] != 'arm64':
            errors.append('Native checks require macOS 27 or later on arm64.')
        else:
            host['macos'] = tool('sw_vers', ['-productVersion'], (27, 0, 0))
            tool('swift', ['--version'], (6, 2, 0))
            tool('rustc', ['--version'], (1, 95, 0))
            tool('cargo', ['--version'], (1, 95, 0))
            tool('rustfmt', ['--version'])
            tool('cargo-clippy', ['--version'])
            host['sdk'] = tool('xcrun', ['--sdk', 'macosx', '--show-sdk-version'], (27, 0, 0))
            host['developer_dir'] = tool('xcode-select', ['-p'])
            for name, args in [('otool', ['--version']), ('file', ['--version'])]:
                tool(name, args)
            for name in ['codesign', 'lipo', 'open', 'ps', 'launchctl']:
                path = shutil.which(name)
                if path:
                    tools[name] = {'path': path, 'sha256': digest(Path(path).read_bytes())}
                else:
                    errors.append('Missing packaging/runtime tool: ' + name)
        if not initialized:
            errors.append('The engine is uninitialized. Run scripts/setup.sh --profile native.')
        elif engine['checkout'] != engine['gitlink'] or engine['dirty']:
            errors.append('The engine checkout is dirty or differs from its gitlink. Preserve it and resolve the difference first.')
        elif not errors:
            try:
                command('cargo', 'metadata', '--manifest-path', 'vendor/paneru/Cargo.toml',
                        '--locked', '--offline', '--no-deps', '--format-version', '1')
            except subprocess.CalledProcessError as error:
                errors.append('Engine manifest validation failed: ' + error.output)
    names = ['Package.swift', 'Package.resolved', '.gitmodules', 'vendor/paneru/Cargo.toml',
             'vendor/paneru/Cargo.lock', 'rust-toolchain', 'rust-toolchain.toml',
             'vendor/paneru/rust-toolchain', 'vendor/paneru/rust-toolchain.toml',
             '.swift-version', 'scripts/setup.sh', 'scripts/check-ready.sh',
             'scripts/lib/harness_environment.py']
    inputs = {name: digest((ROOT / name).read_bytes()) if (ROOT / name).is_file() else None for name in names}
    observation = {'schema': 1, 'profile': profile, 'platform': host, 'tools': tools,
                   'inputs': inputs, 'engine': engine, 'errors': errors}
    observation['fingerprint'] = digest(json.dumps(observation, sort_keys=True).encode())
    return observation


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['setup', 'check', 'observe'])
    parser.add_argument('--profile', choices=['portable', 'native'], default='portable')
    args = parser.parse_args()
    if args.action == 'setup' and args.profile == 'native' and not (ROOT / 'vendor/paneru/.git').exists():
        current = observe('native')
        other_errors = [e for e in current['errors'] if not e.startswith('The engine is uninitialized.')]
        if other_errors:
            print('\n'.join(other_errors), file=sys.stderr)
            return 3
        subprocess.run(['git', 'submodule', 'update', '--init', '--', 'vendor/paneru'], cwd=ROOT, check=True)
    current = observe(args.profile)
    if args.action == 'observe':
        print(json.dumps(current, indent=2))
        return 0
    if current['errors']:
        print('\n'.join(current['errors']), file=sys.stderr)
        return 3
    stamp = git_state_dir() / (args.profile + '.json')
    if args.action == 'setup':
        atomic_json(stamp, current)
        print('Ready for {} checks. Stamp {}'.format(args.profile, stamp))
        return 0
    try:
        saved = json.loads(stamp.read_text())
    except (OSError, ValueError):
        saved = {}
    if saved.get('fingerprint') != current['fingerprint']:
        print('Readiness is missing or stale. Run scripts/setup.sh --profile ' + args.profile, file=sys.stderr)
        return 3
    print('Ready for {} checks. Live environment matches the worktree stamp.'.format(args.profile))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print('Environment check unavailable: ' + str(error), file=sys.stderr)
        sys.exit(3)
