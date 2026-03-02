{pkgs, ...}: {
  programs.zed-editor = {
    enable = true;

    extensions = [
      # General
      "catppuccin-blur"

      # Languages
      "nix"
      "lua"

      # Snippets
      "python-snippets"
      "solid-typescript-snippets"

      # SE
      "plantuml"
    ];
  };
}
