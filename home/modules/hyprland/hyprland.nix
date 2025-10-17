{ config, pkgs, inputs, system, ... }: {
  imports = [
    ./settings.nix
    ./submaps.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${system}.hyprland;
    xwayland.enable = true;
    sourceFirst = true;
    importantPrefixes = [ "$" "bezier" "source" "name" "output" ];

    plugins = [
      inputs.hyprsplit.packages.${system}.hyprsplit
    ];
  };
}
