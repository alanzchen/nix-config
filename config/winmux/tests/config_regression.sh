#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

python3 - "$ROOT/config/winmux/winmux.toml" <<'PY'
import sys
import tomllib

path = sys.argv[1]
with open(path, "rb") as stream:
    config = tomllib.load(stream)

assert config["config-version"] == 2
assert config["start-at-login"] is False
assert config["persistent-workspaces"] == []

sidebar = config["workspace-sidebar"]
assert sidebar["enabled"] is True
assert sidebar["stay-on-top"] is False
assert sidebar["always-expanded"] is False
assert sidebar["project-deletion-action"] == "move-windows-to-fallback"
assert sidebar["project-labels"] == {"default": "Default"}

bindings = config["mode"]["main"]["binding"]
assert bindings["alt-o"] == "open-sidebar"
assert bindings["alt-b"] == "exec-and-forget /usr/bin/open -b com.basecamp.basecamp3"
assert bindings["alt-c"] == "exec-and-forget /usr/bin/open -b com.openai.codex"
assert bindings["alt-g"] == "exec-and-forget /usr/bin/open -b com.mitchellh.ghostty"
assert bindings["alt-m"] == "exec-and-forget /usr/bin/open -b com.apple.mail"
assert bindings["alt-n"] == "move-node-to-workspace --focus-follows-window new"
assert bindings["alt-t"] == "exec-and-forget /usr/bin/open -b ru.keepcoder.Telegram"
assert bindings["alt-z"] == "exec-and-forget /usr/bin/open -b app.zen-browser.zen"
assert bindings["alt-shift-c"] == "move-node-to-workspace c"
assert bindings["alt-shift-z"] == "move-node-to-workspace z"
assert bindings["alt-cmd-h"] == "project prev"
assert bindings["alt-cmd-l"] == "project next"
assert bindings["ctrl-alt-cmd-shift-m"] == "move-workspace-to-monitor --wrap-around next"

for number in range(1, 10):
    number = str(number)
    assert bindings[f"alt-{number}"] == f"workspace {number}"
    assert bindings[f"alt-shift-{number}"] == f"move-node-to-workspace {number}"
    assert bindings[f"alt-cmd-{number}"] == f"project {number}"
    assert bindings[f"alt-cmd-shift-{number}"] == f"move-node-to-project {number}"

assert config.get("on-window-detected", []) == []
PY

echo "WinMux config regression checks passed"
