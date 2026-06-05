#!/usr/bin/env bash
# Build macOS host LuaJIT; run from src/ for -b (0x08 bytecode on Apple Silicon).
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=luajit_sim_env.sh
source "$SCRIPT_DIR/luajit_sim_env.sh"

LJ_DIR="$ROOT/.luajit-src"
LUAJIT="$LJ_DIR/src/luajit"

smoke_test() {
  run_luajit -v
  cat > /tmp/lj_smoke.lua <<'EOF'
LbShopLayer = class("LbShopLayer", function() return display.newNode() end)
function LbShopLayer:ctor() end
EOF
  run_luajit -b -s /tmp/lj_smoke.lua /tmp/lj_smoke.bc
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

export LJ_DIR="$LJ_DIR"

if [ -x "$LUAJIT" ]; then
  echo "found existing luajit, smoke test..."
  if smoke_test; then
    write_luajit_env_file "$ROOT" "$LJ_DIR"
    echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
    [ -n "${GITHUB_ENV:-}" ] && echo "LJ_DIR=$LJ_DIR" >> "$GITHUB_ENV"
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

echo "building macOS host LuaJIT (-j1)..."
make -j1 HOST_CC="clang -arch arm64"

file "$LUAJIT"
smoke_test

write_luajit_env_file "$ROOT" "$LJ_DIR"
echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "LJ_DIR=$LJ_DIR" >> "$GITHUB_ENV"
fi
echo "macOS host LuaJIT ready: $LUAJIT"
