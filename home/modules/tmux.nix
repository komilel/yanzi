{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    disableConfirmationPrompt = true;
    keyMode = "vi";
    mouse = true;
    prefix = "C-a";

    extraConfig = ''
      set-option -g status-position top
      set -g allow-passthrough on
      set -s escape-time 0
    '';
  };
}
