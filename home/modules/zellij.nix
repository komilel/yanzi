{...}: {
  programs.zellij = {
    enable = true;
    # Keep launch/attachment manual while trying Zellij alongside tmux.
    enableZshIntegration = false;

    # Keep the complete KDL together so it can also be tried without activation.
    extraConfig = ''
      default_mode "locked"
      scrollback_editor "nvim"
      // Mouse scrolling must not implicitly enable keyboard management bindings.
      scroll_mode_sync false

      // No global Ctrl/Alt shortcuts: applications only lose the Ctrl-a prefix.
      keybinds clear-defaults=true {
          locked {
              bind "Ctrl a" { SwitchToMode "normal"; }
          }
          normal {
              // Double the prefix to send Ctrl-a (shell beginning-of-line).
              bind "Ctrl a" { Write 1; SwitchToMode "locked"; }
              bind "p" { SwitchToMode "pane"; }
              bind "r" { SwitchToMode "resize"; }
              bind "m" { SwitchToMode "move"; }
              bind "t" { SwitchToMode "tab"; }
              bind "s" { SwitchToMode "scroll"; }
              bind "o" { SwitchToMode "session"; }
          }
          pane {
              bind "p" { SwitchToMode "normal"; }
              bind "h" "Left" { MoveFocus "Left"; }
              bind "j" "Down" { MoveFocus "Down"; }
              bind "k" "Up" { MoveFocus "Up"; }
              bind "l" "Right" { MoveFocus "Right"; }
              bind "Tab" { SwitchFocus; }
              bind ";" { FocusLastPane; }
              bind "n" { NewPane; SwitchToMode "locked"; }
              bind "r" { NewPane "Right"; SwitchToMode "locked"; }
              bind "d" { NewPane "Down"; SwitchToMode "locked"; }
              bind "s" { NewPane "stacked"; SwitchToMode "locked"; }
              bind "x" { CloseFocus; SwitchToMode "locked"; }
              bind "f" { ToggleFocusFullscreen; SwitchToMode "locked"; }
              bind "Shift f" { ToggleFocusNoUiFullscreen; SwitchToMode "locked"; }
              bind "w" { ToggleFloatingPanes; SwitchToMode "locked"; }
              bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "locked"; }
              bind "i" { TogglePanePinned; SwitchToMode "locked"; }
              bind "z" { TogglePaneFrames; SwitchToMode "locked"; }
              bind "c" { SwitchToMode "renamepane"; PaneNameInput 0; }
              bind "[" { PreviousSwapLayout; }
              bind "]" { NextSwapLayout; }
              bind "g" { TogglePaneInGroup; }
              bind "G" { ToggleGroupMarking; }
          }
          resize {
              bind "r" { SwitchToMode "normal"; }
              bind "h" "Left" { Resize "Increase Left"; }
              bind "j" "Down" { Resize "Increase Down"; }
              bind "k" "Up" { Resize "Increase Up"; }
              bind "l" "Right" { Resize "Increase Right"; }
              bind "H" { Resize "Decrease Left"; }
              bind "J" { Resize "Decrease Down"; }
              bind "K" { Resize "Decrease Up"; }
              bind "L" { Resize "Decrease Right"; }
              bind "=" "+" { Resize "Increase"; }
              bind "-" { Resize "Decrease"; }
          }
          move {
              bind "m" { SwitchToMode "normal"; }
              bind "h" "Left" { MovePane "Left"; }
              bind "j" "Down" { MovePane "Down"; }
              bind "k" "Up" { MovePane "Up"; }
              bind "l" "Right" { MovePane "Right"; }
              bind "n" "Tab" { MovePane; }
              bind "p" { MovePaneBackwards; }
          }
          tab {
              bind "t" { SwitchToMode "normal"; }
              bind "h" "k" "Left" "Up" { GoToPreviousTab; }
              bind "l" "j" "Right" "Down" { GoToNextTab; }
              bind "n" { NewTab; SwitchToMode "locked"; }
              bind "x" { CloseTab; SwitchToMode "locked"; }
              bind "r" { SwitchToMode "renametab"; TabNameInput 0; }
              bind "Tab" { ToggleTab; }
              bind "i" { MoveTab "Left"; }
              bind "o" { MoveTab "Right"; }
              bind "b" { BreakPane; SwitchToMode "locked"; }
              bind "[" { BreakPaneLeft; SwitchToMode "locked"; }
              bind "]" { BreakPaneRight; SwitchToMode "locked"; }
              bind "s" { ToggleActiveSyncTab; SwitchToMode "locked"; }
              bind "1" { GoToTab 1; SwitchToMode "locked"; }
              bind "2" { GoToTab 2; SwitchToMode "locked"; }
              bind "3" { GoToTab 3; SwitchToMode "locked"; }
              bind "4" { GoToTab 4; SwitchToMode "locked"; }
              bind "5" { GoToTab 5; SwitchToMode "locked"; }
              bind "6" { GoToTab 6; SwitchToMode "locked"; }
              bind "7" { GoToTab 7; SwitchToMode "locked"; }
              bind "8" { GoToTab 8; SwitchToMode "locked"; }
              bind "9" { GoToTab 9; SwitchToMode "locked"; }
          }
          scroll {
              bind "s" { SwitchToMode "normal"; }
              bind "f" { SwitchToMode "entersearch"; SearchInput 0; }
              bind "e" { EditScrollback; SwitchToMode "locked"; }
              bind "c" { CopyLastCommandOutput; SwitchToMode "locked"; }
          }
          search {
              bind "n" { Search "down"; }
              bind "p" { Search "up"; }
              bind "c" { SearchToggleOption "CaseSensitivity"; }
              bind "w" { SearchToggleOption "Wrap"; }
              bind "o" { SearchToggleOption "WholeWord"; }
          }
          shared_among "scroll" "search" {
              bind "j" "Down" { ScrollDown; }
              bind "k" "Up" { ScrollUp; }
              bind "h" "Left" "PageUp" "Ctrl b" { PageScrollUp; }
              bind "l" "Right" "PageDown" "Ctrl f" { PageScrollDown; }
              bind "u" { HalfPageScrollUp; }
              bind "d" { HalfPageScrollDown; }
              bind "[" { ScrollToPreviousPrompt; }
              bind "]" { ScrollToNextPrompt; }
              bind "m" { SelectCommandAtScrollPosition; }
              bind "Ctrl c" { ScrollToBottom; SwitchToMode "locked"; }
          }
          entersearch {
              bind "Esc" "Ctrl c" { SwitchToMode "scroll"; }
              bind "Enter" { SwitchToMode "search"; }
          }
          renametab {
              bind "Esc" { UndoRenameTab; SwitchToMode "tab"; }
          }
          renamepane {
              bind "Esc" { UndoRenamePane; SwitchToMode "pane"; }
          }
          shared_among "renametab" "renamepane" {
              bind "Enter" "Ctrl c" { SwitchToMode "locked"; }
          }
          session {
              bind "o" { SwitchToMode "normal"; }
              bind "d" { Detach; }
              bind "q" { Quit; }
              bind "w" {
                  LaunchOrFocusPlugin "session-manager" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "locked"
              }
              bind "c" {
                  LaunchOrFocusPlugin "configuration" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "locked"
              }
              bind "l" {
                  LaunchOrFocusPlugin "zellij:layout-manager" {
                      floating true
                      move_to_focused_tab true
                  }
                  SwitchToMode "locked"
              }
          }
          shared_except "locked" "normal" {
              bind "Ctrl a" { SwitchToMode "locked"; }
          }
          shared_except "locked" "entersearch" "renametab" "renamepane" {
              bind "Esc" "Enter" { SwitchToMode "locked"; }
          }
      }
    '';
  };
}
