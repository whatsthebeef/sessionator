#!/usr/bin/env python3
"""Strict check of .sstor/local-run.json, the board's local-run spec that `slop init` writes.

The file is {"build"?: string, "launch": string}. sstor runs these commands in the session's
server window, so anything else (other keys, other types, an empty launch) is refused.
Prints the validated spec as JSON, or nothing when the file is absent.

Usage: sstor_local_run.py <checkout>
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import NoReturn

ALLOWED = {'build', 'launch'}


def fail(message: str) -> NoReturn:
    print(f'sstor: .sstor/local-run.json: {message}', file=sys.stderr)
    sys.exit(1)


def validate(spec: object) -> dict[str, str]:
    if not isinstance(spec, dict):
        fail('must be a JSON object')
    extra = sorted(set(spec) - ALLOWED)
    if extra:
        fail(f'unexpected key(s): {", ".join(extra)}')
    launch = spec.get('launch')
    if not isinstance(launch, str) or not launch.strip():
        fail('"launch" must be a non-empty string')
    result = {'launch': launch}
    if 'build' in spec:
        build = spec['build']
        if not isinstance(build, str) or not build.strip():
            fail('"build" must be a non-empty string when present')
        result['build'] = build
    return result


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit('usage: sstor_local_run.py <checkout>')
    path = Path(sys.argv[1]) / '.sstor' / 'local-run.json'
    if not path.is_file():
        return
    try:
        spec = json.loads(path.read_text())
    except (OSError, ValueError) as error:
        fail(f'cannot read: {error}')
    print(json.dumps(validate(spec)))


if __name__ == '__main__':
    main()
