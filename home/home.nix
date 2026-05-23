{
  config,
  pkgs,
  inputs,
  system,
  ...
}: {
  imports = [
    ./zsh.nix
    ./modules/bundle.nix
  ];

  home.username = "komi";

  home.homeDirectory = "/home/komi";

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  home.packages = [
    (pkgs.symlinkJoin {
      name = "onlyoffice-wayland";
      paths = [pkgs.onlyoffice-desktopeditors];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/onlyoffice-desktopeditors \
        --add-flags "--ozone-platform=wayland" \
        --add-flags "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      '';
    })
  ];

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";
}
