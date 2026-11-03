{ lib, pkgs, ... }:

let
  homebrewChinaMirrors = pkgs.writeShellApplication {
    name = "homebrew-china-mirrors";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      gawk
    ];
    text = builtins.readFile ../config/homebrew/china-mirrors.sh;
  };
in

{
  system.activationScripts.extraActivation.text = lib.mkBefore ''
    echo >&2 "configuring Homebrew mirrors..."
    ${homebrewChinaMirrors}/bin/homebrew-china-mirrors /opt/homebrew/etc/homebrew/brew.env >&2
  '';

  homebrew = {
    enable = true;
    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      cleanup = "none";
      upgrade = false;
    };

    brews = [
      "rhettbull/osxphotos/osxphotos"
      "poppler"
      "r"
    ];

    casks = [
      "arc"
      "chatgpt"
      "discord"
      "figma"
      "finicky"
      "font-cascadia-code-nf"
      "font-hack-nerd-font"
      "font-jetbrains-mono-nerd-font"
      "ghostty"
      "google-chrome"
      "jordanbaird-ice"
      "karabiner-elements"
      "logseq"
      "notion"
      "obsidian"
      "openlogi"
      "raycast"
      "sf-symbols"
      "skim"
      "stats"
      "telegram"
      "visual-studio-code"
      "zen"
      "zotero"
      "zoom"
    ];

    masApps = {
      "Fantastical - Calendar" = 975937182;
      "Slack for Desktop" = 803453959;
      "WhatsApp Messenger" = 310633997;
    };
  };
}
