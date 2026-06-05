#!/usr/bin/env bash
# Build macOS host LuaJIT on Apple Silicon runner -> iOS-compatible 0x08 bytecode (FR2).
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=luajit_sim_env.sh
source "$SCRIPT_DIR/luajit_sim_env.sh"

LJ_DIR="$ROOT/.luajit-src"
LUAJIT="$LJ_DIR/src/luajit"

smoke_test() {
  local bin="$1"
  run_luajit "$bin" -v
  cat > /tmp/lj_smoke.lua <<'EOF'
LbShopLayer = class("LbShopLayer", function() return display.newNode() end)
function LbShopLayer:ctor() end
EOF
  run_luajit "$bin" -b -s /tmp/lj_smoke.lua /tmp/lj_smoke.bc
  echo "smoke test header:"
  xxd -l 8 /tmp/lj_smoke.bc
  python3 - <<'PY'
import sys
d = open("/tmp/lj_smoke.bc", "rb").read()
if d[4] != 0x08:
    print("FAIL: bytecode flag is 0x%02x, need 0x08" % d[4])
    sys.exit(1)
print("OK: bytecode flag 0x08 (iOS FR2)")
PY
}

if [ -x "$LUAJIT" ]; then
  echo "found existing luajit, smoke test..."
  if smoke_test "$LUAJIT"; then
    write_luajit_env_file "$ROOT" "$LUAJIT"
    echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
    [ -n "${GITHUB_ENV:-}" ] && echo "LUAJIT_IOS=$LUAJIT" >> "$GITHUB_ENV"
    echo "reuse: $LUAJIT"
    exit 0
  fi
  echo "cached binary failed, rebuilding..."
fi

if [ ! -d "$LJ_DIR/.git" ]; then
  git clone https://github.com/LuaJIT/LuaJIT.git "$LJ_DIR"
fi

cd "$LJ_DIR"
git fetch --tags --depth 1 2>/dev/null || true
git checkout v2.1.0-beta3 2>/dev/null || git checkout "$(git rev-list -n 1 v2.1.0-beta3)"

make clean >/dev/null 2>&1 || true
unset DYLD_ROOT_PATH SDKROOT IPHONEOS_DEPLOYMENT_TARGET

echo "building macOS host LuaJIT (-j1) for arm64 FR2 bytecode..."
make -j1 HOST_CC="clang -arch arm64"

file "$LUAJIT"
smoke_test "$LUAJIT"

write_luajit_env_file "$ROOT" "$LUAJIT"
echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
[ -n "${GITHUB_ENV:-}" ] && echo "LUAJIT_IOS=$LUAJIT" >> "$GITHUB_ENV"
echo "macOS host LuaJIT ready: $LUAJIT"
