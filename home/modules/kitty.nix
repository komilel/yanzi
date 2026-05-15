{
  config,
  pkgs,
  ...
}: {
  programs.kitty = {
    enable = true;

    font = {
      name = "JetBrainsMono";
      size = 12;
    };

    themeFile = "Catppuccin-Mocha";

    settings = {
      touch_scroll_multiplier = 3.0;
      enable_audio_bell = "no";
      window_padding_width = "0 0";
      background_opacity = 0.7;
      confirm_os_window_close = 0;
      shell_integration = "no-cursor";
    };
  };
}
