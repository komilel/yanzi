{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./cfg/lsp/default.nix
    ./cfg/debugger/default.nix
    ./cfg/languages/default.nix
    ./cfg/autocmds.nix
    ./cfg/opts_and_keys.nix
    ./cfg/plugins/default.nix
    ./cfg/theme.nix
  ];

  programs.nvf = {
    enable = true;

    settings.vim = {
      additionalRuntimePaths = [
        ./cfgLua
      ];

      diagnostics.enable = true;
      diagnostics.config = {
        underline = true;
        virtual_text = {
          spacing = 2;
          prefix = "\●";
        };
        float = {border = "rounded";};
        update_in_insert = false;
        severity_sort = true;
        signs = {
          text = lib.generators.mkLuaInline ''
            {
             [vim.diagnostic.severity.ERROR] = " ",
             [vim.diagnostic.severity.WARN] = " ",
             [vim.diagnostic.severity.HINT] = " ",
             [vim.diagnostic.severity.INFO] = " ",
            }
          '';
        };
      };

      visuals = {
        nvim-web-devicons.enable = true;
        nvim-cursorline.enable = true;
        cinnamon-nvim.enable = true;
        fidget-nvim = {
          enable = true;
          setupOpts = {
            notification = {
              window = {
                normal_hl = "Comment";
                winblend = 0;
              };
            };
          };
        };
        highlight-undo.enable = true;
        indent-blankline.enable = true;

        # Fun
        # cellular-automaton.enable = false;
      };

      statusline = {
        lualine = {
          enable = true;
          theme = "catppuccin";

          activeSection.b = [
            ''{ "filetype", colored = true, icon_only = true, icon = { align = 'left' } } ''
            ''{ "filename", path = 4, symbols = {modified = ' ', readonly = ' '}, separator = {right = ''} } ''
            ''{ "", draw_empty = true, separator = { left = '', right = '' } } ''
          ];
        };
      };

      autopairs.nvim-autopairs.enable = true;

      autocomplete = {
        blink-cmp = {
          enable = true;

          setupOpts = {
            keymap = {
              preset = "enter";
            };
            cmdline = {
              enabled = true;
              keymap = {
                preset = "cmdline";
              };
              completion = {
                menu = {
                  auto_show = true;
                };
              };
            };
          };
        };
      };

      snippets.luasnip.enable = true;

      # tabline = {
      #   nvimBufferline.enable = true;
      # };

      treesitter = with pkgs.vimPlugins; {
        enable = true;

        # nvim-treesitter-context
        context = {
          enable = true;
          setupOpts = {
            max_lines = 4;
          };
        };

        highlight = {
          enable = true;
        };

        textobjects = {
          enable = true;
        };

        indent = {
          enable = true;
        };

        grammars = [nvim-treesitter.withAllGrammars];
      };

      binds = {
        whichKey.enable = true;
        cheatsheet.enable = true;
      };

      git = {
        enable = true;
        gitsigns.enable = true;
      };

      minimap = {
        minimap-vim.enable = false;
        # codewindow.enable = isMaximal; # lighter, faster, and uses lua for configuration
      };

      dashboard = {
        dashboard-nvim.enable = false;
      };

      notify = {
        nvim-notify.enable = true;
      };

      # projects = {
      #   project-nvim.enable = isMaximal;
      # };

      utility = {
        ccc.enable = false;

        vim-wakatime.enable = false;

        diffview-nvim.enable = true;

        yanky-nvim.enable = false;

        # icon-picker.enable = isMaximal;

        surround = {
          enable = true;
          setupOpts = {};
          useVendoredKeybindings = false;
        };

        leetcode-nvim.enable = false;

        multicursors.enable = false;

        smart-splits.enable = false;

        undotree.enable = true;

        oil-nvim = {
          enable = true;
          setupOpts = {
            default_file_explorer = true;
            view_options = {
              show_hidden = true;
            };
          };
        };

        # motion = {
        #   hop.enable = true;
        #   leap.enable = true;
        #   precognition.enable = isMaximal;
        # };

        images = {
          image-nvim.enable = false;
          img-clip.enable = false;
        };
      };

      notes = {
        # neorg.enable = false;
        # orgmode.enable = false;
        # mind-nvim.enable = isMaximal;
        todo-comments.enable = true;
      };

      # terminal = {
      #   toggleterm = {
      #     enable = true;
      #     lazygit.enable = true;
      #   };
      # };

      ui = {
        borders.enable = true;
        noice.enable = true;
        colorizer.enable = true;
        modes-nvim.enable = false; # the theme looks terrible with catppuccin
        illuminate.enable = true;
        breadcrumbs = {
          enable = false;
          navbuddy.enable = false;
        };
        smartcolumn = {
          enable = true;
          setupOpts.custom_colorcolumn = {
            # this is a freeform module, it's `buftype = int;` for configuring column position
            nix = "110";
            ruby = "120";
            java = "130";
            go = ["90" "130"];
          };
        };
        fastaction.enable = true;
      };

      comments = {
        comment-nvim.enable = true;
      };

      presence = {
        neocord.enable = true;
      };
    };
  };
}
