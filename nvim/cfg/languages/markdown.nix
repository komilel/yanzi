{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
    languages = {
      markdown = {
        enable = true;
        treesitter.enable = true;
        lsp.enable = true;

        extensions = {
          render-markdown-nvim = {
            enable = true;

            setupOpts = {
              heading = {
                sign = false;
                icons = [];
              };
              file_types = ["markdown" "codecompanion"];
            };
          };
        };
      };
    };
  };
}
