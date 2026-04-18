{
  pkgs,
  lib,
  ...
}: {
  environment.etc."xray-tproxy/config.json".text = builtins.toJSON {
    inbounds = [
      {
        tag = "tproxy-in";
        port = 12345;
        protocol = "dokodemo-door";
        settings = {
          network = "tcp,udp";
          followRedirect = true;
        };
        streamSettings.sockopt.tproxy = "tproxy";
      }
    ];
    outbounds = [
      {
        protocol = "socks";
        settings.servers = [
          {
            address = "127.0.0.1";
            port = 20170;
          }
        ];
      }
    ];
  };

  systemd.services.xray-tproxy = {
    description = "Xray tproxy bridge for cproxy";
    after = ["v2raya.service"];
    wants = ["v2raya.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.xray}/bin/xray run -c /etc/xray-tproxy/config.json";
      AmbientCapabilities = "CAP_NET_ADMIN";
      CapabilityBoundingSet = "CAP_NET_ADMIN";
    };
  };
}
