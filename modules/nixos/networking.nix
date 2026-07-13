{
  imports = [
    ../cproxy
    ../urix
  ];

  networking = {
    networkmanager.enable = true;

    firewall = {
      enable = false;
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      checkReversePath = "loose";
    };
  };

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    samba.enable = true;

    tailscale = {
      enable = true;
      extraUpFlags = [
        "--accept-routes=true"
        "--accept-dns=true"
      ];
    };
  };

  programs = {
    cproxy.enable = true;
    urix.enable = true;
  };

  security.sudo.extraRules = [
    {
      users = ["komi"];
      commands = [
        {
          command = "/run/current-system/sw/bin/ip";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/cproxy";
          options = ["NOPASSWD" "SETENV"];
        }
      ];
    }
  ];
}
