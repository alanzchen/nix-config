#!/usr/bin/env python3
"""Resumable per-user setup. It does not copy credentials or activate services."""
import getpass
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def seed(source, target):
    """Seed a mutable file without overwriting user changes, including symlinks."""
    if target.exists() or target.is_symlink():
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    target.chmod(0o600)
    return True


def identity(root):
    username = getpass.getuser()
    hostname = subprocess.check_output(['/usr/sbin/scutil', '--get', 'LocalHostName'], text=True).strip()
    computer = subprocess.check_output(['/usr/sbin/scutil', '--get', 'ComputerName'], text=True).strip()
    if not re.fullmatch(r'[a-z_][a-z0-9_-]*', username):
        raise ValueError('Unsupported macOS short username')
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9-]{0,62}', hostname):
        raise ValueError('Choose a valid LocalHostName before installation')
    if Path.home() != Path('/Users') / username:
        raise ValueError('This bootstrap currently requires a standard /Users/<username> home')
    path = root / 'hosts/personal-new/identity.json'
    path.write_text(json.dumps(dict(username=username, hostName=hostname, computerName=computer), indent=2) + '\n')


def restore(root):
    home = Path.home()
    source = root / 'config/migration/vscode'
    target = home / 'Library/Application Support/Code/User'
    for name in ['settings.json', 'keybindings.json']:
        print(('Seeded ' if seed(source/name, target/name) else 'Preserved ') + 'VS Code ' + name)
    code = Path('/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code')
    failures = []
    if code.exists():
        result = subprocess.run([str(code), '--list-extensions'], capture_output=True, text=True)
        installed = set(result.stdout.lower().splitlines()) if result.returncode == 0 else set()
        for extension in (source/'extensions.txt').read_text().splitlines():
            if extension.lower() in installed:
                continue
            result = subprocess.run([str(code), '--install-extension', extension], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if result.returncode:
                failures.append(extension)
    else:
        failures.append('VS Code application missing')
    state = home / '.local/state/mac-bootstrap'
    state.mkdir(parents=True, exist_ok=True)
    (state/'extension-failures.json').write_text(json.dumps(failures, indent=2)+'\n')
    if failures:
        print(f'{len(failures)} extension install(s) need a retry; see mac-bootstrap/extension-failures.json.')


def verify(root):
    issues = []
    for app in ['1Password', 'Basecamp', 'BetterDisplay', 'Tailscale', 'Hammerspoon', 'WinMux']:
        if not (Path('/Applications')/(app+'.app')).is_dir():
            issues.append(f'{app}: application missing')
    op = shutil.which('op')
    try:
        authenticated = op and subprocess.run([op, 'whoami'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=20).returncode == 0
    except subprocess.TimeoutExpired:
        authenticated = False
    if not authenticated:
        issues.append('1Password: unlock app, enable Settings > Developer > Integrate with 1Password CLI, then run op whoami')
    sock = Path.home()/'Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock'
    if not sock.exists():
        issues.append('1Password: enable the SSH agent under Settings > Developer')
    print('\nInstallation checks:')
    for issue in issues:
        print('  Pending: '+issue)
    if not issues:
        print('  Selected applications and 1Password authentication are available.')
    print('\nFirst-run checklist (manual approvals are not inferred from installation):')
    for item in [
        'Approve Karabiner, WinMux, and Hammerspoon permissions in System Settings.',
        'Run wm-toggle on after WinMux Accessibility approval; verify Caps Lock shortcuts.',
        'Open Hammerspoon; verify Control-Option-Space with the current ChatGPT/Codex app.',
        'Open Finicky and select it as the default web browser.',
        'Sign in to Tailscale and approve its VPN/system extension.',
        'Sign in to browsers/Basecamp and activate BetterDisplay if needed.',
        'Use browser sync and supported launcher exports to restore private profiles.',
        'App Store apps: after sign-in, run scripts/install-app-store.sh.',
        'See docs/new-mac.md for SSH key exceptions and remaining custom tools.',
    ]:
        print('  '+item)
    return 2 if issues else 0


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ['identity','restore','verify']:
        sys.exit('Usage: setup-user.py {identity|restore|verify} CONFIG_DIRECTORY')
    try:
        sys.exit(globals()[sys.argv[1]](Path(sys.argv[2]).resolve()) or 0)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        sys.exit(str(exc))
