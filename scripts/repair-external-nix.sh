#!/bin/bash
# Run locally on the affected Mac; sudo and privacy consent stay on that Mac.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -S /bin/bash "$0" </dev/tty
fi
helper=/usr/local/libexec/nix-daemon-launcher
plist=/Library/LaunchDaemons/org.nixos.nix-daemon.plist
[ -f "$plist" ] || { echo 'Install Nix first.' >&2; exit 1; }
/usr/sbin/diskutil info -plist /nix | /usr/bin/python3 -c '
import plistlib, sys
info = plistlib.loads(sys.stdin.buffer.read())
if info.get("Internal") is not False:
    sys.exit("This repair is only for an external Nix store.")
'
work="$(mktemp -d /private/tmp/nix-launcher.XXXXXX)"
trap 'rm -rf "$work"' EXIT
# Never silently replace a binary that may already have a privacy approval.
if [ -e "$helper" ] || [ -L "$helper" ]; then
  [ ! -L "$helper" ] &&
    [ "$(/usr/bin/stat -f '%u:%Lp' "$helper")" = "0:755" ] &&
    /usr/bin/cmp -s "$helper.c" "$ROOT/scripts/nix-daemon-launcher.c" &&
    /usr/bin/codesign --verify --strict "$helper" || {
    echo "Existing $helper differs; review before replacing it." >&2; exit 1;
  }
else
  /usr/bin/clang -O2 -Wall -Wextra -Werror "$ROOT/scripts/nix-daemon-launcher.c" -o "$work/nix-daemon-launcher"
  /usr/bin/codesign --force --sign - --identifier ch.zenan.nix-daemon-launcher "$work/nix-daemon-launcher"
  /usr/bin/codesign --verify --strict "$work/nix-daemon-launcher"
  /usr/bin/install -d -o root -g wheel -m 755 /usr/local/libexec
  /usr/bin/install -o root -g wheel -m 755 "$work/nix-daemon-launcher" "$helper"
  /usr/bin/install -o root -g wheel -m 644 "$ROOT/scripts/nix-daemon-launcher.c" "$helper.c"
fi
if [ ! -e "$plist.before-external-store" ]; then
  /bin/cp -p "$plist" "$plist.before-external-store"
fi
/usr/bin/python3 - "$plist" "$work/daemon.plist" "$helper" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as file:
    config = plistlib.load(file)
config.pop('Program', None)
config['ProgramArguments'] = [sys.argv[3]]
with open(sys.argv[2], 'wb') as file:
    plistlib.dump(config, file)
PY
/usr/bin/plutil -lint "$work/daemon.plist"
if /bin/launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
  /bin/launchctl bootout system/org.nixos.nix-daemon
fi
/usr/bin/install -o root -g wheel -m 644 "$work/daemon.plist" "$plist"
/bin/launchctl bootstrap system "$plist"
echo "Installed the dedicated launcher. In System Settings > Privacy & Security > Full Disk Access, add:"
echo "$helper"
echo 'The daemon retries automatically after you grant access.'
