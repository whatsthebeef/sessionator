#!/usr/bin/env python3
"""sstor's /finalise handshake with the Claude session in a glob's tmux window.

The bash `sstor` script owns worktrees and tmux and calls the slop CLI for everything that talks
to slop; this helper only runs /finalise in the session (or checks that Claude already ran it)
before sstor marks the glob ready or merges it.

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
    if len(args) != 3 or args[0] != 'finalise':
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    print(finalise(Path(args[1]), args[2], request))  # sstor names it if a later slop step fails


if __name__ == '__main__':
    main()
