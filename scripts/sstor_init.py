#!/usr/bin/env python3
"""sstor init's own part: merge the developer's personal Claude settings into a checkout.

`slop init` installs the board's agent set (agents, commands, hooks, settings.json, CLAUDE.md).
Personal settings never come from slop: they live in sessionator's own
.claude/settings.local.json and are merged into the checkout's .claude/settings.local.json:

  env                 set from the source (TASK_APP_URL skipped)
  permissions.allow   union (mcp__atlassian* skipped)
  sandbox             deep merge: lists unioned, scalars set only where missing
                      (mcp.atlassian.com dropped)

Skipped when the source is missing or is the target itself. The target is written atomically and
kept out of git through the repo's untracked info/exclude (never a tracked .gitignore).

Usage: sstor_init.py <source settings.local.json> <checkout>
"""

from __future__ import annotations

import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import NoReturn

TARGET = Path('.claude') / 'settings.local.json'
SKIP_ENV = {'TASK_APP_URL'}
SKIP_PERMISSION_PREFIX = 'mcp__atlassian'
SKIP_SANDBOX_VALUES = {'mcp.atlassian.com'}


def fail(message: str) -> NoReturn:
    print(f'sstor init: {message}', file=sys.stderr)
    sys.exit(1)


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        fail(f'{path} is not valid JSON: {error}')
    if not isinstance(value, dict):
        fail(f'{path} is not a JSON object')
    check_shape(path, value)
    return value


def check_shape(path: Path, settings: dict) -> None:
    """The parts the merge touches must have the shapes Claude Code uses."""
    for key in ('env', 'permissions', 'sandbox'):
        if key in settings and not isinstance(settings[key], dict):
            fail(f'{path}: "{key}" must be a JSON object')
    allow = settings.get('permissions', {}).get('allow', [])
    if not isinstance(allow, list) or not all(isinstance(p, str) for p in allow):
        fail(f'{path}: "permissions.allow" must be a list of strings')


def union(current: list, incoming: list) -> list:
    return current + [item for item in incoming if item not in current]


def merge_sandbox(current: dict, incoming: dict) -> dict:
    merged = dict(current)
    for key, value in incoming.items():
        if isinstance(value, dict):
            if key not in merged:
                merged[key] = merge_sandbox({}, value)
            elif isinstance(merged[key], dict):
                merged[key] = merge_sandbox(merged[key], value)
        elif isinstance(value, list):
            kept = [item for item in value if item not in SKIP_SANDBOX_VALUES]
            if key not in merged:
                merged[key] = kept
            elif isinstance(merged[key], list):
                merged[key] = union(merged[key], kept)
        elif key not in merged:
            merged[key] = value
    return merged


def merge_local(current: dict, source: dict) -> dict:
    merged = dict(current)
    env = {k: v for k, v in source.get('env', {}).items() if k not in SKIP_ENV}
    if env:
        merged['env'] = {**merged.get('env', {}), **env}
    allow = [p for p in source.get('permissions', {}).get('allow', []) if not p.startswith(SKIP_PERMISSION_PREFIX)]
    if allow:
        permissions = dict(merged.get('permissions', {}))
        permissions['allow'] = union(permissions.get('allow', []), allow)
        merged['permissions'] = permissions
    if isinstance(source.get('sandbox'), dict):
        merged['sandbox'] = merge_sandbox(merged.get('sandbox', {}), source['sandbox'])
    return merged


def write_atomically(path: Path, text: str) -> None:
    """Writes through a temp file in the same folder, so an interrupted write never truncates it."""
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else None
    handle, temp = tempfile.mkstemp(dir=path.parent, prefix=f'.{path.name}.', suffix='.tmp')
    try:
        with os.fdopen(handle, 'w') as file:
            file.write(text)
        if mode is not None:
            os.chmod(temp, mode)
        os.replace(temp, path)
    except BaseException:
        Path(temp).unlink(missing_ok=True)
        raise


def ensure_ignored(root: Path) -> None:
    """Keeps the target out of git through the repo's untracked info/exclude (shared by its
    worktrees), unless git already ignores it. A tracked .gitignore is never touched."""
    checked = subprocess.run(['git', 'check-ignore', '-q', str(TARGET)], cwd=root, capture_output=True)
    if checked.returncode != 1:  # 0: already ignored; 128: not a git checkout
        return
    common = subprocess.run(['git', 'rev-parse', '--git-common-dir'], cwd=root, capture_output=True, text=True)
    if common.returncode != 0:
        return
    git_dir = Path(common.stdout.strip())
    exclude = (git_dir if git_dir.is_absolute() else root / git_dir) / 'info' / 'exclude'
    text = exclude.read_text() if exclude.exists() else ''
    exclude.parent.mkdir(parents=True, exist_ok=True)
    exclude.write_text(text + ('' if text.endswith('\n') or not text else '\n') + f'/{TARGET}\n')


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    source_path, root = Path(sys.argv[1]), Path(sys.argv[2])
    target_path = root / TARGET
    if not source_path.is_file():
        return
    if target_path.exists() and os.path.samefile(source_path, target_path):
        return
    current = read_json(target_path) if target_path.exists() else {}
    merged = merge_local(current, read_json(source_path))
    if merged != current or not target_path.exists():
        write_atomically(target_path, json.dumps(merged, indent=2) + '\n')
        print(f'sstor init: merged your personal settings into {TARGET}')
    ensure_ignored(root)


if __name__ == '__main__':
    main()
