"""urix — управление режимами проксирования (TUN, SOCKS5, HTTP, Per-app)."""

import os
import signal
import subprocess
import time

from urix_config import (
    DATA_DIR, XRAY_CONFIG, PIDFILE, CGROUP, CGROUP_PATH, MARK, TABLE,
    TPROXY_PORT, load_config, save_config, run_quiet,
)

TUN_DEVICE = "utun0"
TUN_ADDR = "198.18.0.1"
TUN_GW = "198.18.0.0"
TUN_PIDFILE = os.path.join(DATA_DIR, "tun2socks.pid")
SOCKS_PORT = "10808"
HTTP_PORT = "10809"

# Path to tun2socks — found via nix-shell or PATH
TUN2SOCKS_BIN = None


def _find_tun2socks():
    global TUN2SOCKS_BIN
    if TUN2SOCKS_BIN:
        return TUN2SOCKS_BIN
    import shutil
    path = shutil.which("tun2socks")
    if path:
        TUN2SOCKS_BIN = path
        return TUN2SOCKS_BIN
    return None


def get_active_modes():
    """Return dict of currently active modes from config."""
    cfg = load_config()
    return cfg.get("modes", {
        "tun": False,
        "socks5": False,
        "http": False,
        "perapp": True,
    })


def save_modes(modes):
    cfg = load_config()
    cfg["modes"] = modes
    save_config(cfg)


