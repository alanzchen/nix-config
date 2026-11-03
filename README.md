# Alan's Multi-Host Nix Config

## New personal Mac

The `personal-new` profile and resumable installer use the current personal Mac
as a template. Install/unlock 1Password, enable its SSH agent and CLI integration,
then use the one-line command in [`scripts/new-mac-command.txt`](scripts/new-mac-command.txt).
The configuration is delivered through the private `alanzchen/nix-config` repo.
See [`docs/new-mac.md`](docs/new-mac.md) for prerequisites, captured settings,
credential handling, manual approvals, and the explicit remaining gaps.

The reference Mac is not activated by this workflow. To preview it locally:

```sh
bash scripts/bootstrap-mac.sh --plan
```

This flake is the migration-stage source for one personal Mac, two work Macs,
and an Ubuntu VPS. It is intentionally conservative: the existing personal
Mac configuration remains complete, while new machines start with a small
shared package layer and no service or application takeover.

## Outputs

| Output | Machine | Initial scope |
| --- | --- | --- |
| `darwinConfigurations.personal-new` | New personal Apple-silicon Mac | Full personal template plus migration setup |
| `darwinConfigurations.alans-macbook-air-1` | Personal MacBook Air | Existing full personal configuration |
| `darwinConfigurations.work-mbp` | Work MacBook Pro (`UTD98207`) | nix-darwin base plus portable CLI packages |
| `darwinConfigurations.work-studio` | Work Mac Studio (`JSOM98196`) | nix-darwin base plus portable CLI packages |
| `homeConfigurations."ubuntu@oracle"` | Oracle Ubuntu VPS | Home Manager portable CLI packages only |

The work profiles do not manage Homebrew, Mac App Store apps, macOS defaults,
Karabiner, WinMux, or existing shell and Git files. The Oracle
profile does not manage shell files, Git configuration, systemd services,
Docker, networking, firewall rules, or secrets.

The work profiles also leave the current login shell and Touch ID sudo policy
unchanged until those system-level changes are separately reviewed.

## Validate without activation

These commands evaluate every migration target without switching a machine:

```sh
nix flake check --no-build --all-systems --no-write-lock-file
nix eval --raw '.#darwinConfigurations.work-mbp.system.drvPath'
nix eval --raw '.#darwinConfigurations.work-studio.system.drvPath'
nix eval --raw '.#homeConfigurations."ubuntu@oracle".activationPackage.drvPath'
```

For the work-Mac and Oracle migration, do not run `darwin-rebuild switch` or
`home-manager switch` during the planning stage. The new personal-Mac installer
has its own activation workflow above. See [`docs/migration-plan.md`](docs/migration-plan.md) for the verified
inventory, ownership boundaries, and proposed cutover sequence.

## Configuration shape

- `lib/mk-darwin-host.nix`: parameterized Darwin host constructor.
- `modules/darwin-base.nix`: shared Nix daemon, user, GC, and platform setup.
- `modules/shared/cli-packages.nix`: portable packages shared by the work Macs
  and Oracle.
- `profiles/darwin/personal.nix`: the existing personal desktop modules.
- `profiles/darwin/work.nix`: shared CLI packages and the minimal work-machine
  boundary, with Home Manager disabled.
- `home/alan.nix`: personal Home Manager shell and Git configuration.
- `home/minimal.nix`: package-only Home Manager profile for Oracle.
- `hosts/*/configuration.nix`: verified per-Mac identity.

The pinned `homebrew-cask` revision is an intentional compatibility boundary.
The current flake pins Homebrew 7.0.3. Do not run a general
`nix flake update` as part of this structural migration.

## Personal Mac window manager

`wm-toggle` controls WinMux on the personal Mac. The native macOS menu bar
remains visible, and the saved mode is restored after activation and at login:

```sh
wm-toggle
wm-toggle on
wm-toggle off
wm-toggle status
wmt
```

WinMux treats projects as the outer layer and numbered workspaces as a lazy
inner layer: empty workspaces disappear rather than being kept alive. Holding
unmodified `Tab` for 350 ms opens the project/sidebar picker. Modified Tab
keys, including `Shift+Tab`, pass through natively; `Caps Lock+O` remains an
explicit shortcut. Inside the active project, `Caps
Lock+1` through `Caps Lock+9` switch workspaces; adding Shift moves the focused
window. `Caps Lock+B`, `Caps Lock+C`, `Caps Lock+T`, and `Caps Lock+Z` activate
or launch Basecamp, ChatGPT, Telegram, and Zen. Apps remain in the current
project/workspace unless moved manually.

The active WinMux app is built from `~/Developer/winmux` and installed at
`/Applications/WinMux.app`; `packages/winmux.nix` remains available as an
official-release fallback. Its live config remains mutable at
`~/.config/winmux/winmux.toml` because WinMux records project names and colors
there; `config/winmux/winmux.toml` is the first-install seed. The local fork's
`workspace-sidebar.stay-on-top = false` setting keeps the Dock above the sidebar.

## Secrets

Do not put API keys, service environment files, or private SSH material in this
repository. The personal shell loads private exports from:

```sh
~/.config/shell/secrets.zsh
```
