let
  binds = [
    ", A, exec, obsidian"
    ", C, exec, code"
    ", D, exec, vesktop"
    ", S, exec, steam"
    ", W, exec, libreoffice --writer"
  ];

  getUpToSecondComma = s:
    let
      m = builtins.match "^([^,]*,[^,]*,)" s;
    in
      if m == null then s else builtins.elem m 0;

  commonPart = " submap, reset";
in {
  wayland.windowManager.hyprland.submaps = {
    apps = {
      settings = {
        bind = binds ++
          builtins.map (x: getUpToSecondComma x + commonPart) binds ++
          [
            ", escape, submap, reset"
          ];
      };
    };
  };
}
