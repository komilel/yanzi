{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  makeWrapper,
  libGL,
  qt6,
  wayland,
  libxkbcommon,
  zlib,
  fontconfig,
  freetype,
  libx11,
  libgpg-error,
  e2fsprogs,
}:
stdenv.mkDerivation rec {
  pname = "happ";
  version = "2.6.0";

  src = fetchurl {
    url = "https://github.com/Happ-proxy/happ-desktop/releases/download/${version}/Happ.linux.x64.deb";
    hash = "sha256-EQ8c4sLEgq8iZ4h84Wp3+gef+UkruilYowwm70j66lk=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  # System libs missing from the bundled set
  buildInputs = [
    stdenv.cc.cc.lib # libstdc++.so.6
    libGL # libGL.so.1, libGLX.so.0, libOpenGL.so.0, libEGL.so.1
    qt6.qtwayland # libQt6WlShellIntegration.so.6
    wayland # libwayland-client.so, libwayland-cursor.so, libwayland-egl.so
    libxkbcommon # libxkbcommon.so (keyboard handling on Wayland)
    zlib # libz.so.1
    fontconfig # libfontconfig.so.1
    freetype # libfreetype.so.6
    libx11 # libX11.so.6
    libgpg-error # libgpg-error.so.0
    e2fsprogs # libcom_err.so.2
  ];

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  # Happ ships its own Qt and qt.conf. Wrapping it with Nix's Qt hook injects
  # host plugin paths ahead of the bundled plugins, which causes ABI mismatches
  # like system libqxcb.so being loaded against bundled Qt libraries.
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    # Preserve the bin/lib layout that the binary's $ORIGIN/../lib rpath expects
    mkdir -p "$out/opt/happ"
    cp -r opt/happ/bin "$out/opt/happ/"
    cp -r opt/happ/lib "$out/opt/happ/"

    # Expose main binaries on PATH. The GUI binary is wrapped to ignore host Qt
    # theming/plugin overrides; Happ ships its own Qt runtime, plugins and QML.
    mkdir -p "$out/bin"
    makeWrapper "$out/opt/happ/bin/Happ" "$out/bin/happ" \
      --unset QT_PLUGIN_PATH \
      --unset QML2_IMPORT_PATH \
      --unset NIXPKGS_QT6_QML_IMPORT_PATH \
      --unset QT_STYLE_OVERRIDE \
      --unset QT_QUICK_CONTROLS_STYLE
    ln -s "$out/opt/happ/bin/happd"      "$out/bin/happd"
    ln -s "$out/opt/happ/bin/happ-tcping" "$out/bin/happ-tcping"

    # Desktop entry and icon
    install -Dm644 usr/share/applications/Happ.desktop \
      "$out/share/applications/Happ.desktop"
    substituteInPlace "$out/share/applications/Happ.desktop" \
      --replace-fail 'Exec=/opt/happ/bin/Happ %f' 'Exec=happ %f'
    install -Dm644 usr/share/icons/hicolor/256x256/apps/happ.png \
      "$out/share/icons/hicolor/256x256/apps/happ.png"

    runHook postInstall
  '';

  # autoPatchelfHook scans all ELF files under $out and patches:
  #   - the interpreter (/lib64/ld-linux-x86-64.so.2 → Nix glibc)
  #   - appends Nix store lib paths to RPATH for any "not found" deps
  # The existing $ORIGIN/../lib rpath is preserved, so bundled Qt6 libs work.
  appendRunpaths = [
    # The bundled libs dir; autoPatchelfHook preserves $ORIGIN ones but
    # sub-binaries (xray, sing-box, etc.) may need an explicit absolute path.
    "${placeholder "out"}/opt/happ/lib"
  ];

  meta = with lib; {
    description = "Happ proxy desktop client";
    homepage = "https://github.com/Happ-proxy/happ-desktop";
    platforms = ["x86_64-linux"];
    license = licenses.unfree;
    mainProgram = "happ";
    sourceProvenance = [sourceTypes.binaryNativeCode];
  };
}
