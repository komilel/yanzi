{
  pkgs,
  lib,
  ...
}: {
  # Enable virtualisation
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
    };
  };

  # Add virt-manager
  programs.virt-manager.enable = true;

  # Add your user to the libvirtd group
  users.users.komi.extraGroups = ["libvirtd" "kvm"];

  # Enable dconf (needed for virt-manager settings persistence)
  programs.dconf.enable = true;

  # Enable spice-vdagent for clipboard sharing
  virtualisation.spiceUSBRedirection.enable = true;
}
