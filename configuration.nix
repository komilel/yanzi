# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ self, config, inputs, pkgs, lib, system, ... }:
let
  sddm-theme = inputs.silentSDDM.packages.${system}.default.override {
      theme = "rei";
  };
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "ntfs" ];

  networking.hostName = "HyprNix"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

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
    vistafonts
    font-awesome
    noto-fonts 
    noto-fonts-emoji
    noto-fonts-extra
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
  ];

  qt.enable = true;

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = with pkgs; [ hplip hplipWithPlugin ];
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

  services.blueman.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Mount, trash, and other functionalities
  services.gvfs.enable = true;

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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.komi = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "kvm" "adbusers" ];
  };

  programs = {
    firefox.enable = true;

    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${system}.hyprland;
      portalPackage = inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland;
    };

    niri = {
      enable = true;
    };

    zsh.enable = true;

    seahorse.enable = true;

    thunar = {
      enable = true;
      plugins = with pkgs.xfce; [ thunar-archive-plugin thunar-volman ];
    };

    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };

    gamemode.enable = true;

    direnv.enable = true;

    # Tmp
    adb.enable = true;
    
    # For ciscoPacketTracer8
    firejail = {
      enable = true;
      wrappedBinaries = {
        packettracer8 = {
          executable = lib.getExe pkgs.ciscoPacketTracer8;

          # Will still want a .desktop entry as the package is not directly added
          desktop = "${pkgs.ciscoPacketTracer8}/share/applications/cisco-pt8.desktop.desktop";

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

  nixpkgs.config = {
    allowUnfree = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim
    wget
    neovim
    vscode
    kitty
    telegram-desktop
    vesktop
    waybar
    walker
    swww
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
    dunst
    hyprpicker
    hyprland-per-window-layout
    git
    brightnessctl
    pavucontrol
    bibata-cursors
    qview
    btop
    nvtopPackages.full
    rocmPackages.rocm-smi
    spotify
    pulseaudio
    yazi
    rofi
    lsd
    networkmanagerapplet
    hyprshot
    file-roller
    unzip
    qbittorrent
    qalculate-gtk
    powertop

    # Drawing
    inkscape-with-extensions

    # Dev
    devenv

    # Gaming
    prismlauncher

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

    # === Tmp packages - School ===

    # Prolog language
    swi-prolog

    # Android java dev
    android-studio
    jetbrains.idea-community-bin

    # Gis
    qgis

    # Cisco packet tracer
    ciscoPacketTracer8

    # Plantuml
    plantuml

    # === Flakes ===

    inputs.zen-browser.packages.${system}.default
    inputs.nixCats.packages.${system}.nixCats
    sddm-theme
    sddm-theme.test

    inputs.oglgl.packages.${system}.default
  ] ++
  # Import all scripts from a folder and
  # Add them as packages
  builtins.map (scr: import scr {inherit pkgs config; }) (pkgs.lib.filesystem.listFilesRecursive ./scripts);

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;

      substituters = ["https://hyprland.cachix.org"];
      trusted-substituters = ["https://hyprland.cachix.org"];
      trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];

      trusted-users = [ "root" "komi" ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 10d";
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  services.gnome.gnome-keyring.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      CPU_SCALING_MIN_FREQ_ON_AC = 400000;
      CPU_SCALING_MAX_FREQ_ON_AC = 4785000;
      CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
      CPU_SCALING_MAX_FREQ_ON_BAT = 3285000;

      # Optional helps save long term battery health
      START_CHARGE_THRESH_BAT0 = 40;
      STOP_CHARGE_THRESH_BAT0 = 80;

      USB_AUTOSUSPEND = 0;
    };
  };

  services.thermald.enable = true;

  services.system76-scheduler.settings.cfsProfiles.enable = true;

  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "overload(control, esc)";
          };
        };
      };
    };
  };

  powerManagement.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
  networking.firewall.checkReversePath = "loose";

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

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
