{ pkgs, ... }: {
  programs.vscode = {
    enable = true;

    profiles = {
      default = {
        extensions = with pkgs.vscode-extensions; [
          # General extensions
          catppuccin.catppuccin-vsc
          catppuccin.catppuccin-vsc-icons
          vscodevim.vim
          mkhl.direnv

          # Code completion
          supermaven.supermaven

          # == Languages ==
          # Python
          ms-python.debugpy
          ms-python.python
          ms-python.pylint
          ms-toolsai.jupyter
          ms-toolsai.jupyter-renderers
          ms-toolsai.vscode-jupyter-cell-tags
          ms-toolsai.jupyter-keymap

          # C/Cpp
          hars.cppsnippets
          ms-vscode.cpptools

          # Nix
          bbenoist.nix
          kamadorueda.alejandra

          # Flutter
          dart-code.dart-code
          dart-code.flutter
        ];
      };
    };
  };
}
