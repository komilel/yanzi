{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.zsh = {
    enable = true;

    shellAliases = let
      flakeDir = "~/yanzi";
    in {
      rbd = "sudo nixos-rebuild switch --flake ${flakeDir}";
      rbdt = "sudo nixos-rebuild test --flake ${flakeDir}";
      rbdb = "sudo nixos-rebuild boot --flake ${flakeDir}";

      c = "clear";
      sn = "shutdown now";
      rb = "reboot";
      lc = "lsd";
      llc = "lsd -l";
      lcc = "lsd -la";

      # Git
      lzg = "lazygit";

      v = "vim";

      ts = "tmux-sessionizer";
    };

    enableCompletion = true;

    defaultKeymap = "emacs";

    autosuggestion.enable = true;

    initContent = ''
      # Load wallust theme to new terminal instances
      cat ~/.cache/wallust/sequences
    '';

    syntaxHighlighting = {
      enable = true;
    };

    plugins = [
      {
        name = "fzf-tab";
        file = "fzf-tab.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "Aloxaf";
          repo = "fzf-tab";
          rev = "fc6f0dcb2d5e41a4a685bfe9af2f2393dc39f689";
          sha256 = "1g3kToboNGXNJTd+LEIB/j76VgPdYqG2PNs3u6Zke9s=";
        };
      }
    ];

    history = {
      size = 15000;
      findNoDups = true;
      ignoreAllDups = true;
      path = "${config.xdg.dataHome}/zsh/history";
    };
  };

  # Integrating fzf
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
}
