{
  config,
  pkgs,
  inputs,
  system,
  ...
}: {
  imports = [
    ./packages.nix
    ./niri.nix
    ./gtk.nix
    ./zoxide.nix
    ./oh-my-posh/oh-my-posh.nix
    ./kitty.nix
    ./wallust/wallust.nix
    ./vscode.nix
    ./zed.nix
    ./git.nix
    ./tmux.nix
    ./proxy.nix
  ];
}
