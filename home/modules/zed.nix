{pkgs, ...}: {
  programs.zed-editor = {
    enable = true;

    extensions = [
      # General
      "catppuccin-blur"

      # Languages
      "nix"
      "lua"
      "csharp"

      # Snippets
      "python-snippets"
      "solid-typescript-snippets"
      "csharp-snippets"

      # SE
      "plantuml"
    ];
  };
}
