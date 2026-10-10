#!/usr/bin/bash
set -euo pipefail

font_config=${1:?Missing WeChat font configuration}
shift

if [[ ! -x /opt/wechat/wechat ]]; then
  printf >&2 'Arch WeChat is missing: install wechat-bin inside the arch Distrobox.\n'
  exit 1
fi
if [[ ! -r "$font_config" ]]; then
  printf >&2 'Cannot read WeChat font configuration: %s\n' "$font_config"
  exit 1
fi
if [[ -z ${WAYLAND_DISPLAY:-} || -z ${XDG_RUNTIME_DIR:-} ]]; then
  printf >&2 'Start wechat-arch from your Wayland desktop session.\n'
  exit 1
fi
wayland_socket=$WAYLAND_DISPLAY
if [[ "$wayland_socket" != /* ]]; then
  wayland_socket="$XDG_RUNTIME_DIR/$wayland_socket"
fi
if [[ ! -S "$wayland_socket" ]]; then
  printf >&2 'Wayland socket is unavailable inside Arch: %s\n' "$wayland_socket"
  exit 1
fi

# Old containers do not have the newer /run/zed-ca mount. Preserve TLS verification.
ca_bundle=${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}
if [[ ! -r "$ca_bundle" ]]; then
  if [[ "$ca_bundle" == /* && -r "/run/host$ca_bundle" ]]; then
    ca_bundle="/run/host$ca_bundle"
  else
    ca_bundle=/etc/ssl/certs/ca-certificates.crt
  fi
fi
if [[ ! -r "$ca_bundle" ]]; then
  printf >&2 'No readable CA certificate bundle found inside Arch.\n'
  exit 1
fi

# An allowlist avoids Nix Qt/GTK plugins, library paths, locale archives, and API
# credentials leaking into the vendor binary. Keep desktop integration and proxies.
clean_env=(
  "PATH=/usr/local/bin:/usr/bin:/bin"
  "HOME=$HOME"
  "USER=${USER:-komi}"
  "LOGNAME=${LOGNAME:-komi}"
  "LANG=${LANG:-en_US.UTF-8}"
  "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
  "XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}"
  "XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}"
  "XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}"
  "XDG_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}"
  "XDG_DATA_DIRS=/usr/local/share:/usr/share"
  "XDG_CONFIG_DIRS=/etc/xdg"
  "XDG_SESSION_TYPE=wayland"
  "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
  "DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
  "QT_QPA_PLATFORM=wayland"
  "GDK_BACKEND=wayland"
  "FONTCONFIG_FILE=$font_config"
  "FONTCONFIG_PATH=/etc/fonts"
  "SSL_CERT_FILE=$ca_bundle"
)
for variable in HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY http_proxy https_proxy all_proxy no_proxy \
  LC_ALL LC_CTYPE LC_MESSAGES XDG_CURRENT_DESKTOP XDG_ACTIVATION_TOKEN \
  XMODIFIERS XCURSOR_THEME XCURSOR_SIZE; do
  if [[ -v "$variable" ]]; then
    clean_env+=("$variable=${!variable}")
  fi
done

if [[ ${1:-} == --check ]]; then
  # Probe variables expand in the child shell, after the environment is cleaned.
  # shellcheck disable=SC2016
  exec /usr/bin/env -i "${clean_env[@]}" /usr/bin/bash -c '
    set -euo pipefail
    /usr/bin/pacman -Q wechat-bin noto-fonts noto-fonts-cjk noto-fonts-emoji
    printf "Binary: /opt/wechat/wechat\nPlatform: %s\nCA bundle: %s\n" "$QT_QPA_PLATFORM" "$SSL_CERT_FILE"
    for pattern in "sans-serif" "sans-serif:charset=4e2d" "emoji:charset=1f600"; do
      printf "Font [%s]: " "$pattern"
      /usr/bin/fc-match -f "%{family} (%{file})\n" "$pattern"
    done
    # Windows-style font requests and bogus families must still get CJK glyphs.
    for family in sans-serif "Microsoft YaHei" "Segoe UI" Xiomara; do
      match=$(/usr/bin/fc-match -f "%{family}" "$family:charset=4e2d")
      [[ "$match" == "Noto Sans CJK SC" ]] || { printf >&2 "Unexpected CJK fallback: %s\n" "$match"; exit 1; }
    done
    [[ $(/usr/bin/fc-match -f "%{family}" sans-serif) == "Noto Sans" ]]
    [[ $(/usr/bin/fc-match -f "%{family}" "emoji:charset=1f600") == "Noto Color Emoji" ]]
    [[ -z ${QT_PLUGIN_PATH+x} && -z ${LD_LIBRARY_PATH+x} && -z ${DISPLAY+x} ]]
    printf "WeChat Arch checks passed; no application launched.\n"
  '
fi

exec /usr/bin/env -i "${clean_env[@]}" /opt/wechat/wechat "$@"
