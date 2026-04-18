import sys, json, os
from urllib.parse import parse_qs, unquote

outdir = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else None
source = sys.argv[3] if len(sys.argv) > 3 else None

os.makedirs(outdir, exist_ok=True)

data = None
servers = None

if mode == "--json":
    with open(source) as f:
        data = json.load(f)
elif mode == "--url":
    with open(source) as f:
        sub_url = f.read().strip()
    import urllib.request

    resp = urllib.request.urlopen(sub_url)
    data = json.loads(resp.read())
else:
    with open(os.path.join(outdir, "servers.json")) as f:
        servers = json.load(f)

if data:
    if not data.get("isFound") or not data.get("links"):
        print("Subscription invalid or expired!")
        sys.exit(1)

    user = data.get("user", {})
    print(
        f"Account: {user.get('username', '?')} | "
        f"Days left: {user.get('daysLeft', '?')} | "
        f"Traffic: {user.get('trafficUsed', '?')}"
    )

    servers = []
    for line in data["links"]:
        line = line.strip()
        if not line.startswith("vless://"):
            continue

        without_scheme = line[len("vless://") :]
        main, _, fragment = without_scheme.partition("#")
        name = unquote(fragment) if fragment else "unnamed"
        userinfo, _, hostpart = main.partition("@")
        uuid = userinfo
        hostport, _, query_str = hostpart.partition("?")

        if ":" in hostport.rsplit(":", 1)[-1]:
            host, _, port_s = hostport.rpartition(":")
            port = int(port_s) if port_s else 443
        else:
            host = hostport
            port = 443

        params = parse_qs(query_str)
        p = lambda k, d="": params.get(k, [d])[0]

        net = p("type", "tcp")
        sec = p("security", "none")
        short_host = host.split(".")[0][:10]
        tag = f"{len(servers)+1}-{short_host}-{net}-{sec}"
        # e.g. "1-de-server-tcp-reality", "3-nl-server-xhttp-tls"

        outbound = {
            "tag": tag,
            "protocol": "vless",
            "settings": {
                "vnext": [
                    {
                        "address": host,
                        "port": port,
                        "users": [{"id": uuid, "encryption": p("encryption", "none")}],
                    }
                ]
            },
            "streamSettings": {"network": p("type", "tcp")},
        }

        user_cfg = outbound["settings"]["vnext"][0]["users"][0]
        stream = outbound["streamSettings"]

        flow = p("flow")
        if flow:
            user_cfg["flow"] = flow

        net = p("type", "tcp")
        if net == "xhttp":
            s = {}
            if p("path"):
                s["path"] = p("path")
            if p("mode"):
                s["mode"] = p("mode")
            stream["xhttpSettings"] = s
        elif net == "ws":
            s = {}
            if p("path"):
                s["path"] = p("path")
            if p("host"):
                s["headers"] = {"Host": p("host")}
            stream["wsSettings"] = s
        elif net == "grpc":
            s = {}
            if p("serviceName"):
                s["serviceName"] = p("serviceName")
            stream["grpcSettings"] = s
        elif net in ("tcp", "raw"):
            stream["network"] = "tcp"

        sec = p("security", "none")
        stream["security"] = sec
        if sec == "tls":
            tls = {}
            if p("sni"):
                tls["serverName"] = p("sni")
            if p("fp"):
                tls["fingerprint"] = p("fp")
            if p("alpn"):
                tls["alpn"] = p("alpn").split(",")
            stream["tlsSettings"] = tls
        elif sec == "reality":
            r = {}
            if p("sni"):
                r["serverName"] = p("sni")
            if p("fp"):
                r["fingerprint"] = p("fp")
            if p("pbk"):
                r["publicKey"] = p("pbk")
            if p("sid"):
                r["shortId"] = p("sid")
            if p("spx"):
                r["spiderX"] = p("spx")
            stream["realitySettings"] = r

        servers.append(outbound)

    if not servers:
        print("No vless links found!")
        sys.exit(1)

    with open(os.path.join(outdir, "servers.json"), "w") as f:
        json.dump(servers, f, indent=2)

# determine active
active_file = os.path.join(outdir, "active-outbound")
if os.path.exists(active_file):
    with open(active_file) as f:
        active_tag = f.read().strip()
    if not any(s["tag"] == active_tag for s in servers):
        active_tag = servers[0]["tag"]
else:
    active_tag = servers[0]["tag"]

config = {
    "inbounds": [
        {
            "tag": "tproxy-in",
            "port": 12345,
            "protocol": "dokodemo-door",
            "settings": {"network": "tcp,udp", "followRedirect": True},
            "streamSettings": {"sockopt": {"tproxy": "tproxy"}},
        },
        {
            "tag": "socks-in",
            "port": 20170,
            "protocol": "socks",
            "settings": {"auth": "noauth", "udp": True},
        },
        {"tag": "http-in", "port": 20171, "protocol": "http", "settings": {}},
    ],
    "outbounds": servers + [{"tag": "direct", "protocol": "freedom"}],
    "routing": {
        "rules": [
            {"type": "field", "ip": ["geoip:private"], "outboundTag": "direct"},
            {
                "type": "field",
                "inboundTag": ["tproxy-in", "socks-in", "http-in"],
                "outboundTag": active_tag,
            },
        ]
    },
}

with open(os.path.join(outdir, "runtime-config.json"), "w") as f:
    json.dump(config, f, indent=2)

print(f"\n{len(servers)} servers:")
for s in servers:
    marker = " *" if s["tag"] == active_tag else ""
    net = s["streamSettings"].get("network", "?")
    sec = s["streamSettings"].get("security", "?")
    print(f"  {s['tag']} [{net}+{sec}]{marker}")
