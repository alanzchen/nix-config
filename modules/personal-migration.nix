{
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  credentials = builtins.fromJSON (builtins.readFile ../config/migration/credentials.json);
  publicKeys = credentials.additionalSshPublicKeys // {
    github = credentials.githubSshPublicKey;
  };
  agentConfig = (pkgs.formats.toml { }).generate "agent.toml" {
    ssh-keys = lib.mapAttrsToList (
      _: reference:
      let
        parts = lib.splitString "/" reference;
      in
      {
        vault = builtins.elemAt parts 2;
        item = builtins.elemAt parts 3;
      }
    ) publicKeys;
  };
  agentsview = pkgs.callPackage ../packages/agentsview.nix { };
  colab = pkgs.callPackage ../packages/colab.nix { };
  colabSsh = pkgs.writeShellApplication {
    name = "colab-ssh-config";
    runtimeInputs = [
      pkgs.python3
      pkgs.cloudflared
    ];
    text = ''exec python3 ${../scripts/colab-ssh-config.py} "$@"'';
  };
  startAgentsview = pkgs.writeShellApplication {
    name = "agentsview-spoke-start";
    runtimeInputs = [ pkgs.python3 ];
    text = "exec python3 ${../scripts/agentsview-start.py} ${agentsview}/bin/agentsview /Applications/Tailscale.app/Contents/MacOS/Tailscale";
  };
  withSecrets = pkgs.writeShellApplication {
    name = "with-secrets";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../scripts/with-secrets.py} "$@"
    '';
  };
in
{
  homebrew.casks = [
    # The GUI is the bootstrap prerequisite, installed by its vendor installer.
    # Asking Homebrew to reinstall it can conflict with that existing app.
    "1password-cli"
    "basecamp"
    "betterdisplay"
    "tailscale-app"
    "hammerspoon"
    "claude-code"
    "codex"
  ];
  environment.systemPackages = [
    withSecrets
    pkgs.python3
    agentsview
    colab
    colabSsh
    pkgs.cloudflared
  ];
  home-manager.users.${username} = {
    home.file.".config/1Password/ssh/agent.toml".source = agentConfig;
    home.file.".ssh/config.d/20-migration-hosts.conf".source = ../config/migration/ssh-hosts.conf;
    home.file.".ssh/known_hosts_migration".source = ../config/migration/known_hosts;
    home.file.".ssh/known_hosts_comma".source = ../config/migration/known_hosts_comma;
    launchd.agents.agentsview-spoke = {
      enable = true;
      config = {
        Label = "io.agentsview.nix-spoke";
        ProgramArguments = [ "${startAgentsview}/bin/agentsview-spoke-start" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 30;
        StandardOutPath = "${homeDirectory}/.local/state/mac-bootstrap/agentsview.stdout.log";
        StandardErrorPath = "${homeDirectory}/.local/state/mac-bootstrap/agentsview.stderr.log";
        EnvironmentVariables = {
          HOME = homeDirectory;
        };
      };
    };
    home.file.".hammerspoon/init.lua".source = ../config/hammerspoon/init.lua;
    home.file.".hammerspoon/chatgpt-new-window.lua".source =
      ../config/hammerspoon/chatgpt-new-window.lua;
    home.file.".ssh/config".text = ''
      # Optional host-specific non-secret settings come first.
      Include ~/.ssh/config.d/*
      Host *
        IdentityAgent "${homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        UserKnownHostsFile ~/.ssh/known_hosts ~/.ssh/known_hosts_migration
    '';
    home.activation.sshConfigDirectory = {
      after = [ "writeBoundary" ];
      before = [ "setupLaunchAgents" ];
      data = ''
        mkdir -p "${homeDirectory}/.ssh/config.d" "${homeDirectory}/.local/state/mac-bootstrap"
        chmod 700 "${homeDirectory}/.ssh" "${homeDirectory}/.ssh/config.d" "${homeDirectory}/.local/state/mac-bootstrap"
      '';
    };
  };
}
