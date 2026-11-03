#!/usr/bin/env bash

set -euo pipefail

DEFAULTS_BIN="${DEFAULTS_BIN:-/usr/bin/defaults}"
OPEN_BIN="${OPEN_BIN:-/usr/bin/open}"
OSASCRIPT_BIN="${OSASCRIPT_BIN:-/usr/bin/osascript}"
PGREP_BIN="${PGREP_BIN:-/usr/bin/pgrep}"
PKILL_BIN="${PKILL_BIN:-/usr/bin/pkill}"
SLEEP_BIN="${SLEEP_BIN:-/bin/sleep}"
WINMUX_APP_NAME="${WINMUX_APP_NAME:-WinMux}"
WINMUX_APP_PATH="${WINMUX_APP_PATH:-/Applications/WinMux.app}"
WINMUX_PROCESS_NAME="${WINMUX_PROCESS_NAME:-WinMux}"
WM_TOGGLE_STATE_DIR="${WM_TOGGLE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/wm-toggle}"
WM_TOGGLE_STATE_FILE="$WM_TOGGLE_STATE_DIR/state"

usage() {
  cat <<'EOF'
Usage: wm-toggle [toggle|on|off|status]

With no argument, toggles WinMux. The native macOS menu bar stays visible.
Flags --toggle, --on, --off, and --status are accepted as aliases.
EOF
}

recorded_state() {
  local state

  if [ -r "$WM_TOGGLE_STATE_FILE" ]; then
    IFS= read -r state <"$WM_TOGGLE_STATE_FILE" || true
    case "$state" in
      on | off)
        printf '%s\n' "$state"
        return
        ;;
    esac
  fi

  printf 'on\n'
}

write_state() {
  mkdir -p "$WM_TOGGLE_STATE_DIR"
  printf '%s\n' "$1" >"$WM_TOGGLE_STATE_FILE"
}

notify_macos_menu_bar_change() {
  "$OSASCRIPT_BIN" -l JavaScript <<'JXA'
ObjC.import("Foundation");
const center = $.NSDistributedNotificationCenter.defaultCenter;
center.postNotificationNameObjectUserInfoOptions(
  "AppleInterfaceMenuBarHidingChangedNotification",
  null,
  null,
  1
);
center.postNotificationNameObjectUserInfoOptions(
  "AppleInterfaceFullScreenMenuBarVisibilityChangedNotification",
  null,
  null,
  1
);
JXA
}

set_macos_menu_bar_visible() {
  "$DEFAULTS_BIN" write NSGlobalDomain _HIHideMenuBar -bool false
  "$DEFAULTS_BIN" write NSGlobalDomain AppleMenuBarVisibleInFullscreen -bool true
  "$DEFAULTS_BIN" write com.apple.desktopsettings.menubar AppleMenuBarVisibleInFullscreen -bool true
  "$DEFAULTS_BIN" write com.apple.controlcenter AutoHideMenuBarOption -int 3
  notify_macos_menu_bar_change
}

winmux_running() {
  "$PGREP_BIN" -x "$WINMUX_PROCESS_NAME" >/dev/null 2>&1
}

wait_for_winmux() {
  local wanted="$1"

  for _ in {1..100}; do
    if [ "$wanted" = "running" ] && winmux_running; then
      return 0
    fi
    if [ "$wanted" = "stopped" ] && ! winmux_running; then
      return 0
    fi
    "$SLEEP_BIN" 0.05
  done

  return 1
}

turn_off() {
  if winmux_running; then
    "$OSASCRIPT_BIN" -e "tell application \"$WINMUX_APP_NAME\" to quit"
    if ! wait_for_winmux stopped; then
      "$PKILL_BIN" -TERM -x "$WINMUX_PROCESS_NAME"
      wait_for_winmux stopped || {
        echo "wm-toggle: WinMux did not stop" >&2
        return 1
      }
    fi
  fi

  set_macos_menu_bar_visible
  write_state off
  echo "Window-manager mode: off (WinMux stopped; macOS menu bar visible)"
}

turn_on() {
  set_macos_menu_bar_visible

  if ! winmux_running; then
    if [ ! -d "$WINMUX_APP_PATH" ]; then
      echo "wm-toggle: missing WinMux app: $WINMUX_APP_PATH" >&2
      return 1
    fi
    "$OPEN_BIN" -gj "$WINMUX_APP_PATH"
    wait_for_winmux running || {
      echo "wm-toggle: WinMux did not finish starting" >&2
      return 1
    }
  fi

  write_state on
  echo "Window-manager mode: on (WinMux running; macOS menu bar visible)"
}

restore_saved_mode() {
  if [ "$(recorded_state)" = "off" ]; then
    turn_off
  else
    turn_on
  fi
}

macos_menu_bar_auto_hide() {
  local auto_hide_option
  local hide_on_desktop
  local visible_in_fullscreen

  hide_on_desktop="$("$DEFAULTS_BIN" read NSGlobalDomain _HIHideMenuBar 2>/dev/null || true)"
  visible_in_fullscreen="$("$DEFAULTS_BIN" read NSGlobalDomain AppleMenuBarVisibleInFullscreen 2>/dev/null || true)"
  auto_hide_option="$("$DEFAULTS_BIN" read com.apple.controlcenter AutoHideMenuBarOption 2>/dev/null || true)"

  if [ "$hide_on_desktop" = "1" ] &&
    [ "$visible_in_fullscreen" = "0" ] &&
    [ "$auto_hide_option" = "0" ]; then
    printf 'Always\n'
  elif [ "$hide_on_desktop" = "0" ] &&
    [ "$visible_in_fullscreen" = "1" ] &&
    [ "$auto_hide_option" = "3" ]; then
    printf 'Never\n'
  else
    printf 'mixed or unknown\n'
  fi
}

show_status() {
  local actual="stopped"

  if winmux_running; then
    actual="running"
  fi

  printf 'mode: %s\n' "$(recorded_state)"
  printf 'WinMux: %s\n' "$actual"
  printf 'macOS menu bar auto-hide: %s\n' "$(macos_menu_bar_auto_hide)"
}

action="${1:-toggle}"
[ "$#" -le 1 ] || {
  usage >&2
  exit 2
}

case "$action" in
  toggle | --toggle)
    if [ "$(recorded_state)" = "off" ]; then
      turn_on
    else
      turn_off
    fi
    ;;
  on | --on)
    turn_on
    ;;
  off | --off)
    turn_off
    ;;
  status | --status)
    show_status
    ;;
  restore)
    restore_saved_mode
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
