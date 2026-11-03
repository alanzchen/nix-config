{ pkgs, username, homeDirectory, ... }:
let
  withSecrets = pkgs.writeShellApplication {
    name = "with-secrets";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../scripts/with-secrets.py} "$@"
    '';
  };
in {
  homebrew.casks = [
    # The GUI is the bootstrap prerequisite, installed by its vendor installer.
    # Asking Homebrew to reinstall it can conflict with that existing app.
    "1password-cli" "basecamp" "betterdisplay" "tailscale-app" "hammerspoon"
    "claude-code" "codex"
  ];
  environment.systemPackages = [ withSecrets pkgs.python3 ];
  home-manager.users.${username} = {
    home.file.".hammerspoon/init.lua".source = ../config/hammerspoon/init.lua;
    home.file.".hammerspoon/chatgpt-new-window.lua".source = ../config/hammerspoon/chatgpt-new-window.lua;
    home.file.".ssh/config".text = ''
      # Optional host-specific non-secret settings come first.
      Include ~/.ssh/config.d/*
      Host *
        IdentityAgent "${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    '';
    home.activation.sshConfigDirectory = {
      after = [ "writeBoundary" ];
      before = [ ];
      data = ''mkdir -p "${homeDirectory}/.ssh/config.d"; chmod 700 "${homeDirectory}/.ssh" "${homeDirectory}/.ssh/config.d"'';
    };
  };
}
