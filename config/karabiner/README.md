# Shared keyboard configuration

`karabiner.json` supplies the same Caps Lock, Tab, Shift, and app shortcuts to
the built-in keyboard and the QK65. The keyboard's base layer should send the
standard keycodes for these keys; its Fn layer can continue to handle connection
modes and other hardware functions.

## QK65 over Bluetooth

The QK65 inspected over Bluetooth reports `QK65 KB` / `OnMicro`, vendor `0x05ac`
(1452), product `0x024f` (591), with **both keyboard and pointing-device usages**.
Karabiner's default pointing-device exclusion also excludes this keyboard.
The explicit device entry sets `ignore: false` so the shared rules apply.

Keep both `is_keyboard: true` and `is_pointing_device: true` in the identifier.
Karabiner's virtual keyboard has the same vendor/product IDs, but does not have
the pointing-device usage. Do not enable all pointing devices to fix this board.
USB and 2.4 GHz identities must be inspected separately before adding entries.

Use the validation and activation procedure in the root `AGENTS.md`. Karabiner's
GUI can replace the managed symlink with a regular file, so also compare the live
device entries and shortcut rules with this source after activation. Verify the
QK65 shows **Modify events** enabled and that the core-service log reports it as
`grabbed`.

For a physical check, Caps Lock+G opens Ghostty, Caps Lock+I moves up, and tapping
the left/right Shift key produces `(`/`)`.

## Firmware

[Qwertykeys' official downloads](https://www.qwertykeys.com/pages/fw) distinguish
wired, tri-mode, and later QK65 models. Select firmware using the actual USB/PCB
identity; the Bluetooth name and Apple-compatible vendor/product IDs alone do
not identify a flash target. Preserve a readable onboard layout before changing
firmware when the board's configuration tool supports exporting it.
