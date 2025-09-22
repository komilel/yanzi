{ config, pkgs, ... }: {
  imports = [
    ./settings.nix
    ./submaps.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    sourceFirst = true;
    importantPrefixes = [ "$" "bezier" "source" "name" "output" ];

    plugins = [
      pkgs.hyprlandPlugins.hyprsplit
    ];
  };
}
