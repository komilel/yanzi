{pkgs, ...}: {
  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        libcap
        stdenv.cc.cc
        zlib
        openssl
      ];
    };
  };
}
