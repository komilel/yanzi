{config, ...}:
let
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
        hyprland = {
          src = "colors-hyprland.conf";
          dst = "${Home}/.cache/wallust/colors-hyprland.conf";
        };
        rofi = {
          src = "colors-rofi.rasi";
          dst = "${Home}/.cache/wallust/colors-rofi.rasi";
        };
      };
    };
  };

  xdg.configFile."wallust/templates".source = ./templates;
}
