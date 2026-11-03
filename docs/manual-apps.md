# Manual or Later Migration Apps

The old Mac has a large hand-managed `/Applications` set and no Nix/Homebrew
baseline. This config starts with the apps that are common, safe to reinstall,
and easy to manage through Homebrew casks.

Keep these manual unless you explicitly decide to manage them:

- Company or MDM/security apps: Company Portal, Microsoft Defender, ForeScout,
  GlobalProtect, Self Service, CrashPlan.
- Licensed or vendor-specific apps: Setapp, CrossOver, Loopback, Wolfram,
  Tableau Public, PDF Expert, LiquidText, ROLI Connect.
- App Store apps not yet added with `mas`: TestFlight, Things, Flighty,
  Infuse, Slopes, Xcode.
- Already installed or install intentionally outside this starter config:
  1Password, 1Password for Safari, BetterDisplay, Claude, Docker, Linear,
  Ollama, Tailscale, Wireshark.
- Experimental AI/dev apps whose cask names change often: Claudia, Kiro, Trae,
  ChatWise, Cherry Studio, Octarine, WLJS Notebook, AionUi, iMCP, Zed.
- Region-specific or manually sideloaded apps: Quantumult X, Shadowrocket,
  Sideloadly, rednote, UGREEN NAS, Mazda Update Toolbox.

Secrets from the old shell config were intentionally not migrated. Put private
exports in `~/.config/shell/secrets.zsh`, which Home Manager will source.
