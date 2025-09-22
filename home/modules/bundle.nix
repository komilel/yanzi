{ config, ... }: {
  imports = [
    ./hyprland/hyprland.nix
    ./hyprland/hyprlock.nix
    ./hyprland/hypridle.nix
    ./waybar/waybar.nix
    ./gtk.nix
    ./zoxide.nix
    ./oh-my-posh/oh-my-posh.nix
    ./kitty.nix
    ./wallust/wallust.nix
    ./rofi.nix
    ./dunst/dunst.nix
    ./git.nix
  ];
}
