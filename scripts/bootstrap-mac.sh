#!/bin/bash
# Run as the new Mac's normal administrator user, never with sudo bash.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-install}"
case "$mode" in
  --plan)
    cat <<'PLAN'
New personal Mac setup (no changes made):
  1. Check Apple silicon, normal administrator account, 1Password app, and developer tools.
  2. Install upstream multi-user Nix if absent; retain the existing flake.lock.
  3. Record THIS Mac's username and hostname in hosts/personal-new/identity.json.
  4. Build and activate ONLY personal-new, including the pinned personal WinMux fork.
  5. Seed mutable editor settings, install extensions, and verify 1Password integration.
  6. Report outstanding app sign-ins, OS permissions, and optional App Store installs.
Rerunning resumes installation; existing mutable settings are not overwritten.
PLAN
    exit 0 ;;
  install) ;;
  *) echo "Usage: bash scripts/bootstrap-mac.sh [--plan]" >&2; exit 2 ;;
esac
[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || {
  echo "This profile supports Apple-silicon Macs only." >&2; exit 1;
}
[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user, not root." >&2; exit 1; }
[ -r /dev/tty ] || { echo "Run from an interactive Terminal window." >&2; exit 1; }
host_name="$(/usr/sbin/scutil --get LocalHostName)"
if [ "$host_name" = alans-macbook-air-1 ]; then
  echo "Refusing to replace the reference Mac with the new-machine profile." >&2
  exit 1
fi
[ -d /Applications/1Password.app ] || {
  echo "Install and unlock 1Password, then rerun this command." >&2; exit 1;
}
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  /usr/bin/xcode-select --install || true
  echo "Complete Apple's developer-tools installer. Waiting up to 20 minutes..."
  count=0
  until /usr/bin/xcode-select -p >/dev/null 2>&1; do
    count=$((count + 1))
    [ "$count" -lt 240 ] || { echo "Rerun after developer tools finish installing." >&2; exit 1; }
    sleep 5
  done
fi
export PATH="/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
state="$HOME/.local/state/mac-bootstrap"
mkdir -p "$state"
chmod 700 "$state"
if ! command -v nix >/dev/null 2>&1; then
  installer="$(mktemp -t nix-install)"
  trap 'rm -f "$installer"' EXIT
  /usr/bin/curl --fail --location --proto '=https' --tlsv1.2 https://nixos.org/nix/install -o "$installer"
  sh "$installer" --daemon </dev/tty
  rm -f "$installer"
  trap - EXIT
fi
command -v nix >/dev/null 2>&1 || { echo "Nix installation did not finish." >&2; exit 1; }
nix_cmd=(nix --extra-experimental-features 'nix-command flakes')
"${nix_cmd[@]}" build "$ROOT#darwinConfigurations.personal-new.pkgs.python3" \
  --no-write-lock-file --out-link "$state/python"
python="$state/python/bin/python3"
"$python" "$ROOT/scripts/setup-user.py" identity "$ROOT"
"${nix_cmd[@]}" build "$ROOT#darwinConfigurations.personal-new.system" \
  --no-write-lock-file --out-link "$state/system"
# Secrets are never evaluated by Nix or passed to the privileged activation.
# Read the invoking user's terminal; it does not require root access.
# shellcheck disable=SC2024
sudo -S "$state/system/sw/bin/darwin-rebuild" switch --flake "$ROOT#personal-new" </dev/tty
"$python" "$ROOT/scripts/setup-user.py" restore "$ROOT"
"$python" "$ROOT/scripts/setup-user.py" verify "$ROOT"
