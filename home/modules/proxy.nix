{pkgs, ...}: let
  firefoxDirect = pkgs.writeShellScriptBin "firefox-direct" ''
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
    exec ${pkgs.firefox-bin}/bin/firefox "$@"
  '';

  chromeDirect = pkgs.writeShellScriptBin "chrome-direct" ''
    unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
    exec ${pkgs.google-chrome}/bin/google-chrome-stable "$@"
  '';
in {
  home.packages = [firefoxDirect chromeDirect];

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
