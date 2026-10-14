#!/usr/bin/env python3
"""A convenience guard for common destructive commands, not a shell sandbox."""
import json
import os
from pathlib import Path
import re
import shlex
import sys


def check(command, depth=0):
    if depth > 8:
        raise ValueError('Shell wrapper nesting is too deep to inspect.')
    lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|\n')
    lexer.whitespace = ' \t\r'
    lexer.whitespace_split = True
    segments = [[]]
    for token in lexer:
        if token and all(character in ';&|\n' for character in token):
            segments.append([])
        else:
            segments[-1].append(token)
    for tokens in segments:
        while tokens and (re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*=.*', tokens[0]) or
                          tokens[0] in ['sudo', 'env', 'command', 'exec']):
            tokens.pop(0)
        if not tokens:
            continue
        name = Path(tokens[0]).name
        args = tokens[1:]
        if name in ['bash', 'sh', 'zsh']:
            for index, arg in enumerate(args[:-1]):
                if arg.startswith('-') and 'c' in arg:
                    check(args[index + 1], depth + 1)
                    break
        elif name == 'git':
            if '--no-verify' in args or any('core.hooksPath' in arg for arg in args):
                raise ValueError('The command skips Git hooks. Fix scripts/verify.sh findings and commit normally.')
            if 'push' in args:
                options = args[args.index('push') + 1:]
                if any(arg in ['-f', '--force'] or arg.startswith('+') for arg in options):
                    raise ValueError('The command forces a push. Push a new commit or use --force-with-lease on your feature branch.')
                if any(arg.startswith('--force-with-lease') for arg in options) and any(
                        re.search(r'(^|[:/])(main|master)$', arg) for arg in options):
                    raise ValueError('The command forces main or master. Open a pull request with a new commit.')
        elif name == 'rm':
            recursive = any(arg == '--recursive' or arg.startswith('-') and not arg.startswith('--') and ('r' in arg or 'R' in arg) for arg in args)
            roots = {'/', '/*', '~', '~/', '~/*', '$HOME', '$HOME/', '$HOME/*',
                     '${HOME}', '${HOME}/', '${HOME}/*', os.path.expanduser('~'), os.path.expanduser('~') + '/'}
            if recursive and any(arg in roots for arg in args):
                raise ValueError('The command recursively deletes the filesystem root or home directory. Name the specific directory to delete.')


def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--command':
        command = sys.argv[2]
    elif len(sys.argv) == 1:
        data = json.load(sys.stdin)
        command = data['tool_input']['command']
        if not isinstance(command, str):
            raise ValueError('tool_input.command must be a string.')
    else:
        raise ValueError('Usage: guard-command.sh [--command COMMAND]')
    check(command)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, KeyError, TypeError, OSError) as error:
        print('guard: blocked: ' + str(error), file=sys.stderr)
        sys.exit(2)
