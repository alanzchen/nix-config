#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-/opt/homebrew/etc/homebrew/brew.env}"
start_marker="# nix-config: homebrew china mirrors begin"
end_marker="# nix-config: homebrew china mirrors end"

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | cn | CN | china | CHINA) return 0 ;;
    *) return 1 ;;
  esac
}

is_falsey() {
  case "${1:-}" in
    0 | false | FALSE | no | NO | outside | OUTSIDE) return 0 ;;
    *) return 1 ;;
  esac
}

url_reports_china() {
  local url="$1"
  local result
  result="$(curl --connect-timeout 2 --max-time 4 --fail --silent --show-error "$url" 2>/dev/null || true)"
  printf '%s\n' "$result" | grep -Eq '中国|China|CHINA'
}

is_in_china() {
  if [ -n "${HOMEBREW_CHINA_MIRROR_OVERRIDE:-}" ]; then
    is_truthy "$HOMEBREW_CHINA_MIRROR_OVERRIDE" && return 0
    is_falsey "$HOMEBREW_CHINA_MIRROR_OVERRIDE" && return 1
  fi

  for url in \
    "cip.cc" \
    "myip.ipip.net"
  do
    url_reports_china "$url" && return 0
  done

  return 1
}

write_without_managed_block() {
  local source_file="$1"
  local target_file="$2"

  if [ ! -f "$source_file" ]; then
    : >"$target_file"
    return 0
  fi

  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip = 1; next }
    $0 == end { skip = 0; next }
    !skip { print }
  ' "$source_file" >"$target_file"
}

write_mirror_block() {
  cat <<'BREWENV'
# nix-config: homebrew china mirrors begin
HOMEBREW_BREW_GIT_REMOTE=https://mirrors.ustc.edu.cn/brew.git
HOMEBREW_CORE_GIT_REMOTE=https://mirrors.ustc.edu.cn/homebrew-core.git
HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles
HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api
HOMEBREW_NO_ENV_HINTS=1
# nix-config: homebrew china mirrors end
BREWENV
}

install_env_file() {
  local temp_file="$1"
  local target_file="$2"

  if [ ! -s "$temp_file" ]; then
    rm -f "$target_file"
    return 0
  fi

  mkdir -p "$(dirname "$target_file")"
  install -m 0644 "$temp_file" "$target_file"
}

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

write_without_managed_block "$env_file" "$tmp_file"

if is_in_china; then
  if [ -s "$tmp_file" ] && [ "$(tail -c 1 "$tmp_file" | wc -l | tr -d ' ')" = "0" ]; then
    printf '\n' >>"$tmp_file"
  fi
  write_mirror_block >>"$tmp_file"
  install_env_file "$tmp_file" "$env_file"
  echo "Homebrew USTC mirrors enabled for China network."
else
  install_env_file "$tmp_file" "$env_file"
  echo "Homebrew USTC mirrors disabled outside China network."
fi
