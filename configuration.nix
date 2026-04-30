{
  self,
  config,
  inputs,
  pkgs,
  lib,
  system,
  ...
}: let
  sddm-theme = inputs.silentSDDM.packages.${system}.default.override {
    theme = "rei";
  };
in {
  imports = [
    ./hardware-configuration.nix
    ./nvim/configuration.nix
    ./virt.nix

    ./modules/cproxy
    ./modules/urix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    supportedFilesystems = ["ntfs"];
    kernel.sysctl."fs.inotify.max_user_watches" = 1048576;
  };

  networking.hostName = "Niko";

  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Yekaterinburg";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

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

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = with pkgs; [hplipWithPlugin];
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  services.system-config-printer.enable = true;

  # Enable sound.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Mount, trash, and other functionalities
  services.gvfs.enable = true;

  services.samba.enable = true;

  # Thumbnail support for images
  services.tumbler.enable = true;

  services.displayManager.sddm = {
    package = pkgs.kdePackages.sddm;
    enable = true;
    wayland.enable = true;
    theme = sddm-theme.pname;
    extraPackages = sddm-theme.propagatedBuildInputs;
    settings = {
      # required for styling the virtual keyboard
      General = {
        GreeterEnvironment = "QML2_IMPORT_PATH=${sddm-theme}/share/sddm/themes/${sddm-theme.pname}/components/,QT_IM_MODULE=qtvirtualkeyboard";
        InputMethod = "qtvirtualkeyboard";
      };
    };
  };

  security.polkit = {
    enable = true;
  };

  hardware.bluetooth = {
    enable = true;
    settings = {
      General = {
        experimental = true;
      };
    };
  };

  # Gaming
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Scanning
  hardware.sane = {
    enable = true;
    extraBackends = [pkgs.hplipWithPlugin];
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.komi = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = ["wheel" "adbusers" "scanner" "lp" "docker"];
  };

  programs = {
    firefox.enable = true;

    niri = {
      enable = true;
    };

    zsh.enable = true;

    seahorse.enable = true;

    thunar = {
      enable = true;
      plugins = with pkgs; [thunar-archive-plugin thunar-volman];
    };

    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };

    gamemode.enable = true;

    direnv.enable = true;

    vscode.enable = true;

    kdeconnect.enable = true;

    weylus = {
      enable = true;
      users = ["root" "komi"];
      openFirewall = true;
    };

    # VPN
    cproxy.enable = true;
    urix.enable = true;

    # For ciscoPacketTracer9
    firejail = {
      enable = true;
      wrappedBinaries = {
        packettracer9 = {
          executable = lib.getExe pkgs.ciscoPacketTracer9;

          # Will still want a .desktop entry as the package is not directly added
          desktop = "${pkgs.ciscoPacketTracer9}/share/applications/cisco-packet-tracer-9.desktop";

          extraArgs = [
            # This should make it run in isolated netns, preventing internet access
            "--net=none"

            # firejail is only needed for network isolation so no futher profile is needed
            "--noprofile"

            # Packet tracer doesn't play nice with dark QT themes so this
            # should unset the theme. Uncomment if you have this issue.
            # ''--env=QT_STYLE_OVERRIDE=""''
          ];
        };
      };
    };
  };

  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    libcap
    stdenv.cc.cc
    zlib
    openssl
  ];

  virtualisation.docker.enable = true;

  security.sudo.extraRules = [
    {
      users = ["komi"];
      commands = [
        {
          command = "/run/current-system/sw/bin/ip";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/cproxy";
          options = ["NOPASSWD" "SETENV"];
        }
      ];
    }
  ];

  # Shell
  programs.dms-shell = {
    enable = true;

    systemd = {
      enable = true; # Systemd service for auto-start
      restartIfChanged = true; # Auto-restart dms.service when dms-shell changes
    };

    # Core features
    enableSystemMonitoring = true; # System monitoring widgets (dgop)
    enableVPN = true; # VPN management widget
    enableDynamicTheming = true; # Wallpaper-based theming (matugen)
    enableAudioWavelength = true; # Audio visualizer (cava)
    enableCalendarEvents = false; # Calendar integration (khal)
    enableClipboardPaste = true; # Pasting from the clipboard history (wtype)
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  environment.systemPackages = with pkgs;
    [
      vim
      wget
      neovim
      vscode
      kitty
      telegram-desktop
      vesktop
      zsh
      zinit
      fzf
      tmux
      wallust
      mpv
      obsidian
      gcc
      bluez
      bluez-tools
      wl-clipboard
      busybox
      git
      brightnessctl
      pavucontrol
      bibata-cursors
      qview
      btop
      nvtopPackages.amd
      rocmPackages.rocm-smi
      spotify
      pulseaudio
      yazi
      rofi
      rofimoji
      lsd
      file-roller
      unzip
      qbittorrent
      qalculate-gtk
      powertop
      fastfetch
      thunderbird

      # Printing, scanning
      hplipWithPlugin
      simple-scan

      # Launcher
      walker

      # Comms
      rustdesk
      inetutils

      # Secrets
      bitwarden-desktop

      # Wine
      wineWow64Packages.unstableFull
      wineWow64Packages.wayland
      winetricks

      # Networking
      samba
      cifs-utils

      # Packages for Niri
      xwayland-satellite
      labwc

      # Packages that I need from hypr*
      hyprpicker

      # Drawing
      inkscape-with-extensions
      figma-linux
      gimp

      # Editing
      shotcut
      gnome-text-editor

      # Utilities
      wev
      obs-studio
      gparted
      exfatprogs
      ghostscript
      sshfs
      kalker
      ffmpeg
      zip
      libwebp
      ripgrep-all
      ripgrep
      file

      # VPN Utilities
      qrencode
      wireguard-tools
      xray

      # Dev
      zed-editor
      devenv
      gitkraken
      lazygit

      # Dev - js
      bun
      nodejs

      # Dev - protocols
      mqttui
      mqttx

      # AI tools
      codex
      claude-code
      gemini-cli

      # Gaming
      prismlauncher
      lutris
      r2modman

      # Themes
      colloid-gtk-theme
      colloid-icon-theme
      adwaita-icon-theme

      google-chrome

      # Office packages
      libreoffice-fresh
      hyphen
      hyphenDicts.ru_RU
      hunspell
      hunspellDicts.ru_RU
      # onlyoffice-desktopeditors

      # === Tmp packages - School ===

      # Android & Java dev
      android-studio
      android-tools
      jetbrains.idea

      # Cisco
      ciscoPacketTracer9

      # CSharp
      dotnet-sdk_10

      # Flutter dev
      libGLU

      # Plantuml
      plantuml

      # === Flakes ===

      inputs.zen-browser.packages.${system}.default
      # inputs.nixCats.packages.${system}.nixCats
      sddm-theme
      sddm-theme.test

      inputs.oglgl.packages.${system}.default

      inputs.happ.packages.${system}.default
    ]
    ++
    # Import all scripts from a directory and
    # Add them as packages
    map (scr: import scr {inherit pkgs config;}) (pkgs.lib.filesystem.listFilesRecursive ./scripts);

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "niri";
    EDITOR = "nvim";
    DICPATH = "/run/current-system/sw/share/hunspell:/run/current-system/sw/share/hyphen";

    # Proxy envvars
    HTTP_PROXY = "http://127.0.0.1:10809";
    HTTPS_PROXY = "http://127.0.0.1:10809";
  };

  environment.pathsToLink = [
    "/share/hunspell"
    "/share/myspell"
    "/share/hyphen"
  ];

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;

      trusted-users = ["root" "komi"];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  services.gnome.gnome-keyring.enable = true;

  services.upower.enable = true;

  # BUG: Conflicts with dms?
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
  #
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";
  #
  #     CPU_BOOST_ON_AC = 1;
  #     CPU_BOOST_ON_BAT = 0;
  #
  #     CPU_SCALING_MIN_FREQ_ON_AC = 400000;
  #     CPU_SCALING_MAX_FREQ_ON_AC = 4785000;
  #     CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
  #     CPU_SCALING_MAX_FREQ_ON_BAT = 3285000;
  #
  #     # Optional helps save long term battery health
  #     START_CHARGE_THRESH_BAT0 = 40;
  #     STOP_CHARGE_THRESH_BAT0 = 80;
  #
  #     USB_AUTOSUSPEND = 0;
  #   };
  # };

  services.thermald.enable = true;

  services.system76-scheduler.settings.cfsProfiles.enable = true;

  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = ["*"];
        settings = {
          main = {
            capslock = "overload(control, esc)";
          };
        };
      };
    };
  };

  # Dev
  services.postgresql = {
    enable = true;
  };

  services.tailscale = {
    enable = true;
    extraUpFlags = [
      "--accept-routes=true"
      "--accept-dns=true"
    ];
  };

  # Proxy/vpn
  services.happd.enable = true;
  # services.v2raya = {
  #   enable = true;
  #   cliPackage = pkgs.xray;
  # };

  powerManagement.enable = true;

  networking.firewall = {
    enable = false;
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      } # KDE Connect
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      } # KDE Connect
    ];
    checkReversePath = "loose";
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # system.nixos.label = "Niko";

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}
