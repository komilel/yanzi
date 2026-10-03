{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./overload.nix
  ];

  programs.nvf.settings.vim = {
    lsp = {
      enable = true;

      mappings = {
        goToDeclaration = "gD";
        goToDefinition = "gd";
        goToType = "<leader>D";
        hover = "K";
        listDocumentSymbols = "<leader>ds";
        listImplementations = "gI";
        listReferences = "gr";
        listWorkspaceFolders = "<leader>lwf";
        listWorkspaceSymbols = "<leader>lws";
        # These are global mappings in opts_and_keys.nix, not LSP-dependent.
        nextDiagnostic = null;
        previousDiagnostic = null;
        openDiagnosticFloat = null;
        removeWorkspaceFolder = "<leader>lwr";
        renameSymbol = "<leader>rn";
        signatureHelp = "<leader>ls";
        format = null;
        toggleFormatOnSave = null;
      };

      formatOnSave = true;

      lspkind.enable = false;

      lspsaga.enable = false;

      # Initialize once per buffer in autocmds.nix; do not toggle on each LspAttach.
      inlayHints.enable = false;

      trouble = {
        enable = true;
        mappings = {
          documentDiagnostics = "<leader>xd";
          lspReferences = "<leader>xr";
          symbols = "<leader>xs";
          workspaceDiagnostics = "<leader>xw";
        };
      };

      otter-nvim.enable = true;

      presets.tailwindcss-language-server.enable = true;
    };

    formatter.conform-nvim = {
      enable = true;
      setupOpts = {
        # One synchronous pass before writing, never another pass after writing.
        format_after_save = null;
        format_on_save = lib.generators.mkLuaInline ''
          function(bufnr)
            if not vim.g.formatsave or vim.b[bufnr].disableFormatSave then
              return
            end
            return { lsp_format = "fallback", timeout_ms = 1500 }
          end
        '';
      };
    };

    lazy.plugins = with pkgs.vimPlugins; {
      "glance.nvim" = {
        enabled = true;
        package = glance-nvim;
        cmd = "Glance";

        setupModule = "glance";
        setupOpts = {
          border = {
            enable = true;
          };
        };

        keys = [
          {
            key = "gpd";
            mode = "n";
            action = "<cmd>Glance definitions<cr>";
            desc = "Glance: definitions";
          }

          {
            key = "gpr";
            mode = "n";
            action = "<cmd>Glance references<cr>";
            desc = "Glance: references";
          }

          {
            key = "gpt";
            mode = "n";
            action = "<cmd>Glance type_definitions<cr>";
            desc = "Glance: types";
          }

          {
            key = "gpi";
            mode = "n";
            action = "<cmd>Glance implementations<cr>";
            desc = "Glance: implementations";
          }
        ];
      };
    };
  };
}
