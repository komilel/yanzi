{
  lib,
  pkgs,
  ...
}: {
  programs.zed-editor = {
    enable = true;

    # Merge managed settings without replacing the existing editable config.
    mutableUserSettings = true;

    extraPackages = with pkgs; [
      nixd
      alejandra

      rust-analyzer
      rustfmt

      texlab
    ];

    extensions = [
      # General
      "catppuccin-blur"

      # Languages
      "nix"
      "lua"
      "csharp"
      "latex"

      # Snippets
      "python-snippets"
      "solid-typescript-snippets"
      "csharp-snippets"

      # SE
      "plantuml"
    ];

    userSettings = {
      # Zed only supports a global autosave delay, not a per-language one.
      autosave.after_delay.milliseconds = 1500;

      lsp.texlab = {
        # Use the Nix-managed server rather than downloading a foreign binary.
        binary.path = lib.getExe pkgs.texlab;

        settings.texlab = {
          # Keep the extension's latexmk defaults, including SyncTeX build flags.
          build = {
            onSave = true;
            forwardSearchAfter = true;
          };

          forwardSearch = {
            executable = lib.getExe pkgs.zathura;
            args = [
              "--synctex-forward"
              "%l:1:%f"
              "-x"
              # TexLab unescapes %% before Zathura expands its placeholders.
              ''zeditor --existing "%%{input}:%%{line}"''
              "%p"
            ];
          };
        };
      };
    };
  };

  programs.zathura = {
    enable = true;
    # Follow the source after builds without raising the existing PDF window.
    options.dbus-raise-window = false;
  };
}
