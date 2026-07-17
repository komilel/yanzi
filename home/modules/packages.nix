{
  inputs,
  pkgs,
  system,
  ...
}: let
  onlyofficeWayland = pkgs.symlinkJoin {
    name = "onlyoffice-wayland";
    paths = [pkgs.onlyoffice-desktopeditors];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/onlyoffice-desktopeditors \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
    '';
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
  home.packages =
    (with pkgs; [
      # Desktop applications
      telegram-desktop
      vesktop
      mpv-unwrapped
      obsidian
      qview
      qbittorrent
      qalculate-gtk
      thunderbird
      simple-scan
      vicinae
      inkscape-with-extensions
      figma-linux
      gimp
      drawio
      shotcut
      gnome-text-editor
      obs-studio
      gparted
      google-chrome
      libreoffice-fresh
      onlyofficeWayland
      spotifyWayland

      # Desktop utilities
      wl-clipboard
      brightnessctl
      pavucontrol
      file-roller
      hyprpicker
      wev
      btop
      nvtopPackages.amd
      rocmPackages.rocm-smi
      fastfetch

      # Shell utilities
      zinit
      lsd
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
      pandoc
      texliveSmall
      qrencode
      sops
      age

      # Development
      gcc
      devenv
      lazygit
      bun
      pnpm
      nodejs
      mqttui
      mqttx
      codex
      claude-code

      # Wine
      wineWow64Packages.unstableFull
      winetricks

      # Gaming
      prismlauncher
      r2modman
    ])
    ++ [
      inputs.zen-browser.packages.${system}.default
      inputs.oglgl.packages.${system}.default
      inputs.llm-agents.packages.${system}.pi
    ];
}
