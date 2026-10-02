{pkgs, ...}: let
  projectLayout = pkgs.writeText "zs-project.kdl" ''
    layout {
        // Match manual sessions: native aliases and one-row bars. Giving the
        // status bar two rows selects Zellij's classic two-line UI.
        default_tab_template {
            pane size=1 borderless=true {
                plugin location="tab-bar"
            }
            children
            pane size=1 borderless=true {
                plugin location="status-bar"
            }
        }
        tab name="Main" focus=true { pane; }
        tab name="Shell" { pane; }
    }
  '';
in
  pkgs.writeShellApplication {
    name = "zs";

    runtimeInputs = with pkgs; [zellij fzf findutils coreutils];

    text = ''
      usage() {
        printf '%s\n' \
          'Usage: zs [directory]' \
          'Pick a project with fzf, or supply its directory.' \
          'Create/resume its Zellij session, or switch to it from inside Zellij.'
      }

      if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
        usage
        exit 0
      fi
      if [[ "''${1:-}" == "--" ]]; then
        shift
      fi
      if (( $# > 1 )); then
        usage >&2
        exit 2
      fi

      # Both multiplexers use Ctrl-a; avoid accidentally nesting them.
      if [[ -n "''${TMUX:-}" && -z "''${ZELLIJ:-}" ]]; then
        printf '%s\n' 'zs: launch from outside tmux to avoid nested multiplexers.' >&2
        exit 1
      fi

      if (( $# == 1 )); then
        selected=$1
      else
        search_roots=("$HOME")
        for root in "$HOME/Documents" "$HOME/gits" "$HOME/wbdev" \
                    "$HOME/Documents/Uni" "$HOME/Projs"; do
          if [[ -d "$root" ]]; then
            search_roots+=("$root")
          fi
        done

        # Null-delimited paths preserve spaces/newlines; overlapping roots are
        # deduplicated, and absent/unreadable directories don't break selection.
        if ! IFS= read -r -d "" selected < <(
          (
            find -H "''${search_roots[@]}" -mindepth 1 -maxdepth 3 \
              -type d \( -name .git -o -name .cache -o -name node_modules \) -prune \
              -o -type d -print0 2>/dev/null || true
          ) | sort -zu | fzf --read0 --print0 --no-multi --prompt='Project > '
        ); then
          exit 0
        fi
      fi

      if [[ ! -d "$selected" ]]; then
        printf 'zs: not a directory: %s\n' "$selected" >&2
        exit 1
      fi
      IFS= read -r -d "" selected < <(realpath -ez -- "$selected")

      # Canonical paths make relative/symlink aliases share a session. A short
      # path hash keeps identically named projects distinct and names bounded.
      project_name="''${selected##*/}"
      project_name="''${project_name//[^a-zA-Z0-9_-]/_}"
      project_name="''${project_name:-project}"
      if [[ "$project_name" == -* ]]; then
        project_name="project$project_name"
      fi
      path_hash=$(printf '%s' "$selected" | sha256sum)
      session_name="''${project_name:0:32}-''${path_hash:0:12}"

      if [[ -n "''${ZELLIJ:-}" ]]; then
        # Reattaching to the current session is unsupported by Zellij.
        if [[ "''${ZELLIJ_SESSION_NAME:-}" == "$session_name" ]]; then
          exit 0
        fi
        exec zellij action switch-session "$session_name" \
          --cwd "$selected" --layout "${projectLayout}"
      fi

      # Start in the project without pinning future panes to a default_cwd;
      # splits should still inherit the focused pane's current directory.
      cd -- "$selected"
      exec zellij attach --create "$session_name" \
        options --default-layout "${projectLayout}"
    '';
  }
