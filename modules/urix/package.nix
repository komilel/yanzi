{
  lib,
  python3,
  xray,
  tun2socks,
  iptables,
  iproute2,
  makeWrapper,
}:

python3.pkgs.buildPythonApplication {
  pname = "urix";
  version = "0.1.0";
  format = "other";

  src = ./src;

  nativeBuildInputs = [ makeWrapper ];

  propagatedBuildInputs = [ python3 ];

  installPhase = ''
    # Server
    install -Dm755 urixd $out/bin/urixd
    install -Dm755 urix_server.py $out/lib/urix/urix_server.py
    install -Dm644 urix_config.py $out/lib/urix/urix_config.py
    install -Dm644 urix_rpc.py $out/lib/urix/urix_rpc.py
    install -Dm644 urix_process.py $out/lib/urix/urix_process.py
    install -Dm644 urix_watcher.py $out/lib/urix/urix_watcher.py
    install -Dm644 urix_subscription.py $out/lib/urix/urix_subscription.py
    install -Dm644 urix_service.py $out/lib/urix/urix_service.py
    install -Dm644 urix_modes.py $out/lib/urix/urix_modes.py

    # Client
    install -Dm755 urix $out/bin/urix
    install -Dm644 urix_client.py $out/lib/urix/urix_client.py
    install -Dm644 urix_tui.py $out/lib/urix/urix_tui.py

    # Wrap with PYTHONPATH and PATH (for xray, tun2socks, iptables)
    wrapProgram $out/bin/urixd \
      --prefix PYTHONPATH : $out/lib/urix \
      --prefix PATH : ${lib.makeBinPath [ xray tun2socks iptables iproute2 ]}

    wrapProgram $out/bin/urix \
      --prefix PYTHONPATH : $out/lib/urix
  '';

  meta = with lib; {
    description = "Interactive proxy manager for xray with TUI";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "urix";
  };
}
