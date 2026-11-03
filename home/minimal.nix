{
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  home = {
    inherit username homeDirectory;
    stateVersion = "25.05";
    packages = import ../modules/shared/cli-packages.nix { inherit pkgs; };
  };

  # This profile intentionally does not own shell or Git dotfiles.
  programs.home-manager.enable = true;

  # Avoid even a user-systemd daemon reload during the packages-only phase.
  systemd.user.enable = false;
}
