{
  config,
  pkgs,
  inputs,
  system,
  ...
}: {
  imports = [
    # ./hyprland/hyprland.nix
    ./hyprland/hyprlock.nix
    ./hyprland/hypridle.nix
    ./waybar/waybar.nix
    ./niri.nix
    ./gtk.nix
    ./zoxide.nix
    ./oh-my-posh/oh-my-posh.nix
    ./kitty.nix
    ./wallust/wallust.nix
    ./rofi.nix
    ./vscode.nix
    ./zed.nix
    ./dunst/dunst.nix
    ./git.nix
    ./tmux.nix
  ];
}
