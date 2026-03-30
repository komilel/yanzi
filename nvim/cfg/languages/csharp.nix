{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
    # Server executable for csharp lsp
    extraPackages = with pkgs; [
      roslyn-ls
    ];

    # Mostly treesitter for c#
    languages.csharp = {
      enable = true;
      lsp.enable = false;
      treesitter.enable = true;
    };

    lazy.plugins = with pkgs.vimPlugins; {
      "roslyn.nvim" = {
        enabled = true;
        package = roslyn-nvim;
        ft = "cs";

        setupModule = "roslyn";
        setupOpts = {
          opts = {
            filewatching = "off";
          };
        };

        after = ''
          vim.lsp.config("roslyn", {
            settings = {
              ["csharp|inlay_hints"] = {
                  csharp_enable_inlay_hints_for_implicit_object_creation = true,
                  csharp_enable_inlay_hints_for_implicit_variable_types = true,
              },
              ["csharp|code_lens"] = {
                  dotnet_enable_references_code_lens = true,
              },
              ["csharp|background_analysis"] = {
                dotnet_analyzer_diagnostics_scope = "openFiles",
                dotnet_compiler_diagnostics_scope = "openFiles",
              },
            },
            capabilities = {
              workspace = {
                didChangeWatchedFiles = {
                  dynamicRegistration = true,
                },
              },
            },
          })
        '';
      };
    };
  };
}
