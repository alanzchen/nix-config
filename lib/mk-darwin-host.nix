{ inputs }:

{
  name,
  hostName ? name,
  system ? "aarch64-darwin",
  username ? "alan",
  homeDirectory ? "/Users/${username}",
  modules ? [ ],
  homeModule ? null,
  enableNixHomebrew ? false,
  enableRosetta ? false,
  manageUserShell ? true,
  enableTouchIdSudo ? true,
}:

let
  inherit (inputs) nixpkgs;
  lib = nixpkgs.lib;

  specialArgs = {
    inherit
      inputs
      username
      homeDirectory
      hostName
      manageUserShell
      enableTouchIdSudo
      ;
    hostPlatform = system;
  };

  nixHomebrewModules = lib.optionals enableNixHomebrew [
    inputs.nix-homebrew.darwinModules.nix-homebrew
    (
      { pkgs, ... }:
      {
        nix-homebrew = {
          enable = true;
          # Pin the runtime independently of nix-homebrew's bundled release.
          package = pkgs.callPackage ../packages/homebrew.nix { src = inputs.homebrew-src; };
          inherit enableRosetta;
          user = username;
          taps = {
            "homebrew/homebrew-core" = inputs.homebrew-core;
            "homebrew/homebrew-cask" = inputs.homebrew-cask;
            "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
            "rhettbull/homebrew-osxphotos" = inputs.homebrew-osxphotos;
          };
          mutableTaps = false;
        };
      }
    )
  ];

  homeManagerModules = lib.optionals (homeModule != null) [
    inputs.home-manager.darwinModules.home-manager
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = specialArgs;
        users.${username} = import homeModule;
      };
    }
  ];
in
inputs.nix-darwin.lib.darwinSystem {
  inherit system specialArgs;
  modules = [ ../modules/darwin-base.nix ] ++ modules ++ nixHomebrewModules ++ homeManagerModules;
}
