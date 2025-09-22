{ config, pkgs, ... }: {
  programs.zsh = {
    enable = true;
    
    shellAliases =
      let
        flakeDir = "~/yanzi";
      in {
        rb = "sudo nixos-rebuild switch --flake ${flakeDir}";

        c = "clear";
        sn = "shutdown now";
        rbt = "reboot";
        lc = "lsd";
        llc = "lsd -l";
        lcc = "lsd -c";
      };

    enableCompletion = true;

    autosuggestion.enable = true;

    # setOptions = [
    #   "appendhistory"
    #   "sharehistory"
    #   "hist_ignore_space"
    #   "hist_ignore_all_dups"
    #   "hist_ignore_dups"
    #   "hist_find_no_dups"
    # ];

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

    history.size = 10000;
    history.path = "${config.xdg.dataHome}/zsh/history";
  };

  # Integrating fzf
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
