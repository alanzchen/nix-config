#!/usr/bin/env python3
"""Run a command with a reference-only environment file; never print secrets."""
import os
from pathlib import Path
import re
import shutil
import shlex
import sys


def reference_file(path):
    lines = Path(path).read_text().splitlines()
    count = 0
    for number, line in enumerate(lines, 1):
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        name, separator, value = line.partition('=')
        words = shlex.split(value) if separator else []
        if (not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name)
                or len(words) != 1
                or not re.fullmatch(r'op://[^/\r\n]+/[^/\r\n]+/[^\r\n]+', words[0])
                or '$' in value or '`' in value):
            raise ValueError(f'Line {number}: expected NAME="op://vault/item/field" (no plaintext values)')
        count += 1
    if not count:
        raise ValueError('No secret references configured in this file')


def main():
    if len(sys.argv) < 3:
        raise ValueError('Usage: with-secrets references.env command [arguments...]')
    path = str(Path(sys.argv[1]).resolve())
    reference_file(path)
    op = shutil.which('op')
    if not op:
        raise ValueError('Install 1Password CLI and enable its desktop app integration')
    os.execv(op, [op, 'run', '--env-file', path, '--', *sys.argv[2:]])


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as exc:
        sys.exit(str(exc))
