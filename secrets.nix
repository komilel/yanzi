{config, ...}: {
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;

    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets.CODEX_CA_CERTIFICATE_FILE = {
      owner = "komi";
      mode = "0400";
    };

    secrets.CODEX_LB_API_KEY_FILE = {
      owner = "komi";
      mode = "0400";
    };
  };

  environment.sessionVariables = {
    CODEX_CA_CERTIFICATE = config.sops.secrets.CODEX_CA_CERTIFICATE_FILE.path;
  };

  environment.extraInit = ''
    if [ -r "${config.sops.secrets.CODEX_LB_API_KEY_FILE.path}" ]; then
      export CODEX_LB_API_KEY="$(cat "${config.sops.secrets.CODEX_LB_API_KEY_FILE.path}")"
    fi
  '';
}
