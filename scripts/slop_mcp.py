#!/usr/bin/env python3
"""Call one slop MCP tool through Claude Code, with the developer's own slop login.

sstor holds no slop credential. It asks Claude Code (headless, `claude -p`) to call exactly one
tool and reads that tool's result straight from the stream-json output, so nothing depends on
the model copying data correctly.

Usage: slop_mcp.py <tool> '<json arguments>'     (prints the tool's JSON result)
  server: $SLOP_MCP_SERVER, SLOP_MCP_SERVER in .sstor/sstor.conf, or "slop"
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path


class SlopError(RuntimeError):
    pass


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


def server_name(root: Path) -> str:
    return os.environ.get('SLOP_MCP_SERVER') or read_conf(root).get('SLOP_MCP_SERVER') or 'slop'


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
                names[str(block.get('id', ''))] = str(block.get('name', ''))
            elif block.get('type') == 'tool_result' and names.get(str(block.get('tool_use_id', ''))) == tool:
                content = block.get('content')
                text = content if isinstance(content, str) else ''.join(
                    part.get('text', '') for part in content or [] if isinstance(part, dict)
                )
                if block.get('is_error'):
                    raise SlopError(text.strip() or f'{tool} failed')
                return text
    raise SlopError(f'{tool} was not called; is the "{tool.split("__")[1]}" MCP server set up and signed in?')


def call(root: Path, tool: str, arguments: dict) -> dict:
    """Calls slop's `tool` with `arguments` and returns its JSON result."""
    name = f'mcp__{server_name(root)}__{tool}'
    prompt = (
        f'Call the tool {name} exactly once (not any other server\'s tool) with exactly these arguments, '
        f'then reply with just OK.\nArguments: {json.dumps(arguments)}'
    )
    try:
        result = subprocess.run(
            ['claude', '-p', prompt, '--allowedTools', name, '--output-format', 'stream-json', '--verbose'],
            cwd=root,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=180,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        raise SlopError(f'could not run claude: {error}') from error
    text = tool_result(result.stdout, name)
    try:
        value = json.loads(text)
    except json.JSONDecodeError as error:
        raise SlopError(text.strip()) from error
    if isinstance(value, dict) and isinstance(value.get('code'), str) and 'message' in value:
        # slop's domain errors (forbidden, run_active, invalid_transition, ...)
        raise SlopError(f'{value["code"]}: {value["message"]}')
    return value


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    root = Path(subprocess.run(['git', 'rev-parse', '--show-toplevel'], capture_output=True, text=True).stdout.strip() or '.')
    try:
        print(json.dumps(call(root, sys.argv[1], json.loads(sys.argv[2]))))
    except SlopError as error:
        print(f'slop: {error}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
