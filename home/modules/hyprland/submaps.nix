let
  # Add here any keymaps to apps submap
  binds = [
    ", A, exec, obsidian"
    ", C, exec, code"
    ", D, exec, vesktop"
    ", S, exec, steam"
    ", W, exec, libreoffice --writer"
  ];

  # A lambda to get a keymap itself
  # E.g 'A' from exec obsidian
  # Then it composes 'Submap reset on A'
  getUpToSecondComma = s:
    let
      m = builtins.match "^([^,]*,[^,]*,).*$" s;
    in
      if m == null then s else builtins.elemAt m 0;

  # To call submap reset on all keymaps
  commonPart = " submap, reset";
in {
  wayland.windowManager.hyprland.submaps = {
    apps = {
      settings = {
        bind = binds ++
          (builtins.map (x: getUpToSecondComma x + commonPart) binds) ++
          [
            ", escape, submap, reset"
          ];
      };
    };
  };
}
