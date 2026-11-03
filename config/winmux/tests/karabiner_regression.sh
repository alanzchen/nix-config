#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

python3 - "$ROOT/config/karabiner/karabiner.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    config = json.load(stream)

serialized = json.dumps(config).lower()
assert "aerospace" not in serialized

# QK65 Bluetooth advertises both keyboard and pointing usages. Enable this
# composite device explicitly; the virtual keyboard shares its VID/PID but
# does not have the pointing-device identifier.
qk65_identifiers = {
    "vendor_id": 1452,
    "product_id": 591,
    "is_keyboard": True,
    "is_pointing_device": True,
}
qk65 = next(
    device
    for device in config["profiles"][0]["devices"]
    if device["identifiers"] == qk65_identifiers
)
assert qk65["ignore"] is False

rules = config["profiles"][0]["complex_modifications"]["rules"]
rule = next(rule for rule in rules if "caps lock super key" in rule["description"].lower())
assert "winmux" in rule["description"].lower()

caps_lock = next(
    manipulator
    for manipulator in rule["manipulators"]
    if manipulator["from"].get("key_code") == "caps_lock"
)
assert caps_lock["parameters"] == {
    "basic.to_if_alone_timeout_milliseconds": 200,
}
assert "to_delayed_action" not in caps_lock

tab = next(
    manipulator
    for manipulator in rule["manipulators"]
    if manipulator["from"].get("key_code") == "tab"
)
assert tab["from"] == {"key_code": "tab"}
assert tab["parameters"] == {
    "basic.to_if_alone_timeout_milliseconds": 350,
    "basic.to_if_held_down_threshold_milliseconds": 350,
}
assert tab["to_if_alone"] == [{"key_code": "tab"}]
assert "to_delayed_action" not in tab
assert tab["to_if_held_down"] == [
    {"key_code": "o", "modifiers": ["left_option"]},
]

basecamp_rule = next(rule for rule in rules if rule["description"] == "Basecamp: command-p sends shift-j")
assert basecamp_rule["manipulators"] == [
    {
        "type": "basic",
        "from": {
            "key_code": "p",
            "modifiers": {"mandatory": ["command"]},
        },
        "to": [{"key_code": "j", "modifiers": ["left_shift"]}],
        "conditions": [
            {
                "type": "frontmost_application_if",
                "bundle_identifiers": [r"^com\.basecamp\.basecamp3$"],
            }
        ],
    }
]

ghostty_rule = next(rule for rule in rules if rule["description"] == "Ghostty: command-t sends command-n")
assert ghostty_rule["manipulators"] == [
    {
        "type": "basic",
        "from": {
            "key_code": "t",
            "modifiers": {"mandatory": ["command"]},
        },
        "to": [{"key_code": "n", "modifiers": ["left_command"]}],
        "conditions": [
            {
                "type": "frontmost_application_if",
                "bundle_identifiers": [r"^com\.mitchellh\.ghostty$"],
            }
        ],
    }
]

def variable_is(manipulator, name):
    return any(
        condition.get("type") == "variable_if" and condition.get("name") == name
        for condition in manipulator.get("conditions", [])
    )

def mapping(key, variable):
    return next(
        manipulator
        for manipulator in rule["manipulators"]
        if manipulator["from"].get("key_code") == key and variable_is(manipulator, variable)
    )

assert mapping("o", "caps_lock_super_key")["to"] == [
    {"key_code": "o", "modifiers": ["left_option"]}
]
assert mapping("b", "caps_lock_super_key")["to"] == [
    {"key_code": "b", "modifiers": ["left_option"]}
]
assert mapping("c", "caps_lock_super_key")["to"] == [
    {"key_code": "c", "modifiers": ["left_option"]}
]
assert mapping("g", "caps_lock_super_key")["to"] == [
    {"key_code": "g", "modifiers": ["left_option"]}
]
assert mapping("m", "caps_lock_super_key")["to"] == [
    {"key_code": "m", "modifiers": ["left_option"]}
]
assert mapping("n", "caps_lock_super_key")["to"] == [
    {"key_code": "n", "modifiers": ["left_option"]}
]
assert mapping("t", "caps_lock_super_key")["to"] == [
    {"key_code": "t", "modifiers": ["left_option"]}
]
assert mapping("z", "caps_lock_super_key")["to"] == [
    {"key_code": "z", "modifiers": ["left_option"]}
]
assert mapping("1", "caps_lock_super_key")["to"] == [
    {"key_code": "1", "modifiers": ["left_option"]}
]
assert mapping("1", "tab_workspace_mover")["to"] == [
    {"key_code": "1", "modifiers": ["left_option", "left_shift"]}
]
assert mapping("spacebar", "tab_workspace_mover")["to"] == [
    {
        "key_code": "m",
        "modifiers": ["left_control", "left_option", "left_command", "left_shift"],
    }
]
PY

echo "WinMux Karabiner regression checks passed"
