{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
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
  };
}
