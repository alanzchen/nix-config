# Multi-Host Migration Plan

Historical work-Mac/Oracle plan. As of November 2, 2026, this directory has a
Git baseline and the new personal-Mac workflow is documented in
[`new-mac.md`](new-mac.md). The inventory and older personal-desktop references
below describe the August observation, not the current personal template.

Inventory date: 2026-08-19. Live versions and service state are observations,
not desired-state declarations.

The detailed point-in-time package and service inventory is in
[`inventory-2026-08-19.md`](inventory-2026-08-19.md).

No Nix installation, build activation, service restart, or persistent remote
change was performed while preparing this plan.

## Verified hosts

| Config | Access identity | Platform | Existing Nix | Management boundary |
| --- | --- | --- | --- | --- |
| `alans-macbook-air-1` | local `alan` | `aarch64-darwin`, MacBook Air `Mac17,3` | nix-darwin active | Existing personal config |
| `work-mbp` | SSH `work-mbp`, `alan@UTD98207` | `aarch64-darwin`, MacBook Pro `Mac15,10`, M3 Max | None | DEP/Jamf, FileVault |
| `work-studio` | SSH `alan-mac-studio`, `alan@alan-mac-studio` | `aarch64-darwin`, Mac Studio `Mac14,14`, M2 Ultra | None | DEP/Jamf, FileVault |
| `ubuntu@oracle` | SSH `oracle`, host `instance-20260114-0949` | Ubuntu 24.04, `aarch64-linux` | None | Mutable production VPS |

All three Macs use `/Users/alan`; both work accounts have UID 504. Oracle uses
`/home/ubuntu` with UID 1001. The flake does not encode either UID.

## Composition and ownership

The personal Air retains its previous evaluated system output exactly. Its
Homebrew/MAS apps, macOS defaults, Karabiner, AeroSpace, SketchyBar, shell, and
Git signing remain personal-only.

The two work Macs share `profiles/darwin/work.nix`, which exposes only the
portable system package set from `modules/shared/cli-packages.nix`. Home
Manager and `nix-homebrew` are disabled on both work outputs, so no home files
are claimed and their existing `/opt/homebrew` installations and taps remain
external to Nix.
Their login shell and Touch ID sudo policy are also left unmanaged in this
first stage.

The Oracle output uses `home/minimal.nix`, which imports the same portable
package set through Home Manager. It is a Home Manager target because the live
machine is Ubuntu, not NixOS. No `nixosConfigurations.oracle` is provided until
a separate reprovision design has verified boot, recovery, storage,
networking, and service restoration.

## Work-Mac migration boundary

Both work Macs are DEP-enrolled and use Jamf MDM. Corporate applications such
as Company Portal, CrashPlan, ForeScout, GlobalProtect, Microsoft Defender,
Office, and Self Service remain externally managed.

The machines share these observed top-level Homebrew tools:

- Formulae: `asitop`, `cloudflared`, `ffmpeg`, `gemini-cli`, `gh`, `htop`,
  `iperf3`, `mactop`, `pandoc`, `wget`, and `zsh`.
- Casks: `1password-cli`, `claude-code`, `ghostty`, and `iterm2`.

They are inventory candidates, not current declarations. Homebrew adoption
needs a host-by-host review because the MBP and Studio currently run Homebrew
5.1.14 and 6.0.18 respectively, while the personal flake pins cask metadata for
Homebrew 5.1.11 compatibility.

The MBP already runs a different standalone AeroSpace/SketchyBar/Karabiner
setup plus PostgreSQL 17 and a Tailscale watchdog. The Studio has a different
Karabiner config and runs code-server, OpenClaw, local web/MLX services, and a
Cloudflare tunnel. The personal desktop modules must not be enabled on either
host until their live files and agents have been captured and reconciled.

The Studio also has an App Store Tailscale daemon and a newer Homebrew
`tailscale` CLI. That version split should be resolved deliberately rather than
folded into this migration.

## Oracle migration boundary

The operations source of truth is `/home/ubuntu/sys_admin` (mounted locally via
CloudMounter). The live checkout is dirty and ahead of its remote; it must not
be replaced from Git during a Nix migration.

The VPS currently has about 50 running containers across Coolify and direct
Compose projects, plus host PostgreSQL, Tailscale exit-node routing,
cloudflared, Squid, EasyTier/GlobalProtect tunnels, custom systemd units and
timers, user cron jobs, and Oracle-specific boot/network/firewall behavior.
Its 193 GiB root filesystem was already 82% used at inventory time, so the Nix
store needs a disk-headroom budget before installation.
Critical mutable state includes `/data/coolify`, `/var/lib/docker`,
`/var/lib/postgresql`, `/home/ubuntu/projects`, and frozen live paths under
`/home/ubuntu/sys_admin/{openclaw,rclone}`.

The live baseline also has `cc-connect` and `openchamber` restart-looping, and
the latest server-backup unit failed. Those conditions need an explicit
repair-or-accept decision before service behavior is translated into Nix.

Phase one must not manage those services or the existing shell and Git files.
The latter currently bootstrap Oh My Zsh, NVM, Bun, Cargo, Pipx, and other
mutable runtimes referenced by live services. Secrets remain in their current
external files until a separate secret-management design is approved.
Home Manager's user-systemd integration is disabled so phase one cannot reload
the live user service manager.

A future NixOS reprovision must prove backup and recovery first, then model at
least OCI/UEFI boot, DHCP/RA, the Oracle agent, SSH port 49222, Tailscale
exit-node tuning, Docker address pools and published ports, PostgreSQL and
Coolify state, FUSE mounts, service users, timers, and firewall rules.

## Proposed sequence

1. Recover or establish repository history. This directory currently has no
   `.git` metadata; `.gitignore` now excludes `result` and `.superpowers/` so a
   future reviewed baseline does not ingest generated artifacts.
2. Keep the personal Air as the reference host. Confirm its evaluated output
   remains identical after every structural change.
3. Review the portable package list, then install Nix on only one work Mac
   after confirming Jamf policy. Build the target without activating it and
   inspect the closure and activation script.
4. Pilot the minimal profile on the work MBP. Preserve its current shell,
   Git, UI configs, launch agents, and Homebrew ownership. Observe a restart
   cycle before considering the Studio.
5. Repeat the build-only and manifest review for the Studio, including its
   local services and Tailscale client/daemon ownership.
6. Install Nix on Oracle only after confirming disk headroom and a rollback
   path. Build `ubuntu@oracle` without activation, inspect its manifest, then
   schedule a packages-only Home Manager pilot.
7. Translate applications and services incrementally. Each newly managed
   component needs an explicit old owner, new owner, state path, secret source,
   rollback, and post-restart verification.

Until those reviews occur, use evaluation commands only; do not run any
`switch`, activation script, remote deployment, or NixOS conversion.
