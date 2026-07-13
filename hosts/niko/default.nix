{
  config,
  inputs,
  pkgs,
  system,
  ...
}: let
  sddmTheme = inputs.silentSDDM.packages.${system}.default.override {
    theme = "rei";
  };
  spotifyWayland = pkgs.symlinkJoin {
    name = "spotify-wayland-${pkgs.spotify.version}";

    paths = [pkgs.spotify];

    nativeBuildInputs = [pkgs.makeWrapper];

    postBuild = ''
      rm "$out/bin/spotify"

      makeWrapper ${pkgs.spotify}/bin/spotify "$out/bin/spotify" \
      --unset DISPLAY
    '';
  };
in {
  _module.args = {inherit sddmTheme;};

  imports = [
    ./hardware.nix
    ./secrets.nix
    ../../modules/nixos
    ../../nvim/configuration.nix
  ];

  networking.hostName = "Niko";

  # Set your time zone.
  time.timeZone = "Asia/Yekaterinburg";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.komi = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = ["wheel" "adbusers" "scanner" "lp" "docker" "networkmanager"];
  };

  programs.zsh.enable = true;

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
      mpv-unwrapped
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
      spotifyWayland # Need to unset DISPLAY so spotify works under wayland
      pulseaudio
      lsd
      file-roller
      qbittorrent
      qalculate-gtk
      powertop
      fastfetch
      thunderbird

      # Printing, scanning
      hplipWithPlugin
      simple-scan

      # Comms
      inetutils

      # Launcher
      vicinae

      # Secrets
      # bitwarden-desktop # electron EOL error?

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
      drawio

      # Editing
      shotcut

      # Text
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
      unzip
      jq
      pciutils

      # Utilities - MD -> PDF
      pandoc
      texliveSmall

      # VPN Utilities
      qrencode
      wireguard-tools
      xray

      # Secrets
      sops
      age

      # Dev
      zed-editor
      devenv
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

      # Gaming
      prismlauncher
      r2modman

      # Themes
      colloid-gtk-theme
      colloid-icon-theme
      adwaita-icon-theme

      # Browsers
      google-chrome
      firefox-bin

      # Office packages
      libreoffice-fresh
      hyphen
      hyphenDicts.ru_RU
      hunspell
      hunspellDicts.ru_RU

      # === Tmp packages - School ===

      # Android & Java dev
      android-studio
      android-tools

      # CSharp
      dotnet-sdk_10

      # Flutter dev
      libGLU

      # Plantuml
      plantuml

      # === Flakes ===

      inputs.zen-browser.packages.${system}.default
      sddmTheme
      sddmTheme.test

      inputs.oglgl.packages.${system}.default
    ]
    ++
    # Import all scripts from a directory and
    # Add them as packages
    map (scr: import scr {inherit pkgs config;}) (pkgs.lib.filesystem.listFilesRecursive ../../scripts);

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

  # For dotnet lsps
  # Because they can't find dotnet without envs
  environment.sessionVariables = {
    DOTNET_ROOT = "${pkgs.dotnet-sdk_10}/share/dotnet";
    DOTNET_ROOT_X64 = "${pkgs.dotnet-sdk_10}/share/dotnet";
  };

  environment.etc."dotnet/install_location".text = "${pkgs.dotnet-sdk_10}/share/dotnet\n";

  environment.etc."dotnet/install_location_x64".text = "${pkgs.dotnet-sdk_10}/share/dotnet\n";

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
