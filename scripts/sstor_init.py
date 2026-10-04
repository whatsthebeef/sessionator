#!/usr/bin/env python3
"""sstor init: install the board's agent set from slop into the current checkout.

sstor holds no slop credential. It asks Claude Code (headless, `claude -p`) to call slop's
`get_agent_set` tool with the developer's own OAuth login, reads the tool result from the
stream (a short-lived signed download link), and fetches the bundle with that link.

Usage: sstor init [board]
  board: argument, $SLOP_BOARD, or SLOP_BOARD in .sstor/sstor.conf
  server: $SLOP_MCP_SERVER, SLOP_MCP_SERVER in .sstor/sstor.conf, or "slop"
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import NoReturn

MANIFEST = Path('.claude/slop-agent-set.json')
MARKER = '<!-- implementation-agent-system -->'
MARKER_END = '<!-- /implementation-agent-system -->'

# Files the Jira-era agent system installed; removed on the first run.
LEGACY_FILES = [
    '.claude/agents/qa.md',
    '.claude/agents/unit_test_writer.md',
    '.claude/commands/run-task.md',
    '.claude/commands/deploy.sh',
    '.claude/skills/run-task.md',
    '.claude/skills/deploy.sh',
    '.claude/memory/workflow_config.md',
]
LEGACY_DIRS = ['.claude/agents/docs']


def fail(message: str) -> NoReturn:
    print(f'sstor init: {message}', file=sys.stderr)
    sys.exit(1)


def warn(message: str) -> None:
    print(f'sstor init: warning: {message}', file=sys.stderr)


def git_root() -> Path:
    result = subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True)
    if result.returncode != 0:
        fail('run this inside a git checkout')
    return Path(result.stdout.strip())


def read_conf(root: Path) -> dict[str, str]:
    conf: dict[str, str] = {}
    path = root / '.sstor' / 'sstor.conf'
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                conf[key.strip()] = value.strip().strip('"').strip("'")
    return conf


def tool_result(stream: str, tool: str) -> str:
    """The text of the named tool's result in a `claude -p --output-format stream-json` stream."""
    names: dict[str, str] = {}
    for line in stream.splitlines():
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if message.get('type') not in ('assistant', 'user'):
            continue
        for block in message.get('message', {}).get('content', []):
            if not isinstance(block, dict):
                continue
            if block.get('type') == 'tool_use':
                names[block['id']] = block['name']
            elif block.get('type') == 'tool_result' and names.get(str(block.get('tool_use_id', ''))) == tool:
                content = block.get('content')
                text = content if isinstance(content, str) else ''.join(
                    part.get('text', '') for part in content or [] if isinstance(part, dict)
                )
                if block.get('is_error'):
                    raise RuntimeError(text.strip() or f'{tool} failed')
                return text
    raise RuntimeError(f'{tool} was not called; is the "{tool.split("__")[1]}" MCP server set up and signed in?')


def fetch_bundle(root: Path, server: str, board: str) -> dict:
    tool = f'mcp__{server}__get_agent_set'
    prompt = f'Call the tool {tool} exactly (not any other server\'s tool) with board {board} and download true, then reply with just OK.'
    try:
        result = subprocess.run(
            ['claude', '-p', prompt, '--allowedTools', tool, '--output-format', 'stream-json', '--verbose'],
            cwd=root,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        raise RuntimeError(f'could not run claude: {error}') from error
    link = json.loads(tool_result(result.stdout, tool))
    with urllib.request.urlopen(link['url'], timeout=60) as response:  # noqa: S310 (slop's signed link)
        bundle = json.loads(response.read())
    if not isinstance(bundle.get('files'), list):
        raise RuntimeError('slop returned an unexpected bundle')
    return bundle


def target_of(path: str) -> str | None:
    """Where a bundle file is written in the checkout; merged files return None."""
    if path.startswith(('agents/', 'commands/', 'hooks/')):
        return f'.claude/{path}'
    return None


def merge_settings(root: Path, incoming: dict, first_run: bool) -> None:
    path = root / '.claude' / 'settings.json'
    current = json.loads(path.read_text()) if path.exists() else {}
    if first_run:
        current.get('mcpServers', {}).pop('atlassian-rovo', None)
        if not current.get('mcpServers'):
            current.pop('mcpServers', None)
        current.get('env', {}).pop('TASK_APP_URL', None)
        allow = current.get('permissions', {}).get('allow')
        if isinstance(allow, list):
            current['permissions']['allow'] = [p for p in allow if not p.startswith('mcp__atlassian')]
    for key, value in incoming.get('env', {}).items():
        current.setdefault('env', {})[key] = value
    permissions = current.setdefault('permissions', {})
    for kind in ('allow', 'deny'):
        merged = sorted(set(permissions.get(kind, [])) | set(incoming.get('permissions', {}).get(kind, [])))
        if merged:
            permissions[kind] = merged
    if 'sandbox' in incoming and 'sandbox' not in current:
        current['sandbox'] = incoming['sandbox']
    servers = sorted(set(current.get('enabledMcpjsonServers', [])) | set(incoming.get('enabledMcpjsonServers', [])))
    if servers:
        current['enabledMcpjsonServers'] = servers
    for event, groups in incoming.get('hooks', {}).items():
        existing = current.setdefault('hooks', {}).setdefault(event, [])
        commands = {h.get('command') for g in existing for h in g.get('hooks', [])}
        for group in groups:
            if not any(h.get('command') in commands for h in group.get('hooks', [])):
                existing.append(group)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(current, indent=2) + '\n')


