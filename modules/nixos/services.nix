{
  services = {
    gnome.gnome-keyring.enable = true;

    keyd = {
      enable = true;
      keyboards.default = {
        ids = ["*"];
        settings = {
          main.capslock = "overload(control, esc)";

          # Used for Zen's tab search shortcut.
          "control+alt".w = "macro(C-q 80ms S-5 space)";
        };
      };
    };

    openssh = {
      enable = true;
      openFirewall = true;
    };

    postgresql.enable = true;
    system76-scheduler.settings.cfsProfiles.enable = true;
    thermald.enable = true;
    upower.enable = true;
  };
}
