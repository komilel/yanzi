{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./csharp.nix
    ./markdown.nix
  ];

  programs.nvf.settings.vim = {
    extraPackages = with pkgs; [
      # For gopls
      go
    ];

    languages = {
      enableFormat = true;
      enableTreesitter = true;
      enableExtraDiagnostics = true;

      nix = {
        enable = true;
        extraDiagnostics.enable = true;
        format.enable = true;
        lsp = {
          enable = true;
          servers = ["nixd"];
        };
      };

      bash.enable = true;

      json.enable = true;

      sql.enable = true;

      html.enable = true;

      css.enable = true;

      typescript.enable = true;

      go.enable = true;

      lua.enable = true;

      zig.enable = true;

      python.enable = true;

      rust = {
        enable = true;
        extensions.crates-nvim.enable = true;
      };

      toml.enable = true;

      xml.enable = true;
    };
  };
}
