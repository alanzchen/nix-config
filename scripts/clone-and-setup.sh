#!/bin/bash
# This small entry point uses only macOS tools and the 1Password SSH agent.
set -euo pipefail
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || exit 1
[ "$(id -u)" -ne 0 ] || { echo 'Run as your normal user.' >&2; exit 1; }
[ -d /Applications/1Password.app ] || { echo 'Install and unlock 1Password first.' >&2; exit 1; }
agent="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
[ -S "$agent" ] || { echo 'In 1Password Settings > Developer, enable the SSH agent, then rerun.' >&2; exit 1; }
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  /usr/bin/xcode-select --install || true
  echo 'Complete the Apple developer-tools installer; this command will continue.'
  count=0
  until /usr/bin/xcode-select -p >/dev/null 2>&1; do
    count=$((count + 1))
    [ "$count" -lt 240 ] || { echo 'Rerun after developer tools finish.' >&2; exit 1; }
    sleep 5
  done
fi
# SSH_AUTH_SOCK avoids quoting a path with spaces inside a shell command.
export SSH_AUTH_SOCK="$agent"
export GIT_SSH_COMMAND='/usr/bin/ssh -o IdentityAgent=SSH_AUTH_SOCK'
destination="$HOME/Developer/nix-config"
mkdir -p "$(dirname "$destination")"
if [ ! -e "$destination" ]; then
  /usr/bin/git clone git@github.com:alanzchen/nix-config.git "$destination"
else
  remote="$(/usr/bin/git -C "$destination" remote get-url origin 2>/dev/null || true)"
  [ "$remote" = git@github.com:alanzchen/nix-config.git ] || {
    echo 'Existing destination is not this repository; preserve it and choose another location.' >&2
    exit 1
  }
fi
exec /bin/bash "$destination/scripts/bootstrap-mac.sh"
