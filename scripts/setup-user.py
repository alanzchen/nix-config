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
import tomllib
import stat


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
        print('Restored mapped SSH public keys; private keys remain in 1Password.')
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
    # Use the declared wrapper, not a pre-existing uv tool earlier on PATH.
    colab = Path('/run/current-system/sw/bin/colab')
    tool_failures = []
    try:
        result = subprocess.run([str(colab), 'version'], capture_output=True, text=True, timeout=300)
        if result.returncode or '0.6.0' not in result.stdout:
            tool_failures.append('Colab: rerun /run/current-system/sw/bin/colab version')
    except (OSError, subprocess.SubprocessError):
        tool_failures.append('Colab: rerun /run/current-system/sw/bin/colab version')
    (state/'tool-failures.json').write_text(json.dumps(tool_failures, indent=2)+'\n')
    for issue in tool_failures:
        print('Pending: '+issue)


def ssh_issues(root, home):
    """Static local checks only: do not contact the agent, vault, or remote hosts."""
    issues = []
    manifest = json.loads((root/'config/migration/credentials.json').read_text())
    references = dict(manifest.get('additionalSshPublicKeys', {}))
    references['github'] = manifest['githubSshPublicKey']
    sock = home/'Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock'
    if not sock.exists() or not stat.S_ISSOCK(sock.stat().st_mode):
        issues.append('1Password: SSH agent socket is unavailable; enable the SSH agent')
    try:
        agent = tomllib.loads((home/'.config/1Password/ssh/agent.toml').read_text())
        configured = {(x.get('vault'), x.get('item')) for x in agent.get('ssh-keys', [])}
    except (OSError, ValueError, TypeError, AttributeError):
        configured = set()
    for name, reference in references.items():
        parts = reference.split('/')
        if (parts[2], parts[3]) not in configured:
            issues.append(f'1Password agent selection: {name} key is not declared')
        key = home/f'.ssh/1password-{name}.pub'
        try:
            words = key.read_text().split()
            if len(words) < 2 or words[0] not in ['ssh-rsa','ssh-ed25519','ecdsa-sha2-nistp256','ecdsa-sha2-nistp384','ecdsa-sha2-nistp521']:
                raise ValueError()
            base64.b64decode(words[1], validate=True)
        except (OSError, ValueError):
            issues.append(f'{name}: mapped public key missing or invalid; rerun setup-user.py restore')
    expected = {
        '.ssh/config.d/20-migration-hosts.conf': root/'config/migration/ssh-hosts.conf',
        '.ssh/known_hosts_migration': root/'config/migration/known_hosts',
        '.ssh/known_hosts_comma': root/'config/migration/known_hosts_comma',
    }
    for relative, source in expected.items():
        target = home/relative
        if not target.is_file() or target.read_text() != source.read_text():
            issues.append(f'SSH migration file missing or changed: {relative}')
    main = home/'.ssh/config'
    text = main.read_text() if main.is_file() else ''
    if ('Include ~/.ssh/config.d/*' not in text or '1password/t/agent.sock' not in text
            or '~/.ssh/known_hosts_migration' not in text):
        issues.append('SSH: migration includes, trusted hosts or 1Password agent routing are missing')
    github = home/'.ssh/config.d/10-github.conf'
    if not github.is_file() or 'IdentityFile ~/.ssh/1password-github.pub' not in github.read_text():
        issues.append('GitHub: public-key selection not restored; rerun setup-user.py restore')
    return issues


def verify(root):
    issues = []
    expected = json.loads((root/'config/migration/verification.json').read_text())
    for app in expected['applications']:
        if not (Path('/Applications')/(app+'.app')).is_dir():
            issues.append(f'{app}: application missing')
    # Keep verification local: do not open a second authorization session after
    # potentially lengthy application/extension installation.
    for command in expected['commands']:
        actual = shutil.which(command)
        if not actual:
            issues.append(f'{command}: command missing from PATH')
        elif command in ['agentsview','colab']:
            declared = Path('/run/current-system/sw/bin')/command
            if declared.exists() and Path(actual).resolve() != declared.resolve():
                issues.append(f'{command}: an older local installation shadows the declared command ({actual})')
    issues.extend(ssh_issues(root, Path.home()))
    state = Path.home()/'.local/state/mac-bootstrap'
    for name in ['extension-failures.json', 'tool-failures.json']:
        path = state/name
        if path.is_file():
            pending = json.loads(path.read_text())
            if pending:
                issues.append(f'{len(pending)} incomplete installation(s): see {path}')
    if not (Path.home()/'.local/share/nix-colab/venv/bin/colab').is_file():
        issues.append('Colab environment missing: run /run/current-system/sw/bin/colab version')
    try:
        service = subprocess.run(['/bin/launchctl', 'print', f'gui/{os.getuid()}/io.agentsview.nix-spoke'],
                                 capture_output=True, text=True, timeout=10)
        if service.returncode or not re.search(r'^\s*state = running\s*$', service.stdout, re.M):
            issues.append('AgentsView spoke is not running; check Tailscale sign-in and mac-bootstrap/agentsview.stderr.log')
    except (OSError, subprocess.SubprocessError):
        issues.append('AgentsView launch-agent status could not be checked')
    print('\nInstallation checks:')
    for issue in issues:
        print('  Pending: '+issue)
    if not issues:
        print('  Selected applications and local SSH configuration are available.')
    print('  Vault authentication was not rechecked; verification makes no 1Password calls.')
    print('\nFirst-run checklist (manual approvals are not inferred from installation):')
    for item in expected['manual']:
        print('  '+item)
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    report = state/'verification.json'
    report.write_text(json.dumps({'pending':issues, 'manual':expected['manual'], 'vaultQueried':False}, indent=2)+'\n')
    report.chmod(0o600)
    print(f'\nSaved checklist: {report}')
    return 2 if issues else 0


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ['identity','restore','verify']:
        sys.exit('Usage: setup-user.py {identity|restore|verify} CONFIG_DIRECTORY')
    try:
        sys.exit(globals()[sys.argv[1]](Path(sys.argv[2]).resolve()) or 0)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        sys.exit(str(exc))
