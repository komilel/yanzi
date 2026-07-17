{pkgs, ...}: {
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
      set -g extended-keys
      set -g extended-keys-format csi-u
      set -s escape-time 0

      # Vim-like pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Vim-like splits
      bind v split-window -h -c "#{pane_current_path}"
      bind s split-window -v -c "#{pane_current_path}"

      # Vim-like window navigation
      bind -r C-h previous-window
      bind -r C-l next-window

      # Vim-like pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5
    '';
  };
}
