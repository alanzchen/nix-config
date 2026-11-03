#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import pathlib, sys, tomllib
root = pathlib.Path(sys.argv[1])
config = tomllib.loads((root/'config/migration/winmux.toml').read_text())
assert config['start-at-login'] is False
assert 'display-widths' not in config['workspace-sidebar']
assert config['mode']['main']['binding']['alt-o'] == 'open-sidebar'
assert config['mode']['main']['binding']['alt-b'].endswith('com.basecamp.basecamp3')
host = (root/'hosts/personal-new/configuration.nix').read_text()
assert '/Applications/WinMux.app/Contents/Helpers/winmux' in host
assert 'winmuxRestoreOnActivation = false' in host
assert 'packages/winmux-personal.nix' in host
PY
echo "New-Mac WinMux regression checks passed"
