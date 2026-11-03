{
  homeDirectory,
  lib,
  pkgs,
  username,
  winmuxCliOverride ? null,
  winmuxSeedOverride ? null,
  winmuxRestoreOnActivation ? true,
  ...
}:

let
  # Built from the local fork at ~/Developer/winmux and installed outside the
  # Nix store so personal WinMux patches can be tested directly.
  winmuxAppPath = "/Applications/WinMux.app";
  winmuxCliPath = "${homeDirectory}/Developer/winmux/.local/install/current/bin/winmux";
  activeWinmuxCliPath = if winmuxCliOverride == null then winmuxCliPath else winmuxCliOverride;
  winmuxConfigSeed = pkgs.writeText "winmux.toml" (builtins.readFile (
    if winmuxSeedOverride == null then ../config/winmux/winmux.toml else winmuxSeedOverride
  ));
  winmuxCommand = pkgs.writeShellApplication {
    name = "winmux";
    text = ''
      if [ ! -x "${activeWinmuxCliPath}" ]; then
        echo "winmux: missing CLI from the active local WinMux release: ${activeWinmuxCliPath}" >&2
        exit 127
      fi
      exec "${activeWinmuxCliPath}" "$@"
    '';
  };
  windowManagerToggle = pkgs.writeShellApplication {
    name = "wm-toggle";
    text = ''
      export WINMUX_APP_PATH="${winmuxAppPath}"
      ${builtins.readFile ../config/winmux/window-manager-toggle.sh}
    '';
  };
in
{
  _module.args = {
    winmuxCliOverride = lib.mkDefault null;
    winmuxSeedOverride = lib.mkDefault null;
    winmuxRestoreOnActivation = lib.mkDefault true;
  };
  environment.systemPackages = [
    winmuxCommand
    windowManagerToggle
  ];

  # WinMux stores project labels and colors in its config, so the live file is
  # intentionally mutable. Nix supplies it only on first install.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    winmux_config_dir="${homeDirectory}/.config/winmux"
    winmux_config="$winmux_config_dir/winmux.toml"
    if [ ! -e "$winmux_config" ]; then
      echo >&2 "seeding WinMux configuration..."
      install -d -m 700 -o ${username} -g staff "$winmux_config_dir"
      install -m 600 -o ${username} -g staff ${winmuxConfigSeed} "$winmux_config"
    fi

    ${lib.optionalString winmuxRestoreOnActivation ''
    echo >&2 "restoring saved WinMux mode..."
    /bin/launchctl asuser "$(/usr/bin/id -u ${username})" \
      /usr/bin/sudo -u ${username} --set-home \
      ${windowManagerToggle}/bin/wm-toggle restore
    ''}
  '';

  launchd.user.agents.window-manager-toggle-restore.serviceConfig = {
    ProgramArguments = [
      "${windowManagerToggle}/bin/wm-toggle"
      "restore"
    ];
    RunAtLoad = true;
  };

  # The local fork is updated by rebuilding it, so Sparkle must not replace it.
  system.defaults.CustomUserPreferences."com.zimengxiong.winmux" = {
    SUEnableAutomaticChecks = false;
    SUAutomaticallyUpdate = false;
  };

  home-manager.users.${username}.home.file = {
    ".local/bin/wm-toggle" = {
      source = "${windowManagerToggle}/bin/wm-toggle";
      executable = true;
      force = true;
    };

    ".local/bin/winmux" = {
      source = "${winmuxCommand}/bin/winmux";
      executable = true;
      force = true;
    };
  };
}
