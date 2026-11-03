{
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  identity = builtins.fromJSON (builtins.readFile ./identity.json);
  winmux = pkgs.callPackage ../../packages/winmux-personal.nix { };
in
{
  imports = import ../../profiles/darwin/personal.nix ++ [ ../../modules/personal-migration.nix ];
  networking = {
    hostName = identity.hostName;
    localHostName = identity.hostName;
    computerName = identity.computerName;
  };
  _module.args = {
    winmuxCliOverride = "/Applications/WinMux.app/Contents/Helpers/winmux";
    winmuxSeedOverride = ../../config/migration/winmux.toml;
    winmuxRestoreOnActivation = false;
  };
  # MAS needs an Apple account sign-in; install these in the resumable user step.
  homebrew.masApps = lib.mkForce { };
  home-manager.backupFileExtension = "before-nix";
  # Keep the externally approved launcher stable across Nix upgrades.
  launchd.daemons.nix-daemon.serviceConfig.ProgramArguments = lib.mkIf (identity.externalNixStore
    or false
  ) (lib.mkForce [ "/usr/local/libexec/nix-daemon-launcher" ]);
  system.activationScripts.preActivation.text = lib.mkBefore ''
    ${lib.optionalString (identity.externalNixStore or false) ''
      if [ ! -x /usr/local/libexec/nix-daemon-launcher ] ||
         [ -L /usr/local/libexec/nix-daemon-launcher ] ||
         [ "$(/usr/bin/stat -f '%u:%Lp' /usr/local/libexec/nix-daemon-launcher)" != "0:755" ]; then
        echo "Run scripts/repair-external-nix.sh and approve the launcher before activation." >&2
        exit 1
      fi
    ''}
    if [ -L /Applications/WinMux.app ]; then
      echo "Refusing to replace a symlink at /Applications/WinMux.app" >&2
      exit 1
    fi
    /usr/bin/ditto ${winmux}/Applications/WinMux.app /Applications/WinMux.app
  '';
}
