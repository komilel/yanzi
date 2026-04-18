{ config, lib, pkgs, ... }:

let
  cfg = config.programs.cproxy;
in
{
  options.programs.cproxy = {
    enable = lib.mkEnableOption "cproxy - per-app transparent proxy via cgroup";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cproxy;
      defaultText = lib.literalExpression "pkgs.cproxy";
      description = "The cproxy package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (import ./overlay.nix)
    ];

    environment.systemPackages = [ cfg.package pkgs.iptables pkgs.iproute2 ];

    # cproxy needs iptables and ip rule access
    security.wrappers.cproxy = {
      owner = "root";
      group = "root";
      setuid = true;
      source = "${cfg.package}/bin/cproxy";
    };
  };
}
