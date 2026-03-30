{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./ai/default.nix
  ];

  programs.nvf.settings.vim = {
    extraPackages = with pkgs; [
      fd # For telescope
    ];

    lazy.plugins = with pkgs.vimPlugins; {
      # TODO: Replace with vim.telescope?
      telescope = {
        enabled = true;
        package = "telescope";

        setupModule = "telescope";
        setupOpts = {
          pickers = {
            find_files = {
              hidden = true;
            };
          };
        };

        keys = [
          {
            key = "<leader>sf";
            mode = "n";
            action = "function() return require('telescope.builtin').find_files({ hidden = true }) end";
            desc = "Telescope: [S]earch [F]iles";
            lua = true;
          }

          {
            key = "<leader>sg";
            mode = "n";
            action = "function() return require('telescope.builtin').live_grep() end";
            desc = "Telescope: [S]earch by [G]rep";
            lua = true;
          }

          {
            key = "<leader>sk";
            mode = "n";
            action = "function() return require('telescope.builtin').keymaps() end";
            desc = "Telescope: [S]earch [K]eymaps";
            lua = true;
          }

          # {
          #   key = "<leader>/";
          #   mode = "n";
          #   action = ''
          #     require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
          #       winblend = 10,
          #       previewer = false,
          #     })
          #   '';
          #   desc = "Telescope: Fuzzy search current buffer";
          #   lua = true;
          # }

          {
            key = "<leader><leader>s";
            mode = "n";
            action = "function() return require('telescope.builtin').buffers() end";
            desc = "Telescope: Search buffers";
            lua = true;
          }

          {
            key = "<leader>sw";
            mode = "n";
            action = "function() return require('telescope.builtin').grep_string() end";
            desc = "Telescope: Search current word (under cursor)";
            lua = true;
          }

          {
            key = "<leader>ws";
            mode = "n";
            action = "function() return require('telescope.builtin').lsp_dynamic_workspace_symbols() end";
            desc = "Telescope: Workspace symbols";
            lua = true;
          }

          {
            key = "<leader>sr";
            mode = "n";
            action = "function() return require('telescope.builtin').lsp_references() end";
            desc = "Telescope: LSP references";
            lua = true;
          }

          {
            key = "<leader>si";
            mode = "n";
            action = "function() return require('telescope.builtin').lsp_implementations() end";
            desc = "Telescope: LSP implementations";
            lua = true;
          }
        ];
      };

      "harpoon2" = {
        enabled = true;
        package = harpoon2;
        setupModule = "harpoon";
        setupOpts = {};
        keys = [
          {
            key = "<leader>ha";
            mode = "n";
          }
          {
            key = "<leader>hl";
            mode = "n";
          }
          {
            key = "<leader>hp";
            mode = "n";
          }
          {
            key = "<leader>hn";
            mode = "n";
          }
          {
            key = "<M-C-H>";
            mode = "n";
          }
          {
            key = "<M-C-J>";
            mode = "n";
          }
          {
            key = "<M-C-K>";
            mode = "n";
          }
          {
            key = "<M-C-L>";
            mode = "n";
          }
          {
            key = "<M-C-Y>";
            mode = "n";
          }
          {
            key = "<M-C-U>";
            mode = "n";
          }
          {
            key = "<M-C-I>";
            mode = "n";
          }
          {
            key = "<M-C-O>";
            mode = "n";
          }
        ];
        after = ''
          local harpoon = require("harpoon")
          vim.keymap.set("n", "<leader>ha", function() harpoon:list():add() end, { desc = "Harpoon: add file" })
          vim.keymap.set("n", "<leader>hl", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon: list" })
          vim.keymap.set("n", "<leader>hp", function() harpoon:list():prev() end, { desc = "Harpoon: prev" })
          vim.keymap.set("n", "<leader>hn", function() harpoon:list():next() end, { desc = "Harpoon: next" })

          vim.keymap.set("n", "<M-C-H>", function() harpoon:list():select(1) end, { desc = "Harpoon: select 1" })
          vim.keymap.set("n", "<M-C-J>", function() harpoon:list():select(2) end, { desc = "Harpoon: select 2" })
          vim.keymap.set("n", "<M-C-K>", function() harpoon:list():select(3) end, { desc = "Harpoon: select 3" })
          vim.keymap.set("n", "<M-C-L>", function() harpoon:list():select(4) end, { desc = "Harpoon: select 4" })
          vim.keymap.set("n", "<M-C-Y>", function() harpoon:list():select(5) end, { desc = "Harpoon: select 5" })
          vim.keymap.set("n", "<M-C-U>", function() harpoon:list():select(6) end, { desc = "Harpoon: select 6" })
          vim.keymap.set("n", "<M-C-I>", function() harpoon:list():select(7) end, { desc = "Harpoon: select 7" })
          vim.keymap.set("n", "<M-C-O>", function() harpoon:list():select(8) end, { desc = "Harpoon: select 8" })
        '';
      };
    };
  };
}
