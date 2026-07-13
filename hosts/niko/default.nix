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
in {
  _module.args = {inherit sddmTheme;};

  imports = [
    ./hardware.nix
    ./secrets.nix
    ../../modules/nixos
    ../../nvim/configuration.nix
    ../../profiles/school.nix
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
      # Base system and administration
      vim
      wget
      bluez
      bluez-tools
      busybox
      pulseaudio
      powertop
      hplipWithPlugin
      inetutils
      samba
      cifs-utils
      exfatprogs
      pciutils
      wireguard-tools

      # Session infrastructure
      xwayland-satellite
      labwc
      adwaita-icon-theme

      # System-wide dictionaries
      hyphen
      hyphenDicts.ru_RU
      hunspell
      hunspellDicts.ru_RU

      # SDDM theme and its intentionally retained development artifact
      sddmTheme
      sddmTheme.test
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
