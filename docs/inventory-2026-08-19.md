# Host Inventory: 2026-08-19

This is a read-only migration snapshot. Versions, packages, and running state
will drift; refresh the target immediately before any cutover. No secret values
or private key material are recorded here.

## Personal MacBook Air

- Identity: `alans-macbook-air-1`, user `alan`, `/Users/alan`.
- Hardware: MacBook Air `Mac17,3`, arm64, 24 GiB RAM.
- OS: macOS 26.5.2 (`25F84`).
- Nix: 2.34.7 with nix-darwin active.
- Homebrew: 5.1.11 under `/opt/homebrew`.
- Role in this flake: reference personal desktop configuration.

## Work MacBook Pro

- SSH alias: `work-mbp`; identity `alan@UTD98207`.
- Names: ComputerName, LocalHostName, and HostName are all `UTD98207`.
- Hardware: MacBook Pro `Mac15,10`, M3 Max, 14 cores, 96 GiB RAM.
- OS: macOS 26.6.1 (`25G76`), arm64; Rosetta installed.
- Account: UID 504, `/Users/alan`, `/bin/zsh`.
- Management: DEP and user-approved Jamf MDM; FileVault enabled.
- Nix: absent, including `/nix` and the nix-daemon launch service.
- Homebrew: 5.1.14 under `/opt/homebrew`.

Top-level formulae:

```text
apktool asitop automake boost bzip2 capnp catch2 cloudflared cmake cppcheck
dvisvgm eigen elixir felixkratz/formulae/borders
felixkratz/formulae/sketchybar ffmpeg flyctl gcc@13 gemini-cli gh ghidra git
git-lfs glfw htop iperf3 libusb lima mactop
malpern/tap/sketchybar-toggle mise molten-vk openssl@3.0 oven-sh/bun/bun
pandoc portaudio postgresql@17 pure pyenv-virtualenv radare2
rfidresearchgroup/proxmark3/arm-none-eabi-gcc
rfidresearchgroup/proxmark3/proxmark3 rust spoof-mac supabase/tap/supabase
tree wget whisperkit-cli zlib zsh
```

Casks:

```text
1password-cli aerospace aionui android-platform-tools calibre claude-code
cmake-app codexbar copilot-for-xcode docker-desktop font-cascadia-code-nf
font-fira-code font-hack-nerd-font font-sketchybar-app-font
gcc-arm-embedded ghostty git-credential-manager iterm2 jordanbaird-ice
quarto r-app wireshark wireshark-app wljs-notebook
```

Existing ownership:

- Regular `.zshrc`, `.zprofile`, and `.zshenv` files.
- Standalone Aerospace, SketchyBar, and Karabiner configs; all differ from this
  repository, and SketchyBar uses an older directory layout.
- Running PostgreSQL 17, SketchyBar, borders, and a custom Tailscale watchdog.
- Xcode is installed, but `xcode-select` points to Command Line Tools.
- Git SSH signing through 1Password is already enabled.

## Work Mac Studio

- SSH alias: `alan-mac-studio`; identity `alan@alan-mac-studio`.
- Names: ComputerName and LocalHostName `JSOM98196`; HostName
  `alan-mac-studio`.
- Hardware: Mac Studio `Mac14,14`, M2 Ultra, 24 cores, 128 GiB RAM.
- OS: macOS 26.6.1 (`25G76`), arm64; Rosetta installed.
- Account: UID 504, `/Users/alan`, `/bin/zsh`.
- Management: DEP and user-approved Jamf MDM; FileVault enabled.
- Nix: absent, including `/nix` and the nix-daemon launch service.
- Homebrew: 6.0.18 under `/opt/homebrew`.

Top-level formulae:

```text
asitop cloudflared code-server cog docker ffmpeg gemini-cli gh go htop iperf3
libpq mactop mas mysql-client pandoc pkgconf postgresql@18 python@3.12
tailscale texlive tmux wget whisper-cpp yt-dlp zsh
```

Casks:

```text
1password-cli claude-code ghostty iterm2 lm-studio
```

Existing ownership:

- Regular `.zshrc`, `.zprofile`, and `.zshenv` files.
- Standalone Karabiner config differs from this repository; no current
  Aerospace or SketchyBar config.
- Running code-server, OpenClaw gateway, home HTML server, Cloudflare oMLX
  tunnel, and MLX audio server.
- Full Xcode 26.5 is selected.
- The App Store Tailscale daemon is 1.98.2 while the Homebrew CLI is 1.102.2.
- 1Password's SSH agent exists, but Git signing is not currently configured.

## Shared work-Mac software

Shared top-level formulae:

```text
asitop cloudflared ffmpeg gemini-cli gh htop iperf3 mactop pandoc wget zsh
```

Shared casks:

```text
1password-cli claude-code ghostty iterm2
```

These are candidates for a reviewed work profile, not declarations in the
current phase-zero config.

## Oracle VPS

- SSH alias: `oracle`; identity `ubuntu@instance-20260114-0949`.
- OS: Ubuntu 24.04.4 LTS, Oracle kernel 6.17, aarch64 KVM.
- Hardware: 4 vCPU, 23 GiB RAM, no swap.
- Account: UID 1001, `/home/ubuntu`, zsh.
- Storage: 193 GiB usable root filesystem, 82% used.
- Nix: absent, including `/nix`.
- Operations repo: `/home/ubuntu/sys_admin`, dirty and 20 commits ahead of its
  remote at inventory time.

Live platform and service ownership:

- Docker 29.6.1 with 53 containers, 50 running, across 26 Compose projects.
- Coolify source/config/state under `/data/coolify`.
- Host PostgreSQL 16 under `/var/lib/postgresql/16/main`.
- Tailscale exit-node forwarding/tuning, cloudflared, Squid, EasyTier,
  GlobalProtect, and Oracle-specific firewall/metadata rules.
- Custom root and user systemd units, timers, and paths; two user cron jobs.
- Direct repo-owned Compose stacks under `/home/ubuntu/sys_admin/services` and
  a separate EasyTier stack under `/opt/easytier`.
- Frozen live paths `/home/ubuntu/sys_admin/openclaw` and
  `/home/ubuntu/sys_admin/rclone`.
- Other critical state in `/var/lib/docker`, `/data/coolify`,
  `/var/lib/postgresql`, `/home/ubuntu/projects`, `/home/ubuntu/.config`, and
  `/home/ubuntu/.local/share`.

Observed baseline failures:

- `cc-connect` and `openchamber` were restart-looping.
- The latest `server-backup.service` run had failed.

The initial Home Manager output is packages-only. Docker, Coolify, PostgreSQL,
systemd, cron, network tunnels, forwarding, firewall rules, shell/Git files,
state, and secrets remain explicitly out of scope.