def merge_mcp(root: Path, incoming: dict, server: str) -> None:
    """Adds slop's server to .mcp.json unless the developer already has it configured elsewhere."""
    configured = subprocess.run(['claude', 'mcp', 'get', server], cwd=root, capture_output=True, text=True)
    if configured.returncode == 0:
        return
    path = root / '.mcp.json'
    current = json.loads(path.read_text()) if path.exists() else {}
    for name, entry in incoming.get('mcpServers', {}).items():
        current.setdefault('mcpServers', {})[name] = entry
    path.write_text(json.dumps(current, indent=2) + '\n')


def merge_claude_md(root: Path, section: str) -> None:
    path = root / 'CLAUDE.md'
    text = path.read_text() if path.exists() else ''
    block = f'{MARKER}\n{section.strip()}\n{MARKER_END}'
    if MARKER in text and MARKER_END in text:
        start = text.index(MARKER)
        end = text.index(MARKER_END) + len(MARKER_END)
        text = text[:start] + block + text[end:]
    else:
        text = (text.rstrip() + '\n\n' if text.strip() else '') + block + '\n'
    path.write_text(text)


def ensure_ignored(root: Path, pattern: str) -> None:
    path = root / '.gitignore'
    lines = path.read_text().splitlines() if path.exists() else []
    if pattern not in lines:
        path.write_text('\n'.join(lines + [pattern]) + '\n')


def apply(root: Path, bundle: dict, board: str, server: str) -> list[str]:
    manifest_path = root / MANIFEST
    previous = json.loads(manifest_path.read_text()) if manifest_path.exists() else None
    first_run = previous is None
    written: list[str] = []

    # Write managed files to a staging folder first; swap them in only when all are ready.
    with tempfile.TemporaryDirectory() as staging:
        staged: list[tuple[Path, str]] = []
        for file in bundle['files']:
            target = target_of(file['path'])
            if target is None:
                continue
            source = Path(staging) / target
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_text(file['content'])
            staged.append((source, target))
        for source, target in staged:
            destination = root / target
            destination.parent.mkdir(parents=True, exist_ok=True)
            os.replace(source, destination)
            if target.startswith('.claude/hooks/'):
                destination.chmod(0o755)
            written.append(target)

    by_path = {f['path']: f['content'] for f in bundle['files']}
    if 'settings.json' in by_path:
        merge_settings(root, json.loads(by_path['settings.json']), first_run)
    if 'mcp.json' in by_path:
        merge_mcp(root, json.loads(by_path['mcp.json']), server)
    if 'claude_md.md' in by_path:
        merge_claude_md(root, by_path['claude_md.md'])
    ensure_ignored(root, '.reviews/')

    # Remove managed files that left the agent set, and on the first run the legacy ones.
    stale = set(previous.get('files', [])) - set(written) if previous else set()
    if first_run:
        stale |= set(LEGACY_FILES)
        for directory in LEGACY_DIRS:
            if (root / directory).is_dir():
                shutil.rmtree(root / directory)
    for path in sorted(stale):
        (root / path).unlink(missing_ok=True)

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(
            {
                'board': int(board),
                'version': bundle['version'],
                'files': sorted(written),
                'fetchedAt': datetime.now(timezone.utc).isoformat(timespec='seconds'),
            },
            indent=2,
        )
        + '\n'
    )
    return written


def main() -> None:
    root = git_root()
    conf = read_conf(root)
    board = (sys.argv[1] if len(sys.argv) > 1 else '') or os.environ.get('SLOP_BOARD', '') or conf.get('SLOP_BOARD', '')
    if not board.isdigit():
        fail('no board: pass one (sstor init <board>), set SLOP_BOARD, or add SLOP_BOARD to .sstor/sstor.conf')
    server = os.environ.get('SLOP_MCP_SERVER') or conf.get('SLOP_MCP_SERVER') or 'slop'

    try:
        bundle = fetch_bundle(root, server, board)
    except Exception as error:  # noqa: BLE001 (any failure falls back to the committed copy)
        if (root / MANIFEST).exists():
            warn(f'could not fetch the agent set from slop ({error}); keeping the installed copy')
            return
        fail(f'could not fetch the agent set from slop and nothing is installed yet: {error}')

    written = apply(root, bundle, board, server)
    print(f'sstor init: board {board} agent set v{bundle["version"]}: {len(written)} files, settings, CLAUDE.md')


if __name__ == '__main__':
    main()
