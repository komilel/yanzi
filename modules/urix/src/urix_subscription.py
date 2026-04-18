"""urix — управление подписками и парсинг VLESS URI."""

import base64
import json
import os
import signal
import subprocess
import sys
import time
from urllib.parse import urlparse, parse_qs, unquote

from urix_config import (
    XRAY_CONFIG, PIDFILE, TPROXY_PORT,
    load_config, save_config,
)


def ping_server(uri):
    """Measure TCP connect time to server from VLESS URI. Returns ms or None."""
    import socket
    parsed = urlparse(uri)
    host = parsed.hostname
    port = parsed.port or 443
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        t0 = time.monotonic()
        sock.connect((host, port))
        ms = (time.monotonic() - t0) * 1000
        sock.close()
        return round(ms)
    except Exception:
        return None


def ping_all_servers(servers, callback=None):
    """Ping all servers. callback(index, ms) called for each result."""
    results = {}
    for i, srv in enumerate(servers):
        ms = ping_server(srv.get("uri", ""))
        results[i] = ms
        if callback:
            callback(i, ms)
    return results


def fetch_subscription(url):
    """Fetch subscription URL, decode base64, return list of {name, uri}."""
    import urllib.request
    resp = urllib.request.urlopen(url, timeout=15)
    raw = resp.read().decode(errors="replace").strip()
    decoded = base64.b64decode(raw).decode(errors="replace").strip()
    servers = []
    for line in decoded.splitlines():
        line = line.strip()
        if not line:
            continue
        name = ""
        if "#" in line:
            name = unquote(line.split("#", 1)[1])
        servers.append({"name": name, "uri": line.split("#")[0]})
    return servers


def parse_vless_uri(uri):
    """Parse vless:// URI into xray outbound config."""
    parsed = urlparse(uri)
    uuid = parsed.username
    address = parsed.hostname
    port = parsed.port or 443
    params = parse_qs(parsed.query)

    def p(key, default=""):
        v = params.get(key, [default])
        return v[0] if v else default

    user = {"id": uuid, "encryption": p("encryption", "none")}
    flow = p("flow")
    if flow:
        user["flow"] = flow

    outbound = {
        "protocol": "vless",
        "settings": {"vnext": [{"address": address, "port": port, "users": [user]}]},
        "streamSettings": {},
    }
    ss = outbound["streamSettings"]
    net = p("type", "tcp")
    ss["network"] = net

    security = p("security")
    if security == "tls":
        ss["security"] = "tls"
        tls = {}
        sni = p("sni")
        if sni:
            tls["serverName"] = sni
        fp = p("fp")
        if fp:
            tls["fingerprint"] = fp
        alpn = p("alpn")
        if alpn:
            tls["alpn"] = alpn.split(",")
        ss["tlsSettings"] = tls
    elif security == "reality":
        ss["security"] = "reality"
        reality = {}
        sni = p("sni")
        if sni:
            reality["serverName"] = sni
        fp = p("fp")
        if fp:
            reality["fingerprint"] = fp
        pbk = p("pbk")
        if pbk:
            reality["publicKey"] = pbk
        sid = p("sid")
        if sid:
            reality["shortId"] = sid
        ss["realitySettings"] = reality

    if net == "xhttp":
        xhttp = {}
        path = p("path")
        if path:
            xhttp["path"] = path
        host = p("host")
        if host:
            xhttp["host"] = host
        mode = p("mode")
        if mode:
            xhttp["mode"] = mode
        extra = p("extra")
        if extra:
            try:
                xhttp["extra"] = json.loads(extra)
            except json.JSONDecodeError:
                pass
        ss["xhttpSettings"] = xhttp
    elif net == "ws":
        ws = {}
        path = p("path")
        if path:
            ws["path"] = path
        host = p("host")
        if host:
            ws["headers"] = {"Host": host}
        ss["wsSettings"] = ws
    elif net == "grpc":
        grpc = {}
        sn = p("serviceName")
        if sn:
            grpc["serviceName"] = sn
        ss["grpcSettings"] = grpc

    return outbound


def generate_xray_config(outbound):
    """Generate full xray.json with the given outbound."""
    return {
        "inbounds": [
            {
                "tag": "tproxy-in",
                "port": int(TPROXY_PORT),
                "protocol": "dokodemo-door",
                "settings": {"network": "tcp,udp", "followRedirect": True},
                "streamSettings": {"sockopt": {"tproxy": "tproxy"}},
            }
        ],
        "outbounds": [outbound],
    }


def apply_server(index):
    """Switch to server at given index, regenerate xray.json, restart xray."""
    cfg = load_config()
    servers = cfg.get("servers", [])
    if index < 0 or index >= len(servers):
        print(f"Индекс {index} вне диапазона (0-{len(servers)-1})")
        return False
    srv = servers[index]
    outbound = parse_vless_uri(srv["uri"])
    xray_cfg = generate_xray_config(outbound)
    with open(XRAY_CONFIG, "w") as f:
        json.dump(xray_cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    cfg["active_server"] = index
    save_config(cfg)
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
    print(f"Переключено на: {srv.get('name', '?')} (PID {proc.pid})")
    return True



def load_subscription(url):
    """Fetch subscription and save to config. Returns server list."""
    servers = fetch_subscription(url)
    if servers:
        cfg = load_config()
        cfg["subscription_url"] = url
        cfg["servers"] = servers
        save_config(cfg)
    return servers


def update_subscription():
    """Re-fetch from saved URL. Returns server list or None."""
    cfg = load_config()
    url = cfg.get("subscription_url")
    if not url:
        return None
    return load_subscription(url)
