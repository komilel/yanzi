{pkgs, ...}: let
  cproxyCmd = "sudo -E /run/current-system/sw/bin/cproxy --port 12345 --mode tproxy --";

  mkProxyWrapper = name: bin:
    pkgs.writeShellScriptBin name ''
      exec ${cproxyCmd} ${bin} "$@"
    '';

  proxyApps = {
    chrome-proxy = "google-chrome-stable --user-data-dir=$HOME/.config/chrome-proxy";
    vesktop-proxy = "vesktop";
    telegram-proxy = "Telegram";
  };

  wrappers = builtins.attrValues (builtins.mapAttrs mkProxyWrapper proxyApps);
in {
  home.packages = wrappers;

  programs.bash.shellAliases =
    builtins.mapAttrs (
      _name: bin: "${cproxyCmd} ${bin}"
    )
    proxyApps
    // {
      proxy = "${cproxyCmd}";
    };

  xdg.desktopEntries = {
    chrome-proxy = {
      name = "Google Chrome (Proxy)";
      exec = "chrome-proxy %U";
      icon = "google-chrome";
      comment = "Chrome through proxy";
      categories = ["Network" "WebBrowser"];
      terminal = false;
    };
    vesktop-proxy = {
      name = "Vesktop (Proxy)";
      exec = "vesktop-proxy %U";
      icon = "vesktop";
      comment = "Vesktop through proxy";
      categories = ["Network" "InstantMessaging"];
      terminal = false;
    };
    telegram-proxy = {
      name = "Telegram (Proxy)";
      exec = "telegram-proxy -- %U";
      icon = "telegram";
      comment = "Telegram through proxy";
      categories = ["Network" "InstantMessaging"];
      terminal = false;
    };
  };
}
