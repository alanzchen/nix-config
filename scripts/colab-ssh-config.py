#!/usr/bin/env python3
"""Set the current Colab Cloudflare tunnel without exporting its private key."""
import argparse
import os
from pathlib import Path
import re
import shutil

HEADER = '# Managed by colab-ssh-config; ephemeral endpoint, not committed.\n'


def configure(hostname, home, cloudflared):
    if not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.trycloudflare\.com', hostname):
        raise ValueError('Expected the current <name>.trycloudflare.com hostname, without a URL or port')
    key = home/'.ssh/1password-colab.pub'
    if not key.is_file():
        raise ValueError('Restore the Colab public key from 1Password first')
    target = home/'.ssh/config.d/30-colab.conf'
    if target.is_symlink() or (target.exists() and not target.read_text().startswith(HEADER)):
        raise ValueError('Existing custom Colab configuration preserved; review it before replacing it')
    text = HEADER + f'''Host colab-ssh
  HostName {hostname}
  User root
  IdentityFile ~/.ssh/1password-colab.pub
  IdentitiesOnly yes
  UserKnownHostsFile ~/.ssh/known_hosts_colab
  StrictHostKeyChecking ask
  ForwardAgent no
  ProxyCommand {cloudflared} access ssh --hostname %h
'''
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = target.with_suffix('.conf.tmp')
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, 'w') as file:
            file.write(text)
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('hostname')
    args = parser.parse_args()
    cloudflared = shutil.which('cloudflared')
    if not cloudflared:
        parser.error('cloudflared is not installed')
    try:
        configure(args.hostname, Path.home(), cloudflared)
    except (ValueError, OSError) as error:
        parser.exit(1, str(error)+'\n')
    print('Configured colab-ssh. Verify the runtime host-key fingerprint on first connection.')


if __name__ == '__main__':
    main()
