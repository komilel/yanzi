{
  weylus,
  fetchFromGitHub,
  rustPlatform,
  ffmpeg,
  gst_all_1,
}:
weylus.overrideAttrs (final: previous: {
  version = "0.11.4-pr560-808a2a0-client-v3-runtime-v2-cursor-v1";

  # Unmerged PR #560: native Wayland DMA-BUF capture and VAAPI import.
  src = fetchFromGitHub {
    owner = "H-M-H";
    repo = "Weylus";
    rev = "808a2a0929be73c96089d50ca0466121619f18b2";
    hash = "sha256-2S/EvwDtrVz9nFbE8HTNkJA/S7G6T4VG5SLQJV90GAA=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (final) src;
    # Code-only patches leave Cargo.lock unchanged; reuse the existing vendor tree.
    name = "${final.pname}-0.11.4-pr560-808a2a0-client-v2";
    hash = "sha256-aokIFGGxxihKZNO7uzTu+dCShdPb5avBKR1koguEH+o=";
  };

  patches = (previous.patches or []) ++ [
    ./patches/client-v2.patch
    ./patches/runtime-stability.patch
    ./patches/cursor-session.patch
    ./patches/capture-pacing.patch
    ./patches/smooth-playback.patch
  ];

  # Rust regressions inspect real MP4 packets and H.264 VUI, not FPS guesses.
  nativeCheckInputs = (previous.nativeCheckInputs or []) ++ [ffmpeg];
  preCheck =
    (previous.preCheck or "")
    + ''
      # The clock-pacing regression uses a real appsrc/appsink without a display.
      export GST_PLUGIN_PATH="${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0''${GST_PLUGIN_PATH:+:$GST_PLUGIN_PATH}"
    '';

  postPatch =
    (previous.postPatch or "")
    + ''
      # build.rs otherwise decides whether to run TypeScript by timestamps.
      # Always compile our patched client rather than embed upstream's JS.
      rm -f www/static/lib.js
    '';

  postInstall =
    (previous.postInstall or "")
    + ''
      install -Dm644 www/static/lib.js "$out/share/weylus/lib.js"
      install -Dm644 ts/lib.ts "$out/share/weylus/lib.ts"
    '';
})
