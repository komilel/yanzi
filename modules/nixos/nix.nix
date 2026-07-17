{
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-users = ["root" "komi"];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  systemd.services.nix-daemon.environment = {
    HTTP_PROXY = "http://127.0.0.1:10809";
    HTTPS_PROXY = "http://127.0.0.1:10809";
    NO_PROXY = "127.0.0.1,localhost";
  };
}
