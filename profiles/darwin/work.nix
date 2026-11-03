{ pkgs, ... }:

{
  # Phase-zero work profile. Home Manager, Homebrew, MAS, macOS defaults,
  # Karabiner and WinMux remain deliberately unmanaged.
  environment.systemPackages = import ../../modules/shared/cli-packages.nix { inherit pkgs; };
}
