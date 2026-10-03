{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libusb1,
  libevent,
  dbus,
  openssl,
  opencv,
  python3,
}: let
  # These revisions are the gitlinks in the pinned fingerprint-ocv tree.
  # Fetch only the three required submodules, not the unused vcpkg tree.
  testPython = python3.withPackages (ps: [ps.dbus-python]);
  dependencies = {
    jinx = fetchFromGitHub {
      owner = "Kiwironic";
      repo = "jinx";
      rev = "7f9e70b6c0f718e301a5c9111b60dbce1ff9466e";
      hash = "sha256-R6xoFeXmRKX0ZSU9gnpB4yA4Kzj+aw3qO7moaCYQyic=";
    };
    asyncdbus = fetchFromGitHub {
      owner = "Kiwironic";
      repo = "asyncdbus";
      rev = "c8962400fce4ec84955f0cedc456cfb87e760925";
      hash = "sha256-7ZrpL/kfF1OxBs6yO/FLsdxQCqvGVjS40jH2Nu/JnBs=";
    };
    asyncusb = fetchFromGitHub {
      owner = "Kiwironic";
      repo = "asyncusb";
      rev = "d9e29478037123cfff8f009d7112250c4b2fd3df";
      hash = "sha256-hNoqsh9gu+MI/1NcyJor0qDElAsmcAGzkhTqW11O2Jk=";
    };
  };
in
  stdenv.mkDerivation {
    pname = "fingerprint-ocv";
    version = "1.0.0-unstable-2026-09-16";

    src = fetchFromGitHub {
      owner = "Kiwironic";
      repo = "fingerprint-ocv";
      rev = "69f6afec36873c2184566e29224efd7acef521ec";
      hash = "sha256-6/jBQvsLDnCq1Gf0kYouyQhtKTtVpyA593Sz/ifRlJE=";
    };

    patches = [
      ./patches/manager-without-sensor.patch
      ./patches/verification-lifecycle.patch
    ];

    postPatch =
      lib.concatStringsSep "\n" (lib.mapAttrsToList (name: source: ''
          cp -r --no-preserve=mode ${source}/. ${name}/
        '')
        dependencies)
      + ''
        cp ${./tests/unit.cpp} src/nix-tests.cpp
        cp ${./tests/device-fixture.cpp} src/nix-device-fixture.cpp
        cat ${./tests/CMakeLists.txt} >> src/CMakeLists.txt
      '';

    nativeBuildInputs = [cmake pkg-config];
    buildInputs = [libusb1 libevent dbus openssl opencv];
    nativeCheckInputs = [dbus testPython];

    cmakeFlags = [
      "-DBUILD_TESTING=ON"
      "-DJINX_BUILD_HTTP=OFF"
      "-DJINX_BUILD_CJSON=OFF"
      "-DJINX_BUILD_EVDNS=OFF"
    ];

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      ctest --output-on-failure
      dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf \
        -- python3 ${./tests/dbus-smoke.py} "$PWD/src/fingerprint-ocv"
      dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf \
        -- python3 ${./tests/device-lifecycle.py} "$PWD/src/fingerprint-ocv-device-fixture"
      runHook postCheck
    '';

    meta = {
      description = "Patched userspace driver for the FPC 10a5:9201 fingerprint reader";
      homepage = "https://github.com/Kiwironic/fingerprint-ocv";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.linux;
      mainProgram = "fingerprint-ocv";
    };
  }
