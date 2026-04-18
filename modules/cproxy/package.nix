{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "cproxy";
  version = "4.2.2";

  src = fetchFromGitHub {
    owner = "NOBLES5E";
    repo = "cproxy";
    rev = "v${version}";
    hash = "sha256-WU2goAiTPE8cTK3dDSX+RHvVBoY5QMBTZc1bu8ZOQn8=";
  };

  cargoHash = "sha256-MTBaraHZ60QhgaQn95pmFb23nC6D+KLWAmS186qyaFg=";

  meta = with lib; {
    description = "Easy per-application transparent proxy built on cgroup";
    homepage = "https://github.com/NOBLES5E/cproxy";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "cproxy";
  };
}
