{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./cfg/lsp/default.nix
    ./cfg/debugger/default.nix
    ./cfg/languages/default.nix
  ];

  programs.nvf = {
    enable = true;

    settings.vim = {
      viAlias = true;
      vimAlias = true;
      debugMode = {
        enable = false;
        level = 16;
        logFile = "/tmp/nvim.log";
      };

      searchCase = "ignore";

      options = {
        autoindent = true;
        tabstop = 2;
        shiftwidth = 2;
        softtabstop = 2;

        hlsearch = true;
        inccommand = "split";
        scrolloff = 10;

        mouse = "a";
        undofile = true;

        signcolumn = "yes";
        swapfile = false;

        guicursor = "n-v-i-c:block-Cursor";
        cursorline = true;

        termguicolors = true;
      };

      globals = {
        mapleader = " ";
        maplocalleader = ",";
      };

      keymaps = [
        {
          key = "<C-d>";
          mode = "n";
          action = "<C-d>zz";
          desc = "Centered scroll down";
        }

        {
          key = "<C-u>";
          mode = "n";
          action = "<C-u>zz";
          desc = "Centered scroll up";
        }

        {
          key = "n";
          mode = "n";
          action = "nzzzv";
        }

        {
          key = "N";
          mode = "n";
          action = "Nzzzv";
        }

        {
          key = "j";
          mode = "n";
          action = "v:count == 0 ? 'gj' : 'j'";
          silent = true;
          expr = true;
        }

        {
          key = "k";
          mode = "n";
          action = "v:count == 0 ? 'gk' : 'k'";
          silent = true;
          expr = true;
        }

        {
          key = "<Tab>";
          mode = "n";
          action = "<C-6>";
          desc = "Cycle to previous buffer and back";
        }

        {
          key = "<leader>ch";
          mode = "n";
          action = "<cmd>nohlsearch<CR>";
          desc = "Clear search highlighting";
        }

        {
          key = "<leader>dv";
          mode = "n";
          action = ''
            function()
              local new_config = not vim.diagnostic.config().virtual_text
              vim.diagnostic.config({ virtual_text = new_config })
            end
          '';
          desc = "[D]iagnostic [V]irtual Text Toggle";
          lua = true;
        }

        {
          key = "<leader>y";
          mode = ["n" "x" "v"];
          action = "\"+y";
          desc = "Yank to system clipboard";
          noremap = true;
          silent = true;
        }

        {
          key = "<leader>Y";
          mode = ["n" "x" "v"];
          action = "\"+yy";
          desc = "Yank line to system clipboard";
          noremap = true;
          silent = true;
        }

        {
          key = "-";
          mode = "n";
          action = "<cmd>Oil<CR>";
          desc = "Oil file explorer";
        }

        {
          key = "]d";
          mode = "n";
          action = "vim.diagnostic.goto_next";
          desc = "Go to next diagnostic message";
          lua = true;
        }

        {
          key = "[d";
          mode = "n";
          action = "vim.diagnostic.goto_prev";
          desc = "Go to previous diagnostic message";
          lua = true;
        }

        {
          key = "<leader>e";
          mode = "n";
          action = "vim.diagnostic.open_float";
          desc = "Open floating diagnostic message";
          lua = true;
        }
      ];

      diagnostics.config = {
        underline = true;
        virtual_text = {
          enable = true;
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

      optPlugins = with pkgs.vimPlugins; [
        # AI
        claudecode-nvim
        "snacks-nvim"
      ];

      lazy.plugins = with pkgs.vimPlugins; {
        telescope = {
          enabled = true;
          package = "telescope";
          keys = [
            {
              key = "<leader>sf";
              mode = "n";
              action = "function() return require('telescope.builtin').find_files() end";
              desc = "[S]earch [F]iles";
              lua = true;
            }

            {
              key = "<leader>sg";
              mode = "n";
              action = "function() return require('telescope.builtin').live_grep() end";
              desc = "[S]earch by [G]rep";
              lua = true;
            }

            {
              key = "<leader>sk";
              mode = "n";
              action = "function() return require('telescope.builtin').keymaps() end";
              desc = "[S]earch [K]eymaps";
              lua = true;
            }
          ];
        };

        # AI
        "claudecode.nvim" = {
          enabled = true;
          package = claudecode-nvim;

          setupModule = "claudecode";
          setupOpts = {
            terminal = {
              snacks_win_opts = {
                position = "float";
                width = 0.9;
                height = 0.9;
                border = "rounded";
                backdrop = 80;
              };
            };
          };

          keys = [
            {
              key = "<leader>ac";
              mode = "n";
              action = "<cmd>ClaudeCode<CR>";
              desc = "AI: Toggle claude";
            }

            {
              key = "<leader>af";
              mode = "n";
              action = "<cmd>ClaudeCodeFocus<CR>";
              desc = "AI: Focus claude";
            }

            {
              key = "<leader>am";
              mode = "n";
              action = "<cmd>ClaudeCodeSelectModel<CR>";
              desc = "AI: Select claude model";
            }

            {
              key = "<leader>as";
              mode = "v";
              action = "<cmd>ClaudeCodeSend<CR>";
              desc = "AI: Send to claude";
            }

            {
              key = "<leader>aa";
              mode = "v";
              action = "<cmd>ClaudeCodeDiffAccept<CR>";
              desc = "AI: Accept diff";
            }

            {
              key = "<leader>ad";
              mode = "v";
              action = "<cmd>ClaudeCodeDiffDeny<CR>";
              desc = "AI: Deny diff";
            }
          ];
        };

        snacks-nvim = {
          enabled = true;
          package = "snacks-nvim";

          setupModule = "snacks";
          setupOpts = {terminal = {enabled = true;};};
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
              window.winblend = 10;
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

      theme = {
        enable = true;
        name = "catppuccin";
        style = "mocha";
        transparent = true;
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

        grammars = [nvim-treesitter.withAllGrammars];
      };

      binds = {
        whichKey.enable = true;
        cheatsheet.enable = true;
      };

      telescope.enable = true;

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
        surround.enable = true;
        leetcode-nvim.enable = false;
        multicursors.enable = false;
        smart-splits.enable = true;
        undotree.enable = true;

        oil-nvim = {
          enable = true;
          setupOpts = {
            default_file_explorer = true;
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

      assistant = {
        codecompanion-nvim.enable = true;
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
