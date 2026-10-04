#!/usr/bin/env python3
"""sstor's slop flows: pick up, create, finalise, mark ready and merge globs.

The bash `sstor` script owns worktrees and tmux; this helper talks to slop (through
slop_mcp, with the developer's own login), GitHub (`gh`) and the running Claude session.

  prepare <id> [--take-over]                  pick up the glob and wait for its branch; prints ID=, TITLE=, TYPE=
  new [--type T] [--category C] [--routine] <prompt>   create a glob through intake; prints ID=, TYPE=, STATUS=
  ready <worktree> <session> [--finalised R]  finalise, push and mark the PR ready
  merge <worktree> <session> [--finalised R]  finalise, then squash-merge the PR on GitHub
"""

from __future__ import annotations

import json
import shlex
import subprocess
import sys
import time
import uuid
from pathlib import Path
from typing import NoReturn

sys.path.insert(0, str(Path(__file__).resolve().parent))
import slop_mcp  # noqa: E402  # pyright: ignore[reportMissingImports]

FINALISE_TIMEOUT_S = 20 * 60
PROVISION_TIMEOUT_S = 120


def fail(message: str, code: int = 1) -> NoReturn:
    print(f'sstor: {message}', file=sys.stderr)
    sys.exit(code)


def shell_vars(**values: object) -> None:
    for key, value in values.items():
        print(f'{key}={shlex.quote(str(value))}')


def git(cwd: Path, *args: str) -> str:
    result = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        fail(f'git {" ".join(args)} failed: {result.stderr.strip()}')
    return result.stdout.strip()


def board_of(root: Path) -> int:
    board = slop_mcp.read_conf(root).get('SLOP_BOARD', '')
    if not board.isdigit():
        fail('add SLOP_BOARD=<board id> to .sstor/sstor.conf')
    return int(board)


def busy_run(glob: dict) -> dict | None:
    run = glob.get('currentRun')
    return run if run and run.get('state') in ('active', 'watching') else None


def prepare(root: Path, glob_id: str, take_over: bool) -> None:
    """Checks the glob, picks it up (provisioning its branch if needed) and waits for the branch."""
    try:
        glob = slop_mcp.call(root, 'get_glob', {'id': glob_id})
        run = busy_run(glob)
        if run and not take_over:
            fail(
                f'{glob_id} has a routine run {run["state"]} (owner {run.get("routineOwner")}). '
                f'Use --take-over to supersede it, or watch it: {run.get("sessionUrl") or "the glob view"}',
                3,
            )
        if glob['status'] in ('reviewing', 'signed_off'):
            fail(f'{glob_id} is already merged ({glob["status"]})')
        me = slop_mcp.call(root, 'whoami', {})['email']
        if glob.get('implementer') != me or take_over:
            glob = slop_mcp.call(root, 'pick_up', {'id': glob_id, 'version': glob['version'], 'takeOver': take_over})
        deadline = time.time() + PROVISION_TIMEOUT_S
        while glob.get('provisioning') != 'ok':
            if glob.get('provisioning') == 'failed' or time.time() > deadline:
                fail(f'{glob_id} has no branch yet (provisioning: {glob.get("provisioning")}); check the glob view')
            time.sleep(3)
            glob = slop_mcp.call(root, 'get_glob', {'id': glob_id})
    except slop_mcp.SlopError as error:
        fail(str(error))
    shell_vars(ID=glob['id'], TITLE=glob['title'], TYPE=glob['type'])


def new(root: Path, prompt: str, slop_type: str | None, category: str | None, routine: bool) -> None:
    arguments: dict = {'board': board_of(root), 'idempotencyKey': str(uuid.uuid4()), 'input': prompt}
    if slop_type:
        arguments['type'] = slop_type
    if category:
        arguments['category'] = category
    if routine:
        arguments['autoTrigger'] = True
    try:
        glob = slop_mcp.call(root, 'create_glob', arguments)
    except slop_mcp.SlopError as error:
        fail(str(error))
    print(f'sstor: created {glob["id"]} ({glob["type"]}, {glob["category"]}): {glob["status"]}', file=sys.stderr)
    shell_vars(ID=glob['id'], TYPE=glob['type'], STATUS=glob['status'])


def finalise(worktree: Path, session: str, request: str | None) -> str:
    """Runs /finalise in the session (unless Claude already did) and checks its marker."""
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
    return head


def ready(worktree: Path, session: str, request: str | None) -> None:
    glob_id = git(worktree, 'branch', '--show-current')
    finalise(worktree, session, request)
    git(worktree, 'push', 'origin', glob_id)
    try:
        slop_mcp.call(worktree, 'mark_ready', {'id': glob_id})
    except slop_mcp.SlopError as error:
        fail(str(error))
    print(f'sstor: {glob_id} pushed and marked ready for review', file=sys.stderr)


def merge(worktree: Path, session: str, request: str | None) -> None:
    glob_id = git(worktree, 'branch', '--show-current')
    finalise(worktree, session, request)
    view = subprocess.run(['gh', 'pr', 'view', glob_id, '--json', 'title,isDraft,state'], cwd=worktree, capture_output=True, text=True)
    if view.returncode != 0:
        fail(f'could not find the PR for {glob_id}: {view.stderr.strip()}')
    pr = json.loads(view.stdout)
    if pr['isDraft']:
        fail(f'the PR for {glob_id} is still a draft; run sstor --ready first')
    # Squash only; the title is already `<id>: <title>`. Required checks are enforced by GitHub.
    merged = subprocess.run(
        ['gh', 'pr', 'merge', glob_id, '--squash', '--subject', pr['title'], '--body', ''],
        cwd=worktree,
        capture_output=True,
        text=True,
    )
    if merged.returncode != 0:
        fail(f'GitHub refused the merge: {merged.stderr.strip()}')
    print(f'sstor: {glob_id} squash-merged as "{pr["title"]}"', file=sys.stderr)


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    command, rest = args[0], args[1:]
    root = Path(subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True).stdout.strip() or '.')

    def option(name: str) -> str | None:
        if name in rest:
            index = rest.index(name)
            value = rest[index + 1] if index + 1 < len(rest) else None
            del rest[index : index + 2]
            return value
        return None

    def flag(name: str) -> bool:
        if name in rest:
            rest.remove(name)
            return True
        return False

    if command == 'prepare' and rest:
        take_over = flag('--take-over')
        prepare(root, rest[0], take_over)
    elif command == 'new':
        slop_type, category, routine = option('--type'), option('--category'), flag('--routine')
        if not rest:
            fail('sstor --new needs a prompt')
        new(root, ' '.join(rest), slop_type, category, routine)
    elif command in ('ready', 'merge') and len(rest) >= 2:
        request = option('--finalised')
        (ready if command == 'ready' else merge)(Path(rest[0]), rest[1], request)
    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
