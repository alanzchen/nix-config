#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${script_dir}/../china-mirrors.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

env_file="${tmp_dir}/brew.env"

cat >"$env_file" <<'BREWENV'
HOMEBREW_NO_ANALYTICS=1
BREWENV

HOMEBREW_CHINA_MIRROR_OVERRIDE=1 "$script" "$env_file" >/tmp/china_mirrors_test.log

grep -Fq "HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles" "$env_file"
grep -Fq "HOMEBREW_API_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles/api" "$env_file"
grep -Fq "HOMEBREW_NO_ANALYTICS=1" "$env_file"

HOMEBREW_CHINA_MIRROR_OVERRIDE=0 "$script" "$env_file" >/tmp/china_mirrors_test.log

grep -Fq "HOMEBREW_NO_ANALYTICS=1" "$env_file"
if grep -Fq "mirrors.ustc.edu.cn" "$env_file"; then
  echo "mirror block was not removed outside China" >&2
  exit 1
fi

empty_file="${tmp_dir}/empty.env"
HOMEBREW_CHINA_MIRROR_OVERRIDE=1 "$script" "$empty_file" >/tmp/china_mirrors_test.log
HOMEBREW_CHINA_MIRROR_OVERRIDE=0 "$script" "$empty_file" >/tmp/china_mirrors_test.log

if [ -e "$empty_file" ]; then
  echo "managed-only env file should be removed outside China" >&2
  exit 1
fi

mock_bin="${tmp_dir}/bin"
mkdir -p "$mock_bin"
cat >"${mock_bin}/curl" <<'CURL'
#!/usr/bin/env bash
case "${*: -1}" in
  cip.cc)
    printf 'IP\t: 203.0.113.1\n地址\t: United States\n'
    ;;
  myip.ipip.net)
    printf '当前 IP：203.0.113.1  来自于：中国 广东 广州  电信\n'
    ;;
  *)
    echo "unexpected probe: ${*: -1}" >&2
    exit 1
    ;;
esac
CURL
chmod +x "${mock_bin}/curl"

auto_file="${tmp_dir}/auto.env"
PATH="${mock_bin}:$PATH" "$script" "$auto_file" >/tmp/china_mirrors_test.log
grep -Fq "HOMEBREW_CORE_GIT_REMOTE=https://mirrors.ustc.edu.cn/homebrew-core.git" "$auto_file"
