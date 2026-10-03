#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"
test=${1:-smoke}
case "$test" in
  smoke) ;;
  dap)
    if ! command -v dotnet >/dev/null || ! command -v cc >/dev/null; then
      exec nix-shell -p dotnet-sdk_10 gcc --run "bash '$root/nvim/tests/smoke.sh' dap"
    fi
    ;;
  *) printf 'Usage: bash nvim/tests/smoke.sh [smoke|dap]\n' >&2; exit 2 ;;
esac
# A path source also includes newly added runtime modules before they are staged.
package=$(nix build "path:$root#nixosConfigurations.Niko.config.programs.nvf.finalPackage" --no-write-lock-file --no-link --print-out-paths)
tmp=$(mktemp -d)
cleanup() {
  local status=$?
  if ((status == 0)); then
    rm -rf -- "$tmp"
  else
    printf 'Test failed; isolated files and DAP logs retained at %s\n' "$tmp" >&2
  fi
}
trap cleanup EXIT
export NVIM_AUDIT_TMP="$tmp"
export NVIM_AUDIT_TEST="$root/nvim/tests/$test.lua"
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_CACHE_HOME="$tmp/cache"
export XDG_STATE_HOME="$tmp/state"
export XDG_DATA_HOME="$tmp/data"
mkdir -p "$HOME"
# Discord presence requires a real UI and must not connect during headless tests.
timeout 240s "$package/bin/nvim" --headless -i NONE \
  --cmd 'lua package.preload["neocord"] = function() return { setup = function() end } end' \
  -c 'lua dofile(vim.env.NVIM_AUDIT_TEST)'