def _rebuild_xray_inbounds(modes):
    """Rebuild xray.json inbounds based on active modes."""
    import json

    try:
        with open(XRAY_CONFIG) as f:
            xray_cfg = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        xray_cfg = {"inbounds": [], "outbounds": []}

    # Keep outbounds, rebuild inbounds
    inbounds = []

    if modes.get("tun") or modes.get("perapp"):
        # dokodemo-door for tproxy (used by both TUN via tun2socks→socks→xray and per-app)
        inbounds.append({
            "tag": "tproxy-in",
            "port": int(TPROXY_PORT),
            "protocol": "dokodemo-door",
            "settings": {"network": "tcp,udp", "followRedirect": True},
            "streamSettings": {"sockopt": {"tproxy": "tproxy"}},
        })

    if modes.get("tun") or modes.get("socks5"):
        inbounds.append({
            "tag": "socks-in",
            "port": int(SOCKS_PORT),
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {"udp": True},
        })

    if modes.get("http"):
        inbounds.append({
            "tag": "http-in",
            "port": int(HTTP_PORT),
            "listen": "127.0.0.1",
            "protocol": "http",
        })

    # If nothing selected, at least keep socks
    if not inbounds:
        inbounds.append({
            "tag": "socks-in",
            "port": int(SOCKS_PORT),
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {"udp": True},
        })

    xray_cfg["inbounds"] = inbounds
    with open(XRAY_CONFIG, "w") as f:
        json.dump(xray_cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")


def _restart_xray():
    """Restart xray process."""
    if os.path.exists(PIDFILE):
        try:
            pid = int(open(PIDFILE).read().strip())
            os.kill(pid, signal.SIGTERM)
            time.sleep(1)
        except (OSError, ValueError):
            pass

    proc = subprocess.Popen(
        ["xray", "run", "-c", XRAY_CONFIG],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    with open(PIDFILE, "w") as f:
        f.write(str(proc.pid))
    return proc.pid


# --- TUN mode ---

def start_tun():
    """Start tun2socks TUN interface."""
    binary = _find_tun2socks()
    if not binary:
        return False, "tun2socks не найден. Установи: nix-env -iA nixpkgs.tun2socks"

    # Start tun2socks
    proc = subprocess.Popen(
        [binary, "-device", TUN_DEVICE, "-proxy", f"socks5://127.0.0.1:{SOCKS_PORT}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    with open(TUN_PIDFILE, "w") as f:
        f.write(str(proc.pid))
    time.sleep(0.5)

    # Configure TUN interface
    run_quiet(f"ip addr add {TUN_ADDR}/15 dev {TUN_DEVICE}")
    run_quiet(f"ip link set {TUN_DEVICE} up")

    # Save original default route
    r = subprocess.run("ip route show default", shell=True, capture_output=True, text=True)
    orig_route = r.stdout.strip()

    cfg = load_config()
    cfg["tun_orig_route"] = orig_route
    save_config(cfg)

    # Get xray server IP to exclude from TUN
    import json
    try:
        with open(XRAY_CONFIG) as f:
            xray_cfg = json.load(f)
        server_addr = xray_cfg["outbounds"][0]["settings"]["vnext"][0]["address"]
        # Resolve if hostname
        import socket
        try:
            server_ip = socket.gethostbyname(server_addr)
        except socket.gaierror:
            server_ip = server_addr
        # Route server IP through original gateway
        if orig_route:
            gw_parts = orig_route.split()
            if "via" in gw_parts:
                gw_idx = gw_parts.index("via") + 1
                gw = gw_parts[gw_idx]
                dev_idx = gw_parts.index("dev") + 1 if "dev" in gw_parts else None
                dev = gw_parts[dev_idx] if dev_idx else ""
                run_quiet(f"ip route add {server_ip}/32 via {gw} dev {dev}")
    except Exception:
        pass

    # Set TUN as default route
    run_quiet(f"ip route replace default dev {TUN_DEVICE}")

    return True, f"TUN {TUN_DEVICE} активен"


def stop_tun():
    """Stop tun2socks and restore routing."""
    # Restore original route
    cfg = load_config()
    orig_route = cfg.get("tun_orig_route", "")
    if orig_route:
        run_quiet(f"ip route replace {orig_route}")

    # Remove server-specific route
    import json
    try:
        with open(XRAY_CONFIG) as f:
            xray_cfg = json.load(f)
        server_addr = xray_cfg["outbounds"][0]["settings"]["vnext"][0]["address"]
        import socket
        try:
            server_ip = socket.gethostbyname(server_addr)
        except socket.gaierror:
            server_ip = server_addr
        run_quiet(f"ip route del {server_ip}/32")
    except Exception:
        pass

    # Kill tun2socks
    if os.path.exists(TUN_PIDFILE):
        try:
            pid = int(open(TUN_PIDFILE).read().strip())
            os.kill(pid, signal.SIGTERM)
        except (OSError, ValueError):
            pass
        os.unlink(TUN_PIDFILE)

    # Remove TUN device
    run_quiet(f"ip link del {TUN_DEVICE}")


# --- Per-app mode (cgroup + iptables) ---

def start_perapp():
    """Setup cgroup + iptables for per-app proxying."""
    if not os.path.exists(CGROUP_PATH):
        os.makedirs(CGROUP_PATH, exist_ok=True)

    run_quiet(f"ip rule del fwmark {MARK} table {TABLE}")
    run_quiet(f"ip rule add fwmark {MARK} table {TABLE}")
    run_quiet(f"ip route replace local 0.0.0.0/0 dev lo table {TABLE}")

    run_quiet(f"iptables -t mangle -D OUTPUT -m cgroup --path {CGROUP} -j MARK --set-mark {MARK}")
    run_quiet(f"iptables -t mangle -A OUTPUT -m cgroup --path {CGROUP} -j MARK --set-mark {MARK}")

    for proto in ("tcp", "udp"):
        run_quiet(
            f"iptables -t mangle -D PREROUTING -m mark --mark {MARK} -p {proto} "
            f"-j TPROXY --on-port {TPROXY_PORT} --tproxy-mark {MARK}"
        )
        run_quiet(
            f"iptables -t mangle -A PREROUTING -m mark --mark {MARK} -p {proto} "
            f"-j TPROXY --on-port {TPROXY_PORT} --tproxy-mark {MARK}"
        )



def stop_perapp():
    """Remove cgroup iptables rules."""
    run_quiet(f"iptables -t mangle -D OUTPUT -m cgroup --path {CGROUP} -j MARK --set-mark {MARK}")
    for proto in ("tcp", "udp"):
        run_quiet(
            f"iptables -t mangle -D PREROUTING -m mark --mark {MARK} -p {proto} "
            f"-j TPROXY --on-port {TPROXY_PORT} --tproxy-mark {MARK}"
        )
    run_quiet(f"ip rule del fwmark {MARK} table {TABLE}")
    run_quiet(f"ip route del local 0.0.0.0/0 dev lo table {TABLE}")


# --- Apply modes ---

def apply_modes(modes):
    """Apply the given mode configuration. Returns (success, message)."""
    old_modes = get_active_modes()
    save_modes(modes)

    messages = []

    # Rebuild xray config with correct inbounds
    _rebuild_xray_inbounds(modes)
    _restart_xray()
    time.sleep(0.5)

    # TUN
    if modes.get("tun") and not old_modes.get("tun"):
        ok, msg = start_tun()
        messages.append(msg)
        if not ok:
            modes["tun"] = False
            save_modes(modes)
    elif not modes.get("tun") and old_modes.get("tun"):
        stop_tun()
        messages.append("TUN выключен")

    # Per-app
    if modes.get("perapp") and not old_modes.get("perapp"):
        start_perapp()
        messages.append("Per-app включён")
    elif not modes.get("perapp") and old_modes.get("perapp"):
        stop_perapp()
        messages.append("Per-app выключен")

    # SOCKS5 and HTTP are just inbounds in xray — no extra setup needed
    if modes.get("socks5"):
        messages.append(f"SOCKS5 ::{SOCKS_PORT}")
    if modes.get("http"):
        messages.append(f"HTTP ::{HTTP_PORT}")

    return True, " | ".join(messages) if messages else "OK"


def get_mode_info():
    """Return list of mode dicts for TUI display."""
    modes = get_active_modes()
    try:
        tun_available = _find_tun2socks() is not None
    except Exception:
        tun_available = False
    return [
        {
            "id": "tun",
            "name": "TUN (весь трафик)",
            "desc": f"tun2socks → SOCKS5 :{SOCKS_PORT}",
            "active": modes.get("tun", False),
            "exclusive": True,
            "available": tun_available,
        },
        {
            "id": "socks5",
            "name": "SOCKS5 прокси",
            "desc": f"127.0.0.1:{SOCKS_PORT}",
            "active": modes.get("socks5", False),
            "exclusive": False,
            "available": True,
        },
        {
            "id": "http",
            "name": "HTTP прокси",
            "desc": f"127.0.0.1:{HTTP_PORT}",
            "active": modes.get("http", False),
            "exclusive": False,
            "available": True,
        },
        {
            "id": "perapp",
            "name": "Per-app (выбор приложений)",
            "desc": "cgroup + tproxy + dokodemo-door",
            "active": modes.get("perapp", True),
            "exclusive": False,
            "available": True,
        },
    ]
