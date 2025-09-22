{ config, ... }: {
  wayland.windowManager.hyprland.settings = {
    source = "${config.home.homeDirectory}/.cache/wallust/colors-hyprland.conf";

    "$Mod" = "SUPER";

    monitor = [
      "eDP-1, 2560x1600@120, 0x0, auto"
      ", preferred, auto, 1"
    ];

    exec-once = [
      "dunst"
      "waybar"
      "swww-daemon"
      "hypridle"
      "nm-applet"
      "hyprland-per-window-layout"

      "gnome-keyring-daemon --start --components=secrets"
      # "ssh-agent zsh"
    ];

    # Extra envs
    # "SDL_VIDEODRIVER,wayland"

    env = [
      "HYPRCURSOR_THEME,Bibata-Modern-Ice"
      "HYPRCURSOR_SIZE,24"
      "XCURSOR_THEME,Bibata-Modern-Ice"
      "XCURSOR_SIZE,24"
      "GDK_BACKEND,wayland,x11,*"
      "GDK_SCALE,2"
      "GDK_DISABLE,vulkan"
      "QT_QPA_PLATFORMTHEME,gtk3"
      # "QT_QPA_PLATFORM,xcb"
      "QT_AUTO_SCREEN_SCALE_FACTOR,1"
      "QT_STYLE_OVERRIDE,kvantum"
      "XDG_CURRENT_DESKTOP,Hyprland"
      "XDG_SESSION_TYPE,wayland"
      "XDG_SESSION_DESKTOP,Hyprland"
      "GTK_IM_MODULE,ibus"
      "QT_IM_MODULE,ibus"
      "QT_IM_MODULE,ibus"
      "XMODIFIERS,@im=ibus"
    ];

    general = {
      gaps_in = 3;
      gaps_out = 3;
      border_size = 2;
      "col.active_border" = "$color12 $color10";
      "col.inactive_border" = "rgb(272744)";
      layout = "master";
      resize_on_border = true;
    };

    gestures = {
      workspace_swipe = "on";
      workspace_swipe_cancel_ratio = 0.15;
      workspace_swipe_distance = 500;
      workspace_swipe_forever = true;
      workspace_swipe_use_r = true;
      workspace_swipe_create_new = true;
    };

    input = {
      kb_layout = "us,ru";
      kb_options = "grp:toggle";

      touchpad = {
        natural_scroll = "yes";
        scroll_factor = "0.3";
        disable_while_typing = "true";
      };
    };

    decoration = {
      rounding = 4;

      blur = {
        enabled = true;
        size = 5;
        passes = 3;
        vibrancy = "0.3";
        noise = "0.03";
        new_optimizations = true;
        ignore_opacity = true;
        xray = false;
      };

      # drop_shadow = false;
      # shadow_range = 6;
      # shadow_render_power = 3;
      # "col.shadow" = "rgba(000000c6)";
    };

    animations = {
      enabled = true;

      bezier = [
        "win, 0.2, 0.8, 0.2, 0.9"
        "winOut, 0.1, 0.9, 0.3, 0.9"
        "workspace, 0.0, 0.0, 0.3, 1.0"
        "linear, 0.0, 0.0, 1.0, 1.0"
      ];

      animation = [
        "windows, 1, 3, win, popin"
        "windowsIn, 1, 3, win, popin 60%"
        "windowsOut, 1, 3, winOut, popin 60%"
        "border, 1, 3, linear"
        "fade, 1, 7, default"
        "workspaces, 1, 2, workspace, slidefade"
        "specialWorkspace, 1, 2, workspace, slidevert"
      ];
    };

    dwindle = {
      pseudotile = true;
      preserve_split = true;
      smart_split = false;
    };

    group = {
      "col.border_active" = "$color5";
      "col.border_inactive" = "$color7";

      groupbar = {
        enabled = true;
        height = 2;
        render_titles = false;
        "col.active" = "$color5";
        "col.inactive" = "$color7";
      };
    };

    misc = {
      disable_hyprland_logo = true;
      force_default_wallpaper = 0;
    };

    xwayland = {
      force_zero_scaling = true;
    };

    # Smart gaps
    workspace = [
      "w[tv1], gapsout:0, gapsin:0"
      "f[1], gapsout:0, gapsin:0"
    ];

    windowrule = [
      "opacity 0.9, initialClass:code"

      "float, initialTitle:Open(.*) "
      "center, initialTitle:Open(.*)"
      "opacity 0.9, initialTitle:Open(.*)"
      "size <80% <80%, initialTitle:Open(.*)"

      "float, initialTitle:^(((.*)Export(.*))|((.*)Save(.*)))$"
      "opacity 0.9, initialTitle:^(((.*)Export(.*))|((.*)Save(.*)))$"
      "center, initialTitle:^(((.*)Export(.*))|((.*)Save(.*)))$"
      "size <80% <80%, initialTitle:^(((.*)Export(.*))|((.*)Save(.*)))$"

      "float, initialTitle:^.*File.*$"
      "opacity 0.9, initialTitle:^.*File.*$"
      "center, initialTitle:^.*File.*$"
      "size <80% <80%, initialTitle:^.*File.*$"

      "float, initialClass:hyprland-share-picker"
      "opacity 0.8, initialClass:hyprland-share-picker"
      "center, initialClass:hyprland-share-picker"
      "size 80% 80%, initialClass:hyprland-share-picker"

      "float, initialClass:qView"
      "center, initialClass:qView"
      "size 80% 80%, initialClass:qView"

      "size <30% <15%, initialClass:^(.*)(Thunar|thunar)(.*)$, title:.*Rename.*"
      "float, initialClass:^(.*)(Thunar|thunar)$"
      "opacity 0.8, initialClass:^(Thunar|thunar)$"
      "size 85% 85%, initialClass:^(.*)(Thunar|thunar)$"
      "center, initialClass:^(.*)(Thunar|thunar)$"

      "float, initialClass:(.*)(telegram)(.*)"
      "opacity 0.85, initialClass:(.*)(telegram)(.*)"
      "size 95% 90%, initialClass:(.*)(telegram)(.*)"
      "center, initialClass:(.*)(telegram)(.*)"
      "opacity 1, class:org.telegram.desktop, title:Media viewer"

      # "opacity 0.9, initialClass:(.*)(obsidian)(.*)"

      "float, initialClass:(.*)(qalculate-gtk)(.*)"
      "opacity 0.8, initialClass:(.*)(qalculate-gtk)(.*)"
      "center, initialClass:(.*)(qalculate-gtk)(.*)"
      "size 70% 70%, initialClass:(.*)(qalculate-gtk)(.*)"

      "float, initialClass:(.*)(qView)(.*)"
      "center, initialClass:(.*)(qView)(.*)"
      "size 80% 80%, initialClass:(.*)(qView)(.*)"

      "opacity 0.9, initialClass:(.*)(vesktop)(.*)"

      "opacity 0.9, initialTitle:^(.*)(Spotify)(.*)$"
      "workspace special:music, initialTitle:^(.*)(Spotify)(.*)$ "

      # "Smart" gaps
      "bordersize 0, floating:0, onworkspace:w[tv1]"
      "rounding 0, floating:0, onworkspace:w[tv1]"
      "bordersize 0, floating:0, onworkspace:f[1]"
      "rounding 0, floating:0, onworkspace:f[1]"
    ];

    bind = [
      "$Mod, C, killactive,"
      "$Mod ALT, M, exit,"
      "$Mod, V, togglefloating,"
      "$Mod ALT, L, exec, hyprlock"
      "$Mod SHIFT, A, exec, hyprpicker -a"

      "$Mod, P, pseudo,"
      "$Mod, J, togglesplit,"

      # App submap
      "$Mod, A, submap, apps"

      # Fullscreen
      "$Mod, F, fullscreen, 1"
      "$Mod ALT, F, fullscreen, 0"

      # Toggle opaque for active window
      "$Mod, O, exec, hyprctl setprop active opaque toggle"

      # Move focus between monitors
      "ALT, S, focusmonitor, +1"

      # Music special workspace
      "$Mod, S, togglespecialworkspace, music"
      "$Mod ALT, S, exec, spotify"

      # App keys
      "$Mod, Q, exec, kitty"
      "$Mod, E, exec, thunar"
      "$Mod, R, exec, rofi -show drun -config ~/.config/rofi/drun.rasi"

      # Wallpapers
      "$Mod, W, exec, wallpaper select"
      "$Mod ALT, W, exec, wallpaper random"

      # Move focus with mainMod + vim keys
      "$Mod, H, movefocus, l"
      "$Mod, L, movefocus, r"
      "$Mod, K, movefocus, u"
      "$Mod, J, movefocus, d"

      # Move window or group
      "ALT, H, movewindoworgroup, l"
      "ALT, J, movewindoworgroup, d"
      "ALT, K, movewindoworgroup, u"
      "ALT, L, movewindoworgroup, r"

      # Switch workspaces with mainMod + [0-9]
      "$Mod, 1, split:workspace, 1"
      "$Mod, 2, split:workspace, 2"
      "$Mod, 3, split:workspace, 3"
      "$Mod, 4, split:workspace, 4"
      "$Mod, 5, split:workspace, 5"
      "$Mod, 6, split:workspace, 6"
      "$Mod, 7, split:workspace, 7"
      "$Mod, 8, split:workspace, 8"
      "$Mod, 9, split:workspace, 9"
      "$Mod, 0, split:workspace, 10"

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      "$Mod SHIFT, 1, split:movetoworkspacesilent, 1"
      "$Mod SHIFT, 2, split:movetoworkspacesilent, 2"
      "$Mod SHIFT, 3, split:movetoworkspacesilent, 3"
      "$Mod SHIFT, 4, split:movetoworkspacesilent, 4"
      "$Mod SHIFT, 5, split:movetoworkspacesilent, 5"
      "$Mod SHIFT, 6, split:movetoworkspacesilent, 6"
      "$Mod SHIFT, 7, split:movetoworkspacesilent, 7"
      "$Mod SHIFT, 8, split:movetoworkspacesilent, 8"
      "$Mod SHIFT, 9, split:movetoworkspacesilent, 9"
      "$Mod SHIFT, 0, split:movetoworkspacesilent, 10"

      # Scroll through existing workspaces with mainMod + scroll
      "$Mod, mouse_down, workspace, e+1"
      "$Mod, mouse_up, workspace, e-1"

      # Apps keybindings
      "$Mod, T, exec, Telegram"
      "$Mod, B, exec, zen"

      # Screenshot
      "$Mod SHIFT, S, exec, hyprshot -m region --clipboard-only"
      "$Mod SHIFT, X, exec, hyprshot -m output --clipboard-only"
      "$Mod SHIFT, C, exec, hyprshot -m window --clipboard-only"
    ];

    binde = [
      ", XF86MonBrightnessDown, exec, brightnessctl -d amdgpu_bl1 set 10%-"
      "SUPER, XF86MonBrightnessDown, exec, brightnessctl -d amdgpu_bl1 set 5%-"
      ", XF86MonBrightnessUp, exec, brightnessctl -d amdgpu_bl1 set +10%"
      "SUPER, XF86MonBrightnessUp, exec, brightnessctl -d amdgpu_bl1 set +5%"

      "SUPER, F5, exec, brightnessctl -d amdgpu_bl1 set 10%-"
      "SUPER SHIFT, F5, exec, brightnessctl -d amdgpu_bl1 set 5%-"
      "SUPER, F6, exec, brightnessctl -d amdgpu_bl1 set +10%"
      "SUPER SHIFT, F6, exec, brightnessctl -d amdgpu_bl1 set +5%"

      ", XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle"
      ", XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +10%"
      ", XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -10%"
      "SUPER, XF86AudioMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle"
    ];

    # Move/resize windows with mainMod + LMB/RMB and dragging
    bindm = [
      "$Mod, mouse:272, movewindow"
      "$Mod, mouse:273, resizewindow"
    ];

    plugin = {
      hyprsplit = {
        num_workspaces = 5;
      };
    };
  };
}
