#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MODULE="$ROOT/modules/window-manager.nix"

grep -Fq 'winmuxAppPath = "/Applications/WinMux.app";' "$MODULE"
grep -Fq 'winmuxCliPath = "${homeDirectory}/Developer/winmux/.local/install/current/bin/winmux";' "$MODULE"
grep -Fq 'export WINMUX_APP_PATH="${winmuxAppPath}"' "$MODULE"
grep -Fq 'name = "winmux";' "$MODULE"
grep -Fq 'exec "${activeWinmuxCliPath}" "$@"' "$MODULE"
grep -Fq 'home-manager.users.${username}.home.file = {' "$MODULE"
grep -Fq '".local/bin/winmux" = {' "$MODULE"
grep -Fq 'source = "${winmuxCommand}/bin/winmux";' "$MODULE"
! grep -Fq 'callPackage ../packages/winmux.nix' "$MODULE"
grep -Fq '../config/winmux/winmux.toml' "$MODULE"
grep -Fq '../config/winmux/window-manager-toggle.sh' "$MODULE"
grep -Fq 'SUEnableAutomaticChecks = false;' "$MODULE"
grep -Fq 'if [ ! -e "$winmux_config" ]; then' "$MODULE"

if rg -q 'aerospace|AeroSpace|jankyborders|JankyBorders' \
  "$MODULE" "$ROOT/modules/homebrew.nix" "$ROOT/flake.nix" \
  "$ROOT/lib/mk-darwin-host.nix" "$ROOT/AGENTS.md" "$ROOT/README.md"; then
  echo "active configuration still references the old window-manager stack" >&2
  exit 1
fi
[ ! -d "$ROOT/config/aerospace" ]

echo "WinMux module regression checks passed"
