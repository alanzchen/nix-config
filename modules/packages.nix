{ inputs, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bash
    bat
    curl
    direnv
    fd
    gh
    git
    git-lfs
    htop
    iina
    jq
    just
    mas
    nil
    nixfmt
    nodejs_24
    postgresql_17
    pure-prompt
    ripgrep
    starship
    texliveFull
    (callPackage ../packages/tinycast.nix { })
    tree
    uv
    wget
    yq
    zoxide
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
  ];
}
