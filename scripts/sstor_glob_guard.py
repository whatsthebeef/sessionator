#!/usr/bin/env python3
"""Claude Code PreToolUse hook (Bash): keeps an sstor instance on its own glob.

An instance records its glob in <worktree>/.sstor/glob. This blocks `git checkout`, `git switch`
and `git worktree add` to a branch that is a different glob ID than that file. Where the file is
absent (routines, plain checkouts) it does nothing.

Reads the hook JSON on stdin; exits 2 with the message on stderr to block.
"""

from __future__ import annotations

import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

GLOB_ID = re.compile(r'^s[1-9][0-9]*[ftbh][1-9][0-9]*$')
BRANCH_FLAGS = {'-b', '-B', '-c', '-C', '--orphan'}
SEPARATORS = {';', '&&', '||', '|', '&', '\n'}


def recorded_glob(cwd: Path) -> str | None:
    top = subprocess.run(['git', 'rev-parse', '--show-toplevel'], cwd=cwd, capture_output=True, text=True)
    if top.returncode != 0:
        return None
    marker = Path(top.stdout.strip()) / '.sstor' / 'glob'
    try:
        return marker.read_text().strip() or None
    except OSError:
        return None


def segments(command: str) -> list[list[str]]:
    lexer = shlex.shlex(command, posix=True, punctuation_chars=';&|')
    lexer.whitespace_split = True
    lexer.whitespace = ' \t\r\n'
    try:
        tokens = list(lexer)
    except ValueError:
        tokens = command.split()
    result: list[list[str]] = [[]]
    for token in tokens:
        if token in SEPARATORS or set(token) <= set(';&|'):
            result.append([])
        else:
            result[-1].append(token)
    return [seg for seg in result if seg]


def targets(segment: list[str]) -> list[str]:
    """The branch names a git checkout / switch / worktree add segment would use."""
    if segment[0] != 'git':
        return []
    rest = segment[1:]
    while rest and rest[0].startswith('-'):  # git -C <dir> / -c k=v / --no-pager
        rest = rest[2:] if rest[0] in ('-C', '-c', '--git-dir', '--work-tree') else rest[1:]
    if not rest:
        return []
    if rest[0] in ('checkout', 'switch'):
        skip_first = False
    elif rest[0] == 'worktree' and len(rest) > 1 and rest[1] == 'add':
        rest, skip_first = rest[1:], True  # the first positional is the new path
    else:
        return []
    found: list[str] = []
    positionals = 0
    args = iter(rest[1:])
    for arg in args:
        if arg == '--':
            break
        if arg in BRANCH_FLAGS:
            value = next(args, None)
            if value:
                found.append(value)
        elif arg.startswith('-'):
            continue
        else:
            positionals += 1
            if not (skip_first and positionals == 1):
                found.append(arg)
    return found


def glob_of(name: str) -> str | None:
    name = name.removeprefix('origin/').removeprefix('refs/heads/').removeprefix('refs/remotes/origin/')
    return name if GLOB_ID.match(name) else None


def main() -> None:
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return
    command = (event.get('tool_input') or {}).get('command')
    if not isinstance(command, str):
        return
    mine = recorded_glob(Path(event.get('cwd') or '.'))
    if not mine:
        return
    for segment in segments(command):
        for name in targets(segment):
            other = glob_of(name)
            if other and other != mine:
                print(f'This instance is for {mine}. Start other work with `sstor --glob {other}` and hand over in that glob\'s summary.', file=sys.stderr)
                sys.exit(2)


if __name__ == '__main__':
    main()
