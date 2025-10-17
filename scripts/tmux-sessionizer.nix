{config, pkgs, ...}: 
let
  Home = "${config.users.users.komi.home}";
in pkgs.writeShellApplication {
  name = "tmux-sessionizer";

  runtimeInputs = with pkgs; [
    tmux
    fzf
    neovim
    busybox # For pgrep
  ];
  
  text = ''
    # Originally: tmux-sessionizer script made by Primeagen
    # Link: https://github.com/ThePrimeagen/.dotfiles/blob/master/bin/.local/scripts/tmux-sessionizer

    # Don't exit on error
    set +e

    # Launch nvim in current dir (alias)
    vim_cmd="v ."

    if [[ $# -eq 1 ]]; then
      selected=$1
    else
      selected=$(find ~/ ~/Documents ~/gits ~/wbdev ~/Documents/Uni ~/Projs -mindepth 1 -maxdepth 3 -type d | fzf)
    fi

    if [[ -z $selected ]]; then
      exit 0
    fi

    selected_name=$(basename "$selected" | tr . _)
    tmux_running=$(pgrep tmux)

    if [[ -z $tmux_running ]] || ! tmux has-session -t="$selected_name" 2>/dev/null; then
      tmux new-session -ds "$selected_name" -c "$selected" "$vim_cmd"
      tmux new-window -c "$selected"
      tmux select-window -t 1
    fi

    tmux attach -t "$selected_name"
  '';
}
