{
  description = "Happ proxy desktop client";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    packages.${system}.default = pkgs.callPackage ./package.nix {};

    # NixOS module – enables the happd daemon system-wide
    nixosModules.default = {
      config,
      lib,
      pkgs,
      ...
    }: let
      cfg = config.services.happd;
      happ = self.packages.${system}.default;
    in {
      options.services.happd.enable = lib.mkEnableOption "Happ proxy daemon";

      config = lib.mkIf cfg.enable {
        systemd.services.happd = {
          description = "Happ Process Control Daemon";
          after = ["network.target"];
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${happ}/opt/happ/bin/happd";
            Restart = "on-failure";
            RestartSec = "5s";
            TimeoutStopSec = "10s";
            KillMode = "mixed";
            KillSignal = "SIGTERM";
          };
        };
      };
    };
  };
}
