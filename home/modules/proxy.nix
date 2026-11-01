{pkgs, ...}: let
  firefoxDirect = pkgs.writeShellScriptBin "firefox-direct" ''
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
    exec ${pkgs.firefox-bin}/bin/firefox "$@"
  '';

  chromeDirect = pkgs.writeShellScriptBin "chrome-direct" ''
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
    exec ${pkgs.google-chrome}/bin/google-chrome-stable "$@"
  '';

  # Keep this profile separate from normal Firefox and pin it to shluz's rus slot.
  firefoxRuPrefs = pkgs.writeText "firefox-ru-user.js" ''
    user_pref("network.proxy.type", 1);
    user_pref("network.proxy.socks", "127.0.0.1");
    user_pref("network.proxy.socks_port", 10818);
    user_pref("network.proxy.socks_version", 5);
    user_pref("network.proxy.socks_remote_dns", true);
    user_pref("network.proxy.no_proxies_on", "localhost, 127.0.0.1, ::1");
    user_pref("network.proxy.failover_direct", false);
    user_pref("network.trr.mode", 5);
    user_pref("network.http.http3.enable", false);
    user_pref("media.peerconnection.enabled", false);
  '';

  firefoxRu = pkgs.writeShellScriptBin "firefox-ru" ''
    set -eu
    umask 077
    unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
    unset http_proxy https_proxy all_proxy no_proxy

    profile="''${XDG_DATA_HOME:-$HOME/.local/share}/firefox-ru"
    ${pkgs.coreutils}/bin/install -d -m 700 "$profile"
    ${pkgs.coreutils}/bin/install -m 600 ${firefoxRuPrefs} "$profile/user.js"
    exec ${pkgs.firefox-bin}/bin/firefox --no-remote --profile "$profile" "$@"
  '';

  firefoxRuDesktop = pkgs.makeDesktopItem {
    name = "firefox-ru";
    desktopName = "Firefox (RU)";
    exec = "${firefoxRu}/bin/firefox-ru %U";
    icon = "firefox";
    comment = "Browse with a separate Firefox profile through shluz's rus slot";
    categories = ["Network" "WebBrowser"];
    terminal = false;
  };
in {
  home.packages = [firefoxDirect chromeDirect firefoxRu];

  home.file.".local/share/applications/firefox-ru.desktop".source =
    "${firefoxRuDesktop}/share/applications/firefox-ru.desktop";

  xdg.desktopEntries = {
    firefox-direct = {
      name = "Firefox (No Proxy)";
      exec = "firefox-direct %U";
      icon = "firefox";
      comment = "Browse Firefox without HTTP proxy environment variables";
      categories = ["Network" "WebBrowser"];
      terminal = false;
    };

    chrome-direct = {
      name = "Google Chrome (No Proxy)";
      exec = "chrome-direct %U";
      icon = "google-chrome";
      comment = "Browse Chrome without HTTP proxy environment variables";
      categories = ["Network" "WebBrowser"];
      terminal = false;
    };
  };
}
