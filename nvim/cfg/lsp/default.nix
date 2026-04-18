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
        nextDiagnostic = "]d";
        previousDiagnostic = "[d";
        openDiagnosticFloat = "<leader>e";
        removeWorkspaceFolder = "<leader>lwr";
        renameSymbol = "<leader>rn";
        signatureHelp = "<leader>ls";
        toggleFormatOnSave = "<leader>lf";
      };

      formatOnSave = true;

      lspkind.enable = false;

      lspsaga.enable = false;

      inlayHints.enable = true;

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
