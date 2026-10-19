#!/usr/bin/env bash
set -euo pipefail

# Keep stock Weylus's configuration untouched.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/weylus-pipewire"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/weylus-pipewire"
umask 077
mkdir -p "$XDG_CONFIG_HOME" "$state_dir"

access_code_file="$state_dir/access-code"
if [[ -n "${WEYLUS_ACCESS_CODE:-}" ]]; then
    access_code="$WEYLUS_ACCESS_CODE"
else
    if [[ ! -s "$access_code_file" ]]; then
        od -An -N16 -tx1 /dev/urandom | tr -d ' \n' > "$access_code_file"
    fi
    chmod 600 "$access_code_file"
    access_code=$(<"$access_code_file")
fi

bind_address="${WEYLUS_BIND_ADDRESS:-}"
if [[ -z "$bind_address" ]]; then
    if ! bind_address=$(tailscale ip -4); then
        printf 'No Tailscale address available; connect Tailscale or set WEYLUS_BIND_ADDRESS.\n' >&2
        exit 1
    fi
fi
if [[ -z "$bind_address" ]]; then
    printf 'No bind address available.\n' >&2
    exit 1
fi
web_port="${WEYLUS_WEB_PORT:-1702}"
url_host="$bind_address"
if [[ "$bind_address" == *:* ]]; then
    url_host="[$bind_address]"
fi

export WEYLUS_LOG_LEVEL="${WEYLUS_LOG_LEVEL:-DEBUG}"
export WEYLUS_VAAPI_DEVICE="${WEYLUS_VAAPI_DEVICE:-/dev/dri/renderD128}"
export WEYLUS_VAAPI_DRM_NODE="${WEYLUS_VAAPI_DRM_NODE:-$WEYLUS_VAAPI_DEVICE}"
export GST_DEBUG="${GST_DEBUG:-2}"
export GST_DEBUG_NO_COLOR=1

printf 'Tablet URL: http://%s:%s/?access_code=%s\n' "$url_host" "$web_port" "$access_code"
exec @weylus@ \
    --no-gui \
    --wayland-support \
    --pipewire-pipeline dmabuf \
    --try-vaapi \
    --bind-address "$bind_address" \
    --web-port "$web_port" \
    --access-code "$access_code" \
    "$@"
