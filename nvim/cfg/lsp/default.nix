{
  pkgs,
  lib,
  ...
}: {
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
        listWorkspaceFolders = "<leader>wl";
        listWorkspaceSymbols = "<leader>ws";
        nextDiagnostic = "]d";
        previousDiagnostic = "[d";
        openDiagnosticFloat = "<leader>e";
        removeWorkspaceFolder = "<leader>wr";
        renameSymbol = "<leader>rn";
        signatureHelp = "<leader>ls";
        toggleFormatOnSave = "<leader>lf";
      };

      formatOnSave = true;

      lspkind.enable = false;

      lspsaga.enable = false;

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
  };
}
