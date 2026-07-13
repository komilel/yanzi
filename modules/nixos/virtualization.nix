{pkgs, ...}: {
  virtualisation = {
    docker.enable = true;

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

  programs = {
    dconf.enable = true;
    virt-manager.enable = true;
  };

  users.users.komi.extraGroups = ["libvirtd" "kvm"];
}
