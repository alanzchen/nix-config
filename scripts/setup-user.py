#!/usr/bin/env python3
"""Resumable per-user setup. It does not copy credentials or activate services."""
import getpass
import base64
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


def restore_github_identity(root):
    """Only a public key is exported. Private-key operations stay in the agent."""
    op = shutil.which('op')
    if not op:
        return False
    manifest = json.loads((root/'config/migration/credentials.json').read_text())
    references = dict(manifest.get('additionalSshPublicKeys', {}))
    references['github'] = manifest['githubSshPublicKey']
    for name, reference in references.items():
        if not re.fullmatch(r'[a-z][a-z0-9-]*', name) or not re.fullmatch(r'op://[a-z0-9]+/[a-z0-9]+/public_key', reference):
            raise ValueError('Expected an explicit public_key reference in the credential manifest')
    template = ''.join(f'[[{name}]]\n{{{{ {ref} }}}}\n[[/{name}]]\n' for name,ref in references.items())
    try:
        # Resolve all currently mapped public keys in ONE CLI invocation. Never
        # revisit 1Password during subsequent application or verification steps.
        result = subprocess.run([op, 'inject'], input=template, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        return False
    if result.returncode:
        return False
    try:
        public_keys = {}
        remaining = result.stdout
        for name in references:
            prefix, suffix = f'[[{name}]]\n', f'\n[[/{name}]]\n'
            if not remaining.startswith(prefix) or suffix not in remaining:
                raise ValueError()
            value, remaining = remaining[len(prefix):].split(suffix, 1)
            parts = value.strip().split()
            if len(parts) < 2 or parts[0] not in ['ssh-rsa', 'ssh-ed25519', 'ecdsa-sha2-nistp256', 'ecdsa-sha2-nistp384', 'ecdsa-sha2-nistp521']:
                raise ValueError()
            base64.b64decode(parts[1], validate=True)
            public_keys[name] = ' '.join(parts[:2]) + '\n'
        if remaining.strip():
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        raise ValueError('1Password returned an invalid public-key batch; nothing was written') from None
    ssh = Path.home()/'.ssh'
    ssh.mkdir(mode=0o700, parents=True, exist_ok=True)
    # Preflight every output before writing any of them.
    for name,public in public_keys.items():
        key = ssh/f'1password-{name}.pub'
        if key.is_symlink() or (key.exists() and key.read_text().strip() != public.strip()):
            print('Preserved an existing different SSH public key; review it before migration.')
            return False
    directory = ssh/'config.d'
    directory.mkdir(mode=0o700, exist_ok=True)
    config = directory/'10-github.conf'
    expected = 'Host github.com\n  User git\n  IdentitiesOnly yes\n  IdentityFile ~/.ssh/1password-github.pub\n'
    if config.is_symlink() or (config.exists() and config.read_text() != expected):
        print('Preserved existing GitHub SSH routing; review it before migration.')
        return False
    for name,public in public_keys.items():
        key = ssh/f'1password-{name}.pub'
        key.write_text(public)
        key.chmod(0o600)
    config.write_text(expected)
    config.chmod(0o600)
    return True


def restore(root):
    home = Path.home()
    if restore_github_identity(root):
        print('Configured GitHub public-key selection; private key remains in 1Password.')
    else:
        print('Pending: 1Password public-key setup. Enable CLI integration and rerun setup.')
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
    # Keep verification local: do not open a second authorization session after
    # potentially lengthy application/extension installation.
    if not shutil.which('op'):
        issues.append('1Password CLI is not installed')
    sock = Path.home()/'Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock'
    if not sock.exists():
        issues.append('1Password: enable the SSH agent under Settings > Developer')
    github_config = Path.home()/'.ssh/config.d/10-github.conf'
    if (not (Path.home()/'.ssh/1password-github.pub').is_file()
            or not github_config.is_file()
            or 'IdentityFile ~/.ssh/1password-github.pub' not in github_config.read_text()):
        issues.append('GitHub: mapped public-key selection not restored; rerun setup-user.py restore')
    print('\nInstallation checks:')
    for issue in issues:
        print('  Pending: '+issue)
    if not issues:
        print('  Selected applications and local SSH configuration are available.')
    print('  Vault authentication was not rechecked; verification makes no 1Password calls.')
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
