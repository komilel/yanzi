{pkgs, ...}: {
  programs.zed-editor = {
    enable = true;

    extraPackages = with pkgs; [
      nixd
      alejandra

      rust-analyzer
      rustfmt
    ];

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
