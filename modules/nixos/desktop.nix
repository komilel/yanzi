{
  pkgs,
  sddmTheme,
  ...
}: {
  fonts.packages = with pkgs; [
    nerd-fonts.droid-sans-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    corefonts
    vista-fonts
    font-awesome
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    comfortaa
    rubik
  ];

  qt = {
    enable = true;
    platformTheme = "kde";
    style = "adwaita-dark";
  };

  services = {
    displayManager.sddm = {
      package = pkgs.kdePackages.sddm;
      enable = true;
      wayland.enable = true;
      theme = sddmTheme.pname;
      extraPackages = sddmTheme.propagatedBuildInputs;
      settings.General = {
        GreeterEnvironment = "QML2_IMPORT_PATH=${sddmTheme}/share/sddm/themes/${sddmTheme.pname}/components/,QT_IM_MODULE=qtvirtualkeyboard";
        InputMethod = "qtvirtualkeyboard";
      };
    };

    gvfs.enable = true;
    libinput.enable = true;

    pipewire = {
      enable = true;
      pulse.enable = true;
    };

    printing = {
      enable = true;
      drivers = [pkgs.hplipWithPlugin];
    };

    system-config-printer.enable = true;
    tumbler.enable = true;
  };

  security.polkit.enable = true;

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          FastConnectable = true;
          Experimental = false;
        };
        Policy = {
          AutoEnable = true;
          ReconnectAttempts = 7;
          ReconnectIntervals = "1,2,4,8,16,32,64";
        };
      };
    };

    graphics = {
      enable = true;
      enable32Bit = true;
    };

    sane = {
      enable = true;
      extraBackends = [pkgs.hplipWithPlugin];
    };
  };

  programs = {
    firefox.enable = true;
    gamemode.enable = true;
    kdeconnect.enable = true;
    niri.enable = true;
    seahorse.enable = true;

    steam = {
      enable = true;
      gamescopeSession.enable = true;
      extraCompatPackages = [pkgs.proton-ge-bin];
    };

    thunar = {
      enable = true;
      plugins = with pkgs; [thunar-archive-plugin thunar-volman];
    };

    vscode.enable = true;

    weylus = {
      enable = true;
      users = ["root" "komi"];
      openFirewall = true;
    };

    dms-shell = {
      enable = true;
      systemd = {
        enable = true;
        restartIfChanged = true;
      };
      enableSystemMonitoring = true;
      enableVPN = true;
      enableDynamicTheming = true;
      enableAudioWavelength = true;
      enableCalendarEvents = false;
      enableClipboardPaste = true;
    };
  };
}
