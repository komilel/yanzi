{
  config,
  pkgs,
  ...
}: {
  virtualisation = {
    docker = {
      enable = true;
      # Image pulls run in the daemon, which does not inherit session proxy variables.
      daemon.settings.proxies = {
        http-proxy = config.environment.sessionVariables.HTTP_PROXY;
        https-proxy = config.environment.sessionVariables.HTTPS_PROXY;
        no-proxy = "localhost,127.0.0.1,::1";
      };
    };

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        swtpm.enable = true;
        vhostUserPackages = [pkgs.virtiofsd];
      };
    };

    spiceUSBRedirection.enable = true;
  };

  environment.systemPackages = [pkgs.distrobox];

  environment.etc."distrobox/distrobox.conf".text = ''
    # Reuse the existing Docker daemon.
    container_manager="docker"
    # Make Nix-backed Home Manager shell configuration available in containers.
    container_additional_volumes="/nix/store:/nix/store:ro /etc/profiles/per-user:/etc/profiles/per-user:ro /etc/static/profiles/per-user:/etc/static/profiles/per-user:ro"
    # SSL_CERT_FILE points at this runtime CA bundle (see hosts/niko/secrets.nix).
    container_additional_volumes="$container_additional_volumes /run/zed-ca:/run/zed-ca:ro"
  '';

  programs = {
    dconf.enable = true;
    virt-manager.enable = true;
  };

  users.users.komi.extraGroups = ["libvirtd" "kvm"];
}
