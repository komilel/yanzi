{config, ...}: let
  Home = "${config.home.homeDirectory}";
in {
  programs.wallust = {
    enable = true;

    settings = {
      backend = "fastresize";
      palette = "dark";
      check_contrast = true;

      templates = {
        waybar = {
          template = "waybar.css";
          target = "${Home}/.cache/wallust/waybar.css";
        };

        rofi = {
          src = "colors-rofi.rasi";
          dst = "${Home}/.cache/wallust/colors-rofi.rasi";
        };

        niri = {
          src = "colors-niri.kdl";
          dst = "${Home}/.cache/wallust/colors-niri.kdl";
        };
      };
    };
  };

  xdg.configFile."wallust/templates".source = ./templates;
}
