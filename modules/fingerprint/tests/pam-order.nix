{
  runCommandCC,
  writeText,
  python3,
  linux-pam,
  services,
}: let
  rules = writeText "fingerprint-pam-rules.json" (builtins.toJSON {
    sddm = services.sddm.text;
    login = services.login.text;
    sshd = services.sshd.text;
  });
in
  runCommandCC "fingerprint-sddm-pam-regressions" {
    nativeBuildInputs = [python3];
    buildInputs = [linux-pam];
  } ''
    $CC -shared -fPIC ${./pam-mock.c} -o mock.so -lpam
    python3 ${./pam-order.py} ${rules} ${linux-pam}/lib/libpam.so "$PWD/mock.so"
    touch "$out"
  ''
