{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };

    supportedFilesystems = ["ntfs"];

    kernel.sysctl = {
      "fs.inotify.max_user_watches" = 1048576;
      # Zram swap is nearly free, so bias the kernel toward using it.
      "vm.swappiness" = 100;
    };
  };

  # Compressed RAM swap takes priority over the NVMe swap partition.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  powerManagement = {
    enable = true;
    powertop.enable = false;
  };
}
