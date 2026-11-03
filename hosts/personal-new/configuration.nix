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
  # Reviewed macOS 27.2 defaults with the upstream Nix installer's startup
  # block. Exact hashes only: nix-darwin preserves them as .before-nix-darwin
  # before replacing them, while still refusing unrecognized custom content.
  environment.etc."bashrc".knownSha256Hashes = [
    "8b5e3466922d1ae34bc145e21c7e53e7329a7a7b58b148b436bd954d5e651ac3"
  ];
  environment.etc."zshrc".knownSha256Hashes = [
    "cf0f7b7775b4c058d6085d9e7e57d58c307ca43730f8e4d921a9ef4e530e7e16"
  ];
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
    ${pkgs.python3}/bin/python3 ${../../scripts/install-winmux.py} \
      ${winmux}/Applications/WinMux.app
  '';
}
