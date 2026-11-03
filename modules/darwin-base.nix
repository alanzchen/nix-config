{
  lib,
  pkgs,
  username,
  homeDirectory,
  hostPlatform,
  manageUserShell,
  enableTouchIdSudo,
  ...
}:

{
  system.primaryUser = username;

  users.users.${username} = {
    home = homeDirectory;
  }
  // lib.optionalAttrs manageUserShell { shell = pkgs.zsh; };

  programs.zsh.enable = manageUserShell;
  environment.shells = lib.optionals manageUserShell [ pkgs.zsh ];

  nix = {
    enable = true;
    package = pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        username
      ];
      build-users-group = "nixbld";
      extra-platforms = lib.optionals (hostPlatform == "aarch64-darwin") [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 3;
        Minute = 15;
      };
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs = {
    hostPlatform = hostPlatform;
    config.allowUnfree = true;
  };

  security.pam.services.sudo_local.touchIdAuth = enableTouchIdSudo;

  system.stateVersion = 6;
}
