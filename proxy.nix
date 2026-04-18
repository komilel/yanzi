{pkgs, ...}: let
  parseScript = ./proxy/parse-sub.py;

  updateScript = pkgs.writeShellScriptBin "tunnel-update" ''
    set -euo pipefail
    SUB_FILE="''${1:-$HOME/personal/sub}"

    if [ -f "$SUB_FILE" ] && head -c1 "$SUB_FILE" | grep -q '{'; then
      # it's already JSON, use directly
      sudo ${pkgs.python3}/bin/python3 ${parseScript} /etc/xray --json "$SUB_FILE"
    elif [ -f "$SUB_FILE" ]; then
      # it's a URL, fetch it
      sudo ${pkgs.python3}/bin/python3 ${parseScript} /etc/xray --url "$SUB_FILE"
    else
      echo "No file found: $SUB_FILE"
      echo "Either put subscription JSON in ~/personal/sub"
      echo "or put the subscription URL in ~/personal/sub"
      exit 1
    fi
    sudo systemctl restart xray
  '';

  tunnelScript = pkgs.writeShellScriptBin "tunnel" ''
    CONF_DIR="/etc/xray"
    SERVERS="$CONF_DIR/servers.json"
    ACTIVE_FILE="$CONF_DIR/active-outbound"

    case "''${1:-}" in
      list)
        if [ ! -f "$SERVERS" ]; then
          echo "No servers. Run 'tunnel-update' first."
          exit 1
        fi
        if systemctl is-active --quiet xray; then
          echo "xray: running"
        else
          echo "xray: NOT running"
        fi
        ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "")
        ${pkgs.jq}/bin/jq -r --arg active "$ACTIVE" \
          '.[] | .tag as $t | "\(if $t == $active then "* " else "  " end)\($t) [\(.streamSettings.network)+\(.streamSettings.security)]"' \
          "$SERVERS"
        ;;
      *)
        if [ ! -f "$SERVERS" ]; then
          echo "No servers. Run 'tunnel-update' first."
          exit 1
        fi
        if ! ${pkgs.jq}/bin/jq -e --arg t "$1" '.[] | select(.tag == $t)' "$SERVERS" > /dev/null 2>&1; then
          echo "Unknown server: $1"
          echo "Run 'tunnel list' to see available."
          exit 1
        fi
        echo "$1" | sudo tee "$ACTIVE_FILE" > /dev/null
        sudo ${pkgs.python3}/bin/python3 ${parseScript} /etc/xray
        sudo systemctl restart xray
        echo "Switched to $1"
        ;;
    esac
  '';
in {
  environment.systemPackages = [updateScript tunnelScript];

  systemd.services.xray = {
    description = "Xray proxy";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.xray}/bin/xray run -c /etc/xray/runtime-config.json";
      AmbientCapabilities = "CAP_NET_ADMIN";
      CapabilityBoundingSet = "CAP_NET_ADMIN";
    };
  };
}
