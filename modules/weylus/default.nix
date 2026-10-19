{
  callPackage,
  writeShellApplication,
  coreutils,
  tailscale,
}: let
  patchedWeylus = callPackage ./package.nix {};
in
  writeShellApplication {
    name = "weylus-pipewire";
    runtimeInputs = [coreutils tailscale];
    text = builtins.replaceStrings ["@weylus@"] ["${patchedWeylus}/bin/weylus"] (builtins.readFile ./launch.sh);
    passthru = {inherit patchedWeylus;};
    meta = {
      description = "Isolated Weylus launcher with Niri DMA-BUF/VAAPI capture and patched playback";
      mainProgram = "weylus-pipewire";
    };
  }
