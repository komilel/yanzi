{
  config,
  pkgs,
  ...
}: let
  customCa = config.sops.secrets.CODEX_CA_CERTIFICATE_FILE.path;
  zedCaBundle = "/run/zed-ca/ca-bundle.crt";
in {
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;

    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets.CODEX_CA_CERTIFICATE_FILE = {
      owner = "komi";
      mode = "0400";

      # Recreate the combined bundle when the secret changes.
      restartUnits = ["zed-ca-bundle.service"];
    };

    secrets.CODEX_LB_API_KEY_FILE = {
      owner = "komi";
      mode = "0400";
    };

    secrets.Z_AI_API_KEY = {
      owner = "komi";
      mode = "0400";
    };
  };

  systemd.services.zed-ca-bundle = {
    description = "Generate CA bundle for Zed";

    wantedBy = ["multi-user.target"];
    after = ["sops-install-secrets.service"];

    path = [pkgs.coreutils];

    serviceConfig = {
      Type = "oneshot";
      User = "komi";

      RuntimeDirectory = "zed-ca";
      RuntimeDirectoryMode = "0755";

      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      temporary="$(mktemp /run/zed-ca/ca-bundle.crt.XXXXXX)"

      cat \
        /etc/ssl/certs/ca-certificates.crt \
        ${customCa} \
        > "$temporary"

      chmod 0444 "$temporary"
      mv -f "$temporary" ${zedCaBundle}
    '';
  };

  environment.sessionVariables = {
    CODEX_CA_CERTIFICATE = customCa;
    SSL_CERT_FILE = zedCaBundle;
    NODE_EXTRA_CA_CERTS = customCa;
  };

  environment.extraInit = ''
    if [ -r "${config.sops.secrets.CODEX_LB_API_KEY_FILE.path}" ]; then
      export CODEX_LB_API_KEY="$(cat "${config.sops.secrets.CODEX_LB_API_KEY_FILE.path}")"
    fi

    if [ -r "${config.sops.secrets.Z_AI_API_KEY.path}" ]; then
      export Z_AI_API_KEY="$(cat "${config.sops.secrets.Z_AI_API_KEY.path}")"
    fi
  '';
}
