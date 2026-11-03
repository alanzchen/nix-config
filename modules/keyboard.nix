{ username, ... }:

{
  home-manager.users.${username}.xdg.configFile."karabiner/karabiner.json" = {
    source = ../config/karabiner/karabiner.json;
    force = true;
  };
}
