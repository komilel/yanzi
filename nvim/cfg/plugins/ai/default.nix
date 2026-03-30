{
  pkgs,
  lib,
  ...
}: {
  programs.nvf.settings.vim = {
    extraPackages = with pkgs; [
      # For codecompanion (ai)
      codex-acp
      claude-code-acp
    ];

    startPlugins = with pkgs.vimPlugins; [
      # AI (CodeCompanion)
      codecompanion-history-nvim
      codecompanion-spinner-nvim
      codecompanion-lualine-nvim
    ];

    lazy.plugins = with pkgs.vimPlugins; {
      # Dep of codecompanion
      # Picker needed
      "snacks.nvim" = {
        enabled = true;
        package = snacks-nvim;
        setupModule = "snacks";
        setupOpts = {
          picker = {
            enabled = true;
          };
          input = {
            enabled = true;
          };
        };
      };

      # ========
      # == AI ==
      # ========
      "claudecode.nvim" = {
        enabled = true;
        package = claudecode-nvim;

        setupModule = "claudecode";
        setupOpts = {
          # Selection Tracking
          track_selection = true;
          visual_demotion_delay_ms = 50;

          # Terminal Configuration
          terminal = {
            split_side = "right"; # "left" or "right"
            split_width_percentage = 0.40;
            provider = "auto"; # "auto", "snacks", "native", "external", "none", or custom provider table
            auto_close = true;
          };

          # Diff Integration
          diff_opts = {
            layout = "vertical"; # "vertical" or "horizontal"
            open_in_new_tab = true;
            keep_terminal_focus = false; # If true, moves focus back to terminal after diff opens
            hide_terminal_in_new_tab = false;
            # on_new_file_reject = "keep_empty"; -- "keep_empty" or "close_window"

            # Legacy aliases (still supported):
            # vertical_split = true;
            # open_in_current_tab = true;
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
            key = "<leader>as";
            mode = "v";
            action = "<cmd>ClaudeCodeSend<CR>";
            desc = "AI: Send to claude";
          }
        ];
      };

      "codecompanion.nvim" = {
        enabled = true;
        package = codecompanion-nvim;

        setupModule = "codecompanion";
        setupOpts = {
          ignore_warnings = true;

          interactions = {
            chat = {
              adapter = "claude_code";
              model = "opus";

              keymaps = {
                paste_image = {
                  modes = {
                    n = "gp";
                  };
                  description = "Paste image from clipboard";
                  callback = lib.generators.mkLuaInline ''
                    function()
                      vim.cmd("PasteImage")
                    end
                  '';
                };
              };
            };
            cli = {
              agent = "claude_code";
              agents = {
                claude_code = {
                  cmd = "claude";
                  args = [];
                  description = "Claude Code CLI";
                };
                codex = {
                  cmd = "codex";
                  args = {};
                  description = "OpenAI Codex CLI";
                };
              };
            };
          };

          adapters = {
            acp = {
              claude_code = lib.generators.mkLuaInline ''                function ()
                              return require("codecompanion.adapters").extend("claude_code", {
                                commands = {
                                  default = {
                                    "claude-code-acp"
                                  },
                                },
                                env = {
                                  CLAUDE_CODE_OAUTH_TOKEN = require("komi.tokens").get_token("claude")
                                }
                              })
                            end'';
              codex = lib.generators.mkLuaInline ''                function()
                              return require("codecompanion.adapters").extend("codex", {
                                defaults = {
                                  auth_method = "chatgpt", -- "openai-api-key"|"codex-api-key"|"chatgpt"
                                },
                              })
                            end'';
            };

            http = {
              gemini = lib.generators.mkLuaInline ''
                function()
                  return require("codecompanion.adapters").extend("gemini", {
                    env = {
                      api_key = require("komi.tokens").get_token("gemini")
                    }
                  })
                end'';
            };
          };

          display = {
            chat = {
              icons = {
                chat_context = "";
              };

              opts = {
                completion_provider = "blink";
              };

              fold_context = true;
              auto_scroll = true;

              intro_message = "Something's cooking...";
              separator = "─"; # The separator between the different messages in the chat buffer
              show_context = true; # Show context (from editor context and slash commands) in the chat buffer?
              show_header_separator = false; # Show header separators in the chat buffer? Set this to false if you're using an external markdown formatting plugin
              show_settings = false; # Show LLM settings at the top of the chat buffer?
              show_token_count = true; # Show the token count for each response?
              show_tools_processing = true; # Show the loading message when tools are being executed?
              start_in_insert_mode = false; # Open the chat buffer in insert mode?
            };
          };

          extensions = {
            history = {
              enabled = true;
              opts = {
                picker = "telescope";
                picker_keymaps = {
                  rename = {
                    n = "r";
                    i = "<M-r>";
                  };
                  delete = {
                    n = "d";
                    i = "<M-d>";
                  };
                  duplicate = {
                    n = "<C-y>";
                    i = "<C-y>";
                  };
                };

                auto_generate_title = true;
                title_generation_opts = {
                  adapter = "gemini";
                  model = "gemini-2.5-flash";
                  refresh_every_n_prompts = 0;
                  max_refreshes = 3;
                };
              };
            };

            spinner = {
              enabled = true;
            };
          };
        };

        keys = [
          {
            key = "<leader>cc";
            mode = ["n" "v"];
            action = "<cmd>CodeCompanionChat Toggle<CR>";
            desc = "AI: Code companion chat";
          }

          # New codecompanion chat
          {
            key = "<leader>cn";
            mode = ["n"];
            action = "<cmd>CodeCompanionChat<CR>";
            desc = "AI: New code companion chat";
          }

          {
            key = "<leader>ca";
            mode = ["n" "v"];
            action = "<cmd>CodeCompanionActions<CR>";
            desc = "AI: Code companion actions";
          }

          # CodeCompanion CLI
          {
            key = "<leader>cd";
            mode = ["n" "v"];
            action = "<cmd>CodeCompanionCLI<CR>";
            desc = "AI: Code companion CLI";
          }

          {
            key = "<leader>cp";
            mode = ["n" "v"];
            action = "<cmd>CodeCompanionCLI Ask<CR>";
            desc = "AI: Code companion CLI with a prompt";
          }

          {
            key = "<leader>ce";
            mode = ["n" "v"];
            action = ''function() return require("codecompanion").cli("#{this}", { focus = false }) end'';
            desc = "AI: Add context to code companion CLI";
            lua = true;
          }
        ];
      };

      "img-clip.nvim" = {
        enabled = true;
        package = img-clip-nvim;
        cmd = ["PasteImage"];

        setupModule = "img-clip";
        setupOpts = {
          filetypes = {
            codecompanion = {
              prompt_for_file_name = false;
              template = "[Image]($FILE_PATH)";
              use_absolute_path = true;
              dir_path = "/tmp/codecompanion-images";
            };
          };
        };
      };
    };
  };
}
