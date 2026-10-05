#!/usr/bin/env python3
"""sstor's /finalise handshake with the Claude session in a glob's tmux window.

The bash `sstor` script owns worktrees and tmux and calls the slop CLI for everything that talks
to slop; this helper only runs /finalise in the session (or checks that Claude already ran it)
before sstor marks the glob ready or merges it.

  check <worktree> <session> <glob> [--finalised R]
      fails at once, naming where the glob's branch is checked out, unless the worktree is on the
      glob's branch and (without --finalised) Claude is running in <session>:claude.

  finalise <worktree> <session> [--finalised R]
      sends `/finalise <request>` to <session>:claude and waits for .sstor/.finalised to hold
      that request and the current commit; with --finalised R, only checks the marker for R.
      Prints the request ID on stdout (progress goes to stderr).
"""

from __future__ import annotations

import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import NoReturn

FINALISE_TIMEOUT_S = 20 * 60


def fail(message: str, code: int = 1) -> NoReturn:
    print(f'sstor: {message}', file=sys.stderr)
    sys.exit(code)


def git(cwd: Path, *args: str) -> str:
    result = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        fail(f'git {" ".join(args)} failed: {result.stderr.strip()}')
    return result.stdout.strip()


SHELLS = {'bash', 'zsh', 'sh', 'fish', 'dash', 'ksh', 'tcsh', 'login', '-bash', '-zsh', '-sh'}


def where_checked_out(worktree: Path, glob: str) -> str:
    listing = subprocess.run(['git', 'worktree', 'list'], cwd=worktree, capture_output=True, text=True).stdout.strip()
    porcelain = subprocess.run(['git', 'worktree', 'list', '--porcelain'], cwd=worktree, capture_output=True, text=True).stdout
    path = None
    for line in porcelain.splitlines():
        if line.startswith('worktree '):
            path = line[len('worktree ') :]
        elif line == f'branch refs/heads/{glob}':
            return f'{glob} is checked out in {path}'
    return f'{glob} is not checked out in any worktree. Worktrees:\n{listing}'


def check(worktree: Path, session: str, glob: str, need_claude: bool) -> None:
    """Stops straight away when /finalise could never complete: the worktree is off the glob's
    branch, or nothing is running Claude in the session's claude window."""
    branch = subprocess.run(['git', 'symbolic-ref', '--quiet', '--short', 'HEAD'], cwd=worktree, capture_output=True, text=True).stdout.strip()
    if branch != glob:
        fail(f"the worktree {worktree} is on '{branch or 'a detached HEAD'}', not {glob}. {where_checked_out(worktree, glob)}. Nothing was done")
    if not need_claude:
        return
    target = f'{session}:claude'
    shown = subprocess.run(['tmux', 'display', '-p', '-t', target, '#{pane_current_command}'], capture_output=True, text=True)
    command = shown.stdout.strip()
    if shown.returncode != 0 or not command or command in SHELLS:
        reason = f"no window {target}" if shown.returncode != 0 else f'{target} is running {command or "nothing"}, not Claude'
        fail(f'{reason}. Start Claude there (claude --continue), or run /finalise yourself and pass --finalised <id>. '
             f'{where_checked_out(worktree, glob)}. Nothing was done')


def finalise(worktree: Path, session: str, request: str | None) -> str:
    """Runs /finalise in the session (unless Claude already did), checks its marker and returns
    the request ID."""
    marker = worktree / '.sstor' / '.finalised'
    head = git(worktree, 'rev-parse', 'HEAD')
    if request is None:
        request = str(uuid.uuid4())
        marker.unlink(missing_ok=True)
        target = f'{session}:claude'
        sent = subprocess.run(['tmux', 'send-keys', '-t', target, f'/finalise {request}', 'C-m'], capture_output=True)
        if sent.returncode != 0:
            fail(f'could not reach the Claude window ({target}); run /finalise there and pass --finalised <id>')
        print(f'sstor: waiting for /finalise {request} in {target}...', file=sys.stderr)
        deadline = time.time() + FINALISE_TIMEOUT_S
        while not marker.exists():
            if time.time() > deadline:
                fail('timed out waiting for /finalise; nothing was marked ready or merged')
            time.sleep(3)
        time.sleep(1)
        head = git(worktree, 'rev-parse', 'HEAD')
    lines = marker.read_text().split() if marker.exists() else []
    if lines[:2] != [request, head]:
        fail('the finalise marker does not match this request and the current commit; run /finalise again')
    return request


def main() -> None:
    args = sys.argv[1:]
    request = None
    if '--finalised' in args:
        index = args.index('--finalised')
        if index + 1 >= len(args):
            fail('--finalised needs the /finalise request ID', 2)
        request = args[index + 1]
        del args[index : index + 2]
    if len(args) == 4 and args[0] == 'check':
        check(Path(args[1]), args[2], args[3], need_claude=request is None)
        return
    if len(args) != 3 or args[0] != 'finalise':
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    print(finalise(Path(args[1]), args[2], request))  # sstor names it if a later slop step fails


if __name__ == '__main__':
    main()
