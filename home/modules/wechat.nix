{pkgs, ...}: let
  fontConfig = pkgs.writeText "wechat-arch-fonts.conf" (builtins.readFile ./wechat/fonts.conf);
  guestLauncher = pkgs.writeText "wechat-arch-guest.sh" (builtins.readFile ./wechat/launch.sh);

  wechatArch = pkgs.writeShellApplication {
    name = "wechat-arch";
    text = ''
      # Use Arch's interpreter and binary, not the host's WeChat or Portable wrapper.
      exec ${pkgs.distrobox}/bin/distrobox enter --no-tty --no-workdir arch -- \
        /usr/bin/bash ${guestLauncher} ${fontConfig} "$@"
    '';
  };
in {
  home.packages = [wechatArch];

  xdg.desktopEntries.wechat-arch = {
    name = "WeChat (Arch, Wayland)";
    comment = "Arch's newer WeChat with native Wayland and isolated font settings";
    exec = "${wechatArch}/bin/wechat-arch %U";
    icon = "wechat";
    categories = ["Network" "InstantMessaging"];
    terminal = false;
    startupNotify = false;
    settings.StartupWMClass = "wechat";
  };
}
