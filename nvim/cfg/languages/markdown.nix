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

        format = {
          enable = true;
          type = ["prettierd"];
        };

        extensions = {
          render-markdown-nvim = {
            enable = true;

            setupOpts = {
              preset = "lazy";
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
