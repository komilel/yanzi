{
  pkgs,
  lib,
  ...
}: {
  programs.claude-code = {
    enable = true;

    plugins = [
      pkgs.fetchFromGitHub
      {
        owner = "JuliusBrussee";
        repo = "caveman";
        rev = "c2ed24b3e5d412cd0c25197b2bc9af587621fd99";
        sha256 = "13riqfh6j2l6hv6qj30jwxvicm7bf7y17fxckfi55pqrjfb3zxlk";
      }
    ];
  };
}
