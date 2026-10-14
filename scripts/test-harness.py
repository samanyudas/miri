#!/usr/bin/env python3
"""Exercise public commands in disposable repositories and linked worktrees."""
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
PIN = 'f1df5873832c980c046fa6d55f7745c8b715e39c'


class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='miri-harness-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'repo'
        self.root.mkdir()
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                        GIT_AUTHOR_NAME='Harness test', GIT_AUTHOR_EMAIL='test@example.invalid',
                        GIT_COMMITTER_NAME='Harness test', GIT_COMMITTER_EMAIL='test@example.invalid')
        for key in ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'HARNESS_RUN', 'HARNESS_HANDOFF', 'HARNESS_HANDOFF_NOTE']:
            self.env.pop(key, None)
        names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT)
        for name in set(os.fsdecode(names).rstrip('\0').split('\0')):
            source = ROOT / name
            if not name or not source.is_file() or name.startswith('vendor/'):
                continue
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        self.write('scripts/test-harness.py', "print('Fixture nested test workload completed.')\n")
        self.git('init', '-q')
        self.git('add', '.')
        self.git('update-index', '--add', '--cacheinfo', '160000,' + PIN + ',vendor/paneru')
        self.git('commit', '-qm', 'Fixture baseline')
        (self.root / 'vendor/paneru').mkdir(parents=True)

    def write(self, name, text, executable=False):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if executable:
            path.chmod(0o755)
        return path

    def git(self, *args, root=None, check=True):
        return subprocess.run(['git', *args], cwd=root or self.root, env=self.env,
                              capture_output=True, text=True, check=check)

    def run_cli(self, *args, expected=0, env=None, root=None):
        result = subprocess.run(list(args), cwd=root or self.root, env=env or self.env,
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def setup_portable(self):
        self.run_cli('scripts/setup.sh', '--profile', 'portable')

    def summaries(self):
        return [json.loads(path.read_text()) for path in sorted((self.root / '.harness/runs').glob('*/summary.json'))]

    def stub_tool(self, name, body):
        directory = Path(self.temp.name) / 'tools'
        directory.mkdir(exist_ok=True)
        path = directory / name
        path.write_text('#!/bin/bash\n' + body + '\n')
        path.chmod(0o755)
        self.env['PATH'] = str(directory) + os.pathsep + self.env['PATH']
        return path

    def wait_for(self, condition):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if condition():
                return
            time.sleep(0.05)
        self.fail('The requested process state did not occur.')

    def test_setup_repeats_and_detects_tool_and_input_drift(self):
        self.setup_portable()
        stamp = self.root / '.git/miri-harness/portable.json'
        before = stamp.read_bytes()
        self.setup_portable()
        self.assertEqual(stamp.read_bytes(), before)
        self.run_cli('scripts/check-ready.sh')
        self.stub_tool('bash', 'if [[ "$1" == --version ]]; then echo "GNU bash, version 9.0"; else exec /bin/bash "$@"; fi')
        result = self.run_cli('scripts/check-ready.sh', expected=3)
        self.assertIn('missing or stale', result.stderr)
        self.setup_portable()
        self.write('Package.resolved', '{}\n')
        self.run_cli('scripts/check-ready.sh', expected=3)
        self.setup_portable()
        self.write('scripts/setup.sh', (self.root / 'scripts/setup.sh').read_text() + '\n')
        self.run_cli('scripts/check-ready.sh', expected=3)

    def test_missing_tool_does_not_create_stamp(self):
        self.stub_tool('git', 'if [[ "$1" == --version ]]; then exit 1; else exec /usr/bin/git "$@"; fi')
        result = self.run_cli('scripts/setup.sh', expected=3)
        self.assertIn('git failed', result.stderr)
        self.assertFalse((self.root / '.git/miri-harness/portable.json').exists())

    def test_unknown_arguments_do_not_mutate(self):
        before = self.git('status', '--porcelain').stdout
        for command, args in [('setup.sh', ['--profile', 'portable', '--oops']),
                              ('check-ready.sh', ['--profile', 'typo']), ('verify.sh', ['--level', 'typo']),
                              ('restore-state.sh', ['oops']), ('end-session.sh', ['--level', 'bad']),
                              ('scan.sh', ['--oops']), ('review-change.sh', ['--bad'])]:
            self.run_cli('scripts/' + command, *args, expected=2)
        self.assertEqual(self.git('status', '--porcelain').stdout, before)
        self.assertFalse((self.root / '.harness').exists())
        self.assertFalse((self.root / '.git/miri-harness').exists())

    def test_hooks_refuse_shared_or_foreign_configuration(self):
        result = self.run_cli('scripts/setup.sh', '--install-hooks', expected=2)
        self.assertIn('extensions.worktreeConfig true', result.stderr)
        self.assertEqual(self.git('config', '--get', 'core.hooksPath', check=False).returncode, 1)
        self.git('config', 'extensions.worktreeConfig', 'true')
        self.git('config', '--worktree', 'core.hooksPath', '/foreign/hooks')
        self.run_cli('scripts/setup.sh', '--install-hooks', expected=2)
        self.assertEqual(self.git('config', '--get', 'core.hooksPath').stdout.strip(), '/foreign/hooks')

    def test_linked_worktree_installer_preserves_main_sibling_and_shared_hooks(self):
        self.git('config', 'extensions.worktreeConfig', 'true')
        sibling = Path(self.temp.name) / 'sibling'
        target = Path(self.temp.name) / 'target'
        self.git('worktree', 'add', '-q', '-b', 'sibling', str(sibling))
        self.git('worktree', 'add', '-q', '-b', 'target', str(target))
        hooks = self.root / '.git/hooks'
        before = {p.name: p.read_bytes() for p in hooks.iterdir() if p.is_file()}
        for _ in range(2):
            self.run_cli('scripts/setup.sh', '--install-hooks', root=target)
        self.assertEqual(self.git('config', '--get', 'core.hooksPath', root=target).stdout.strip(), str(target.resolve() / '.githooks'))
        for other in [self.root, sibling]:
            self.assertEqual(self.git('config', '--get', 'core.hooksPath', root=other, check=False).returncode, 1)
        self.assertEqual({p.name: p.read_bytes() for p in hooks.iterdir() if p.is_file()}, before)
        self.run_cli('scripts/setup.sh', '--profile', 'portable', root=target)
        self.assertFalse((self.root / '.git/miri-harness').exists())
        self.assertTrue((self.root / '.git/worktrees/target/miri-harness/portable.json').exists())

    def test_guard_installer_preserves_unrelated_settings_and_is_idempotent(self):
        original = {'permissions': {'allow': ['Bash(git status)']}, 'hooks': {'PreToolUse': [
            {'matcher': 'Read', 'hooks': [{'type': 'command', 'command': 'foreign-read-hook'}]}]}}
        path = self.write('.claude/settings.local.json', json.dumps(original))
        self.run_cli('scripts/setup.sh', '--enable-claude-guard')
        saved = path.read_bytes()
        settings = json.loads(saved)
        self.assertEqual(settings['permissions'], original['permissions'])
        self.assertEqual(settings['hooks']['PreToolUse'][0], original['hooks']['PreToolUse'][0])
        self.assertEqual(len(settings['hooks']['PreToolUse']), 2)
        self.run_cli('scripts/setup.sh', '--enable-claude-guard')
        self.assertEqual(path.read_bytes(), saved)

    def test_guard_installer_rejects_malformed_foreign_and_symlink_settings(self):
        for text in ['{broken', '[]', '{"hooks": []}', '{"hooks":{"PreToolUse":[{}]}}',
                     '{"hooks":{"PreToolUse":[{"hooks":[{"command":"foreign/guard-command.sh"}]}]}}']:
            path = self.write('.claude/settings.local.json', text)
            self.run_cli('scripts/setup.sh', '--enable-claude-guard', expected=2)
            self.assertEqual(path.read_text(), text)
        path.unlink()
        outside = Path(self.temp.name) / 'foreign.json'
        outside.write_text('{}')
        path.symlink_to(outside)
        self.run_cli('scripts/setup.sh', '--enable-claude-guard', expected=2)
        self.assertEqual(outside.read_text(), '{}')

    def test_repo_checks_map_and_immutable_files(self):
        self.run_cli('scripts/verify.sh', '--level', 'repo')
        summary = self.summaries()[-1]
        self.assertEqual(summary['status'], 'passed')
        self.assertEqual(summary['requested_level'], 'repo')
        self.assertEqual([c['id'] for c in summary['checks']], ['repository'])
        self.write('docs/new-topic/spaced name.md', 'Read this file.\n')
        result = self.run_cli('scripts/verify.sh', '--level', 'repo', expected=1)
        self.assertIn('Unmapped path', result.stdout)
        (self.root / 'docs/new-topic/spaced name.md').unlink()
        self.write('scripts/lib/ste_lint.LICENSE', 'Changed license\n')
        result = self.run_cli('scripts/verify.sh', '--level', 'repo', expected=1)
        self.assertIn('Vendored upstream hash changed', result.stdout)

    def test_missing_map_path_and_invalid_hook_fail(self):
        (self.root / 'docs/agents').rename(self.root / 'docs/agents-moved')
        result = self.run_cli('scripts/verify.sh', '--level', 'repo', expected=1)
        self.assertIn('Missing or escaping map path', result.stdout)
        (self.root / 'docs/agents-moved').rename(self.root / 'docs/agents')
        (self.root / 'scripts/restore-state.sh').chmod(0o644)
        result = self.run_cli('scripts/verify.sh', '--level', 'repo', expected=1)
        self.assertIn('Hook is not executable', result.stdout)

    def test_failed_check_keeps_exit_log_and_later_not_run(self):
        self.setup_portable()
        self.write('scripts/test-harness.py', "print('intentional fixture failure')\nraise SystemExit(7)\n")
        result = self.run_cli('scripts/verify.sh', expected=7)
        summary = self.summaries()[-1]
        self.assertEqual(summary['status'], 'failed')
        checks = {c['id']: c for c in summary['checks']}
        self.assertEqual(checks['harness-tests']['exit_code'], 7)
        self.assertEqual(checks['writing-tests']['status'], 'not_run')
        self.assertIn('intentional fixture failure', result.stdout)
        self.assertEqual(summary['scope'], 'working-tree')
        self.assertEqual(summary['source']['head'], self.git('rev-parse', 'HEAD').stdout.strip())
        self.assertTrue(summary['environment_fingerprint'])

    def test_dirty_handoff_and_stale_evidence_preserve_work(self):
        self.write('README.md', 'Uncommitted changes.\n')
        self.run_cli('scripts/end-session.sh', '--level', 'repo', '--note', 'Native checks pending.')
        summary = self.summaries()[-1]
        self.assertEqual(summary['handoff']['note'], 'Native checks pending.')
        self.assertIn('README.md', summary['handoff']['dirty'])
        self.assertIn('current. passed at level repo', self.run_cli('scripts/restore-state.sh').stdout)
        self.write('README.md', 'Later uncommitted changes.\n')
        self.assertIn('stale. passed at level repo', self.run_cli('scripts/restore-state.sh').stdout)
        self.assertEqual((self.root / 'README.md').read_text(), 'Later uncommitted changes.\n')

    def test_restore_revalidates_live_tools(self):
        self.run_cli('scripts/verify.sh', '--level', 'repo')
        self.stub_tool('bash', 'if [[ "$1" == --version ]]; then echo "GNU bash, version 99.0"; else exec /bin/bash "$@"; fi')
        self.assertIn('stale.', self.run_cli('scripts/restore-state.sh').stdout)

    def test_unique_concurrent_portable_runs(self):
        self.setup_portable()
        processes = [subprocess.Popen(['scripts/verify.sh', '--level', 'repo'], cwd=self.root, env=self.env,
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) for _ in range(2)]
        for process in processes:
            output = process.communicate(timeout=30)[0]
            self.assertEqual(process.returncode, 0, output)
        summaries = self.summaries()
        self.assertEqual(len(summaries), 2)
        self.assertNotEqual(summaries[0]['run'], summaries[1]['run'])
        self.assertTrue(all(s['status'] == 'passed' for s in summaries))

    def test_interruption_retains_summary_and_stops_owned_child(self):
        self.setup_portable()
        self.write('scripts/test-harness.py', "import os, time\nfrom pathlib import Path\nPath('.harness/child.pid').write_text(str(os.getpid()))\ntime.sleep(60)\n")
        process = subprocess.Popen(['scripts/verify.sh'], cwd=self.root, env=self.env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.addCleanup(lambda: process.poll() is None and process.kill())
        self.wait_for(lambda: (self.root / '.harness/child.pid').exists())
        child = int((self.root / '.harness/child.pid').read_text())
        process.terminate()
        output = process.communicate(timeout=15)[0]
        self.assertEqual(process.returncode, 143, output)
        summary = self.summaries()[-1]
        self.assertEqual(summary['status'], 'interrupted')
        self.assertEqual(next(c for c in summary['checks'] if c['id'] == 'harness-tests')['status'], 'interrupted')
        with self.assertRaises(ProcessLookupError):
            os.kill(child, 0)

    def test_native_lock_refuses_another_owner_and_does_not_remove_it(self):
        self.setup_portable()
        self.write('scripts/check-ready.sh', '#!/bin/bash\nexit 0\n', executable=True)
        self.write('scripts/test-ste.py', "print('Fixture writing workload passed')\n")
        self.write('scripts/test-guard-command.sh', '#!/bin/bash\nexit 0\n', executable=True)
        self.stub_tool('cargo', 'if [[ "$1" == --version ]]; then echo "cargo 1.95.0"; else exit 0; fi')
        self.stub_tool('rustc', 'echo "rustc 1.95.0"')
        self.write('scripts/build-prototype.sh', '#!/bin/bash\nexit 0\n', executable=True)
        lock = self.root / '.harness/native.lock'
        lock.mkdir(parents=True)
        owner = {'pid': os.getpid(), 'run': 'foreign-run'}
        (lock / 'owner.json').write_text(json.dumps(owner))
        result = self.run_cli('scripts/verify.sh', '--level', 'build', expected=3)
        self.assertIn('owned by another run', result.stdout)
        self.assertEqual(json.loads((lock / 'owner.json').read_text()), owner)
        summary = self.summaries()[-1]
        self.assertEqual(next(c for c in summary['checks'] if c['id'] == 'engine-format')['status'], 'not_run')

    def test_native_unavailable_never_becomes_passed(self):
        self.setup_portable()
        self.write('scripts/test-ste.py', "print('Fixture writing workload passed')\n")
        self.write('scripts/test-guard-command.sh', '#!/bin/bash\nexit 0\n', executable=True)
        result = self.run_cli('scripts/verify.sh', '--level', 'build', expected=3)
        summary = self.summaries()[-1]
        self.assertEqual(summary['status'], 'unavailable')
        self.assertEqual(next(c for c in summary['checks'] if c['id'] == 'native-ready')['status'], 'unavailable')
        self.assertEqual(next(c for c in summary['checks'] if c['id'] == 'package')['status'], 'not_run')
        self.assertTrue('uninitialized' in result.stdout or 'require macOS' in result.stdout)

    def test_readiness_rejects_unsupported_sdk_without_engine_mutation(self):
        if platform.system() != 'Darwin' or platform.machine() != 'arm64':
            result = self.run_cli('scripts/setup.sh', '--profile', 'native', expected=3)
            self.assertIn('require macOS', result.stderr)
        else:
            self.stub_tool('xcrun', 'echo "26.0"')
            result = self.run_cli('scripts/setup.sh', '--profile', 'native', expected=3)
            self.assertIn('xcrun requires at least 27.0.0', result.stderr)
        self.assertFalse((self.root / 'vendor/paneru/.git').exists())
        self.assertFalse((self.root / '.git/miri-harness/native.json').exists())


if __name__ == '__main__':
    unittest.main()
