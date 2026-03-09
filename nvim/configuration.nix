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
  ];

  programs.nvf = {
    enable = true;

    settings.vim = {
      additionalRuntimePaths = [
        ./cfgLua
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

      extraPackages = with pkgs; [
        # For codecompanion (ai)
        codex-acp
        claude-code-acp
      ];

      optPlugins = with pkgs.vimPlugins; [
        # AI
        claudecode-nvim
        "snacks-nvim"
        "codecompanion-nvim"
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

        # Code companion?
        codecompanion-nvim = {
          enabled = true;
          package = "codecompanion-nvim";

          setupModule = "codecompanion";
          setupOpts = {
            ignore_warnings = true;
            interactions = {
              chat = {
                adapter = "codex";
              };
            };
            adapters = {
              acp = {
                claude_code = lib.generators.mkLuaInline ''                  function ()
                                return require("codecompanion.adapters").extend("claude_code", {
                                  env = {
                                    CLAUDE_CODE_OAUTH_TOKEN = require("komi.tokens").get_token("claude")
                                  }
                                })
                              end'';
                codex = lib.mkLuaInline ''                  function()
                                return require("codecompanion.adapters").extend("codex", {
                                  defaults = {
                                    auth_method = "chatgpt", -- "openai-api-key"|"codex-api-key"|"chatgpt"
                                  },
                                })
                              end'';
              };
            };
          };

          # keys = {};
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

      theme = {
        enable = true;
        name = "catppuccin";
        style = "macchiato";
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

        indent = {
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
