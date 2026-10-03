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

    # Work around the pinned NVF StyLua preset referencing an undefined global `util`.
    # Reuse its normal arguments so selection formatting respects the same indent style.
    formatter.conform-nvim.setupOpts.formatters.stylua.range_args = lib.mkForce (lib.generators.mkLuaInline ''
      function(self, ctx)
        local start_offset, end_offset = require("conform.util").get_offsets_from_range(ctx.buf, ctx.range)
        return vim.list_extend(self.args(self, ctx), {
          "--range-start", tostring(start_offset),
          "--range-end", tostring(end_offset),
        })
      end
    '');

    # Keep JS/JSX/TSX on the same project-gated ESLint preset as TypeScript.
    diagnostics.nvim-lint.linters_by_ft = {
      javascript = ["eslint_d"];
      javascriptreact = ["eslint_d"];
      typescriptreact = ["eslint_d"];
    };

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
      # NVF separates JSX/TSX parsers, formatting and LSP filetypes.
      tsx = {
        enable = true;
        extraDiagnostics.enable = false; # Do not silently introduce Biome alongside ESLint.
      };

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
