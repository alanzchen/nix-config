#!/usr/bin/env python3
"""Install the pinned app once; never merge over a running or updated bundle."""
import argparse
import hashlib
import os
from pathlib import Path
import stat
import subprocess
import tempfile


def bundle_manifest(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError(f'Expected an app directory, not a symlink: {root}')
    result = {}
    for directory, folders, files in os.walk(root, followlinks=False):
        for name in folders + files:
            path = Path(directory)/name
            relative = str(path.relative_to(root))
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                result[relative] = ('link', os.readlink(path))
            elif stat.S_ISDIR(mode):
                result[relative] = ('directory',)
            elif stat.S_ISREG(mode):
                result[relative] = ('file', mode & 0o111, hashlib.sha256(path.read_bytes()).hexdigest())
            else:
                raise ValueError(f'Unexpected special file in app: {path}')
    return result


def verify_signature(app):
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)


def install(source, destination, check_only=False):
    expected = bundle_manifest(source)
    verify_signature(source)
    if os.path.lexists(destination):
        if bundle_manifest(destination) != expected:
            raise ValueError(f'{destination} differs from the pinned app; preserved for review. '
                             'Quit WinMux and review the existing version before replacing it.')
        verify_signature(destination)
        print('WinMux already matches the pinned app; no files changed.')
        return
    if check_only:
        raise ValueError(f'WinMux is not installed at {destination}')
    # Validate a complete staged copy before making it visible in Applications.
    with tempfile.TemporaryDirectory(prefix='.winmux-install-', dir=destination.parent) as tmp:
        staged = Path(tmp)/'WinMux.app'
        subprocess.run(['/usr/bin/ditto', str(source), str(staged)], check=True)
        if bundle_manifest(staged) != expected:
            raise ValueError('Staged WinMux bundle does not match its source')
        verify_signature(staged)
        if os.path.lexists(destination):
            raise ValueError(f'{destination} appeared during installation; preserved for review')
        staged.rename(destination)
    print(f'Installed WinMux at {destination}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--destination', type=Path, default=Path('/Applications/WinMux.app'))
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        install(args.source, args.destination, args.check)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f'{error}\n')
