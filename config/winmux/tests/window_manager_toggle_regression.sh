#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$ROOT/config/winmux/window-manager-toggle.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/WinMux.app"
: >"$tmpdir/process-state"
: >"$tmpdir/command-log"

cat >"$tmpdir/defaults" <<'MOCK'
#!/usr/bin/env bash
printf 'defaults %s\n' "$*" >>"$MOCK_COMMAND_LOG"
if [ "${1:-}" = "read" ]; then
  case "$*" in
    *AutoHideMenuBarOption*) printf '3\n' ;;
    *_HIHideMenuBar*) printf '0\n' ;;
    *AppleMenuBarVisibleInFullscreen*) printf '1\n' ;;
  esac
fi
MOCK

cat >"$tmpdir/open" <<'MOCK'
#!/usr/bin/env bash
printf 'open %s\n' "$*" >>"$MOCK_COMMAND_LOG"
printf 'running\n' >"$MOCK_PROCESS_STATE"
MOCK

cat >"$tmpdir/osascript" <<'MOCK'
#!/usr/bin/env bash
printf 'osascript %s\n' "$*" >>"$MOCK_COMMAND_LOG"
if [ "${1:-}" = "-e" ]; then
  printf 'stopped\n' >"$MOCK_PROCESS_STATE"
fi
MOCK

cat >"$tmpdir/pgrep" <<'MOCK'
#!/usr/bin/env bash
[ "$(cat "$MOCK_PROCESS_STATE")" = "running" ]
MOCK

cat >"$tmpdir/pkill" <<'MOCK'
#!/usr/bin/env bash
printf 'pkill %s\n' "$*" >>"$MOCK_COMMAND_LOG"
printf 'stopped\n' >"$MOCK_PROCESS_STATE"
MOCK

chmod +x "$tmpdir"/{defaults,open,osascript,pgrep,pkill}

run_toggle() {
  DEFAULTS_BIN="$tmpdir/defaults" \
  OPEN_BIN="$tmpdir/open" \
  OSASCRIPT_BIN="$tmpdir/osascript" \
  PGREP_BIN="$tmpdir/pgrep" \
  PKILL_BIN="$tmpdir/pkill" \
  SLEEP_BIN=/usr/bin/true \
  WINMUX_APP_PATH="$tmpdir/WinMux.app" \
  WM_TOGGLE_STATE_DIR="$tmpdir/state" \
  MOCK_COMMAND_LOG="$tmpdir/command-log" \
  MOCK_PROCESS_STATE="$tmpdir/process-state" \
  bash "$SCRIPT" "$@"
}

run_toggle on >/dev/null
[ "$(cat "$tmpdir/state/state")" = "on" ]
[ "$(cat "$tmpdir/process-state")" = "running" ]
grep -Fq "open -gj $tmpdir/WinMux.app" "$tmpdir/command-log"

status="$(run_toggle status)"
grep -Fxq 'mode: on' <<<"$status"
grep -Fxq 'WinMux: running' <<<"$status"
grep -Fxq 'macOS menu bar auto-hide: Never' <<<"$status"

run_toggle off >/dev/null
[ "$(cat "$tmpdir/state/state")" = "off" ]
[ "$(cat "$tmpdir/process-state")" = "stopped" ]

echo "WinMux toggle regression checks passed"
