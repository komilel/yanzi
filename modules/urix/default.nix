{ config, lib, pkgs, ... }:

let
  cfg = config.programs.urix;
in
{
  options.programs.urix = {
    enable = lib.mkEnableOption "urix - interactive xray proxy manager with TUI";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.urix;
      defaultText = lib.literalExpression "pkgs.urix";
      description = "The urix package to use.";
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/urix.sock";
      description = "Path to the urixd unix socket.";
    };

    blockedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tailscale0" "vpn-2" ];
      description = "Network interfaces to block for proxied applications (prevents WebRTC ICE issues).";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (import ./overlay.nix)
    ];

    environment.systemPackages = [
      cfg.package
      pkgs.xray
      pkgs.tun2socks
    ];

    # systemd service for the daemon
    systemd.services.urixd = {
      description = "urix proxy manager daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/urixd --socket ${cfg.socketPath}";
        Restart = "on-failure";
        RestartSec = 3;
        StateDirectory = "urix";
      };
    };
  };
}
