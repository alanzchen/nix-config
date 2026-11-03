# Agent Notes

## Sudo

When a command needs root privileges, prefer `sudo -S` so the shared terminal session can provide the password over stdin. This is especially relevant for `darwin-rebuild switch`, because system activation must run as root.

## WinMux

WinMux is the window manager on the personal Mac. The active app is built from
the fork at `~/Developer/winmux` and installed at `/Applications/WinMux.app`.
Keep the native macOS menu bar visible because WinMux provides its own
project/workspace sidebar. `packages/winmux.nix` is retained only as the
official-release fallback; it is not the active package.

The live `~/.config/winmux/winmux.toml` stays mutable because WinMux records
project labels and colors in it. `config/winmux/winmux.toml` is a first-install
seed, not a force-managed symlink. `wm-toggle` owns the coordinated WinMux state,
and its one-shot launch agent restores that state at login.

Caps Lock is a Karabiner variable layer, not a general Option modifier. When
adding or changing a Caps Lock WinMux shortcut, update the complete input path:

- Add the matching `alt-<key>` action to both the live and seed WinMux configs.
- Add an explicit `caps_lock_super_key` manipulator to
  `config/karabiner/karabiner.json` that emits the key with `left_option`.
- Add regression coverage for both the WinMux action and Karabiner translation.

The live Karabiner config is a Nix-managed symlink. After validation, activate
with `sudo -S darwin-rebuild switch --flake .#alans-macbook-air-1`, then verify
that Karabiner reloaded the config and that `/Applications/WinMux.app` is the
active manager. A valid WinMux binding is unreachable if its Karabiner mapping
is missing.

When changing this integration, verify with:

```sh
for test in config/winmux/tests/*.sh; do bash "$test"; done
nix-instantiate --parse --eval --strict modules/window-manager.nix >/dev/null
nix build .#darwinConfigurations.alans-macbook-air-1.system --no-link
```
