{config, pkgs, ...} : {
  imports = [ ./modules.nix ];

  programs.waybar = {
    enable = true;
    settings = {
      defaultBar = {
        layer = "top"; # Waybar at top layer
        position = "top"; # Waybar position
        margin-top = 0;
        margin-left = 0;
        margin-right = 0;
        margin-bottom = 0;
        # "height": 30, # Waybar height (to be removed for auto height)
        # "width": 1280, # Waybar width
        spacing = 0; # Gaps between modules

        reload_style_on_change = true;

        modules-left = [
          "custom/launcher"
          "hyprland/workspaces"
          "mpris"
        ];

        modules-center = [
          "clock"
        ];

        modules-right = [
          "group/stats"
          "hyprland/language"
          "tray"
        ];
      };
    };

    style = (builtins.readFile ./style.css);
  };
}
