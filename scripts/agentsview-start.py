#!/usr/bin/env python3
"""Start the selected spoke on this Mac's Tailscale address; no vault access."""
import ipaddress
import json
import os
from pathlib import Path
import subprocess
import sys


def tailscale_address(binary):
    result = subprocess.run([binary, 'status', '--json'], capture_output=True, text=True, timeout=15)
    if result.returncode:
        raise ValueError('Waiting for Tailscale sign-in')
    state = json.loads(result.stdout)
    if state.get('BackendState') != 'Running':
        raise ValueError('Waiting for Tailscale to be running')
    for address in state.get('Self', {}).get('TailscaleIPs', []):
        ip = ipaddress.ip_address(address)
        if ip.version == 4 and ip in ipaddress.ip_network('100.64.0.0/10'):
            return str(ip)
    raise ValueError('No Tailscale IPv4 address is available')


def main():
    os.umask(0o077)
    binary, tailscale = sys.argv[1:]
    address = tailscale_address(tailscale)
    # Separate state preserves any existing service, database, and device identity.
    state = Path.home()/'.local/share/agentsview-nix'
    if state.is_symlink():
        raise ValueError('AgentsView state directory must not redirect to another installation')
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.environ.pop('AGENTSVIEW_AUTH_TOKEN', None)
    os.environ['AGENTSVIEW_DATA_DIR'] = str(state)
    os.environ['AGENTSVIEW_TELEMETRY_ENABLED'] = '0'
    config = state/'config.toml'
    if config.is_symlink():
        raise ValueError('AgentsView config must remain a local mutable file')
    if not config.exists():
        with config.open('x') as file:
            file.write('archive_content = "full"\ndaemon_idle_timeout = "0s"\nrequire_auth = true\n')
    os.execv(binary, [binary, 'serve', '--no-browser', '--no-sync', '--require-auth',
                     '--host', address, '--port', '18082', '--no-update-check'])


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError):
        sys.exit('AgentsView could not start: check Tailscale sign-in and local state permissions. Launchd will retry.')
