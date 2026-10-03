{
  pkgs,
  lib,
  ...
}: let
  debugPython = pkgs.python3.withPackages (ps: [ps.debugpy]);
in {
  programs.nvf.settings.vim = {
    extraPackages = with pkgs; [nodejs procps];

    # Let dap-go own Delve's server lifecycle and Go/test configurations.
    languages.go.dap.enable = true;

    debugger.nvim-dap = {
      enable = true;
      ui = {
        enable = true;
        autoStart = true;
      };
      presets = {
        debugpy.enable = true;
        codelldb.enable = true;
      };
      adapters = {
        coreclr = {
          type = "executable";
          command = lib.getExe pkgs.netcoredbg;
          args = ["--interpreter=vscode"];
        };
        "pwa-node" = {
          type = "server";
          host = "127.0.0.1";
          port = "\${port}";
          executable = {
            command = lib.getExe pkgs.vscode-js-debug;
            args = ["\${port}" "127.0.0.1"];
          };
        };
      };
      sources.komi-dap = ''
        require("komi.dap").setup({
          python = "${lib.getExe debugPython}",
        })
      '';
    };

    # Delve builds in the adapter's cwd, not the launch configuration's cwd.
    # Apply this after dap-go installs its adapter so projects work outside :pwd.
    pluginRC.komi-dap-go = {
      after = ["nvim-dap-go" "komi-dap"];
      before = [];
      data = ''
        require("komi.dap").setup_go()
      '';
    };

    keymaps = [
      {
        key = "<leader>dB";
        mode = "n";
        action = ''
          function()
            vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
              if condition and condition ~= "" then
                require("dap").set_breakpoint(condition)
              end
            end)
          end
        '';
        lua = true;
        desc = "DAP: conditional breakpoint";
      }
      {
        key = "<leader>dl";
        mode = "n";
        action = ''
          function()
            vim.ui.input({ prompt = "Log point message: " }, function(message)
              if message and message ~= "" then
                require("dap").set_breakpoint(nil, nil, message)
              end
            end)
          end
        '';
        lua = true;
        desc = "DAP: log point";
      }
      {
        key = "<leader>dt";
        mode = "n";
        action = ''
          function()
            if vim.bo.filetype == "go" then
              require("dap-go").debug_test()
            else
              vim.notify("Debug nearest test is currently configured for Go only", vim.log.levels.INFO)
            end
          end
        '';
        lua = true;
        desc = "DAP: debug nearest Go test";
      }
    ];
  };
}
