# urix

Interactive proxy manager for xray on NixOS. Per-app proxying via cgroups, subscription management, TUN/SOCKS5/HTTP modes — all from a terminal TUI without sudo.

## Architecture

```
urixd (root, systemd)              urix (user, no sudo)
├── xray lifecycle                  ├── CLI commands
├── cgroup + iptables               ├── TUI (curses, 3 tabs)
├── netlink watcher (auto-add)      │   ├── [1] Apps
├── tun2socks (TUN mode)            │   ├── [2] Servers
└── unix socket /run/urix.sock      │   └── [3] Modes
    ↕ JSON-RPC                      └── animations (dissolve/rainbow)
```

## NixOS Setup

```nix
# configuration.nix
imports = [ ./modules/urix ];

programs.urix = {
  enable = true;
  # socketPath = "/run/urix.sock";
  # blockedInterfaces = [ "tailscale0" "vpn-2" ];
};
```

```bash
sudo nixos-rebuild switch --flake ~/nixos-config
```

## Usage

```bash
# Service runs automatically via systemd
systemctl status urixd

# TUI (no sudo needed)
urix ui

# CLI
urix status                    # service status
urix list                      # proxied apps
urix add-name vesktop          # proxy by name
urix add 1234                  # proxy by PID
urix remove 1234               # unproxy
urix run firefox               # launch app through proxy
urix sub <url>                 # load subscription
urix ping                      # ping all servers
```

## TUI Tabs

### [1] Apps
Toggle per-app proxying. Processes grouped by application. Enter adds/removes all child processes and saves to auto_proxy list. Watcher (netlink cn_proc) auto-adds new processes matching saved apps.

### [2] Servers
Select VPN server from subscription. `[p]` ping all, `[a]` add subscription URL, `[u]` update. Server switch has dissolve/appear animation with rainbow wave.

### [3] Modes
- **TUN** — all system traffic via tun2socks (exclusive)
- **SOCKS5** — `127.0.0.1:10808`
- **HTTP** — `127.0.0.1:10809`
- **Per-app** — cgroup + tproxy + dokodemo-door

TUN is exclusive. SOCKS5/HTTP/Per-app can be combined.

## Files

```
modules/urix/
├── default.nix          # NixOS module (options.programs.urix)
├── package.nix          # Nix derivation
├── overlay.nix          # pkgs.urix overlay
├── README.md
└── src/
    ├── urixd            # daemon entry point
    ├── urix             # client entry point (CLI + TUI)
    ├── urix_server.py   # asyncio daemon, RPC dispatch, event broadcast
    ├── urix_client.py   # socket transport (non-blocking)
    ├── urix_rpc.py      # JSON-RPC encode/decode
    ├── urix_config.py   # constants, config I/O
    ├── urix_process.py  # /proc scanning, cgroup ops, app grouping
    ├── urix_watcher.py  # netlink cn_proc auto-add daemon
    ├── urix_subscription.py  # VLESS parser, subscription fetch, ping
    ├── urix_service.py  # xray/iptables lifecycle
    ├── urix_modes.py    # TUN/SOCKS5/HTTP/per-app mode management
    └── urix_tui.py      # curses TUI with animations
```

## Protocol

JSON-RPC over unix socket (`/run/urix.sock`), one JSON per line.

```
→ {"method": "app.list", "id": 1}
← {"result": [...], "id": 1}

→ {"method": "subscribe", "id": 0}
← {"event": "watcher.match", "data": {"pid": 1234, "name": "Vesktop"}}
```

## Runtime Data

Config and PID files stored in `/var/lib/urix/`:
- `config.json` — auto_proxy list, servers, active modes
- `xray.json` — generated xray config
- `xray.pid`, `watcher.pid`, `tun2socks.pid`

## Dependencies

- Python 3 (stdlib only, no pip packages)
- xray
- tun2socks (for TUN mode)
- iptables, iproute2
