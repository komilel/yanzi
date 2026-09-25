{pkgs, ...}: {
  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        libcap
        stdenv.cc.cc
        zlib
        openssl

        # core runtime
        glib
        nss
        nspr
        expat
        fontconfig
        freetype
        dbus
        cups
        krb5
        systemd
        gtk3

        # graphics / GL
        mesa
        libdrm
        libglvnd
        vulkan-loader

        # X11 family
        libx11
        libxcb
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxi
        libxrandr
        libxrender
        libxtst
        libxcursor
        libxscrnsaver

        at-spi2-core

        # wayland — the important one for our purpose
        wayland
        libxkbcommon

        # audio
        alsa-lib
        libpulseaudio
      ];
    };
  };
}
