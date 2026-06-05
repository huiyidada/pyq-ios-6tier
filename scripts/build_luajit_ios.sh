#!/usr/bin/env bash
# Build LuaJIT for iOS simulator; run with DYLD_ROOT_PATH only AFTER build.
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
    print("FAIL: iOS bytecode flag is 0x%02x, need 0x08" % d[4])
    sys.exit(1)
print("OK: iOS bytecode flag 0x08")
PY
}

if [ -x "$LUAJIT" ]; then
  echo "found existing luajit, running smoke test..."
  if smoke_test "$LUAJIT"; then
    echo "reuse cached luajit: $LUAJIT"
    write_luajit_env_file "$ROOT" "$LUAJIT"
    echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
    if [ -n "${GITHUB_ENV:-}" ]; then
      setup_luajit_sim_env
      echo "LUAJIT_IOS=$LUAJIT" >> "$GITHUB_ENV"
      echo "DYLD_ROOT_PATH=$DYLD_ROOT_PATH" >> "$GITHUB_ENV"
      echo "SDKROOT=$SDKROOT" >> "$GITHUB_ENV"
    fi
    exit 0
  fi
  echo "cached luajit failed smoke test, rebuilding..."
fi

if [ ! -d "$LJ_DIR/.git" ]; then
  git clone https://github.com/LuaJIT/LuaJIT.git "$LJ_DIR"
fi

cd "$LJ_DIR"
git fetch --tags --depth 1 2>/dev/null || true
git checkout v2.1.0-beta3 2>/dev/null || git checkout "$(git rev-list -n 1 v2.1.0-beta3)"

make clean >/dev/null 2>&1 || true

SIMSYS="$(xcrun --sdk iphonesimulator --show-sdk-path)"
echo "iOS Simulator SDK: $SIMSYS"

# CRITICAL: do NOT set DYLD_ROOT_PATH during make — breaks host buildvm (dyld_sim error).
unset DYLD_ROOT_PATH
unset SDKROOT
unset IPHONEOS_DEPLOYMENT_TARGET

echo "building LuaJIT (-j1, simulator target)..."

make -j1 \
  HOST_CC="clang -arch arm64" \
  TARGET_SYS=iOS \
  TARGET_FLAGS="-arch arm64 -isysroot $SIMSYS -mios-simulator-version-min=12.0 -Os"

file "$LUAJIT"
smoke_test "$LUAJIT"

write_luajit_env_file "$ROOT" "$LUAJIT"
echo "$LUAJIT" > "$ROOT/.luajit_ios_path"

if [ -n "${GITHUB_ENV:-}" ]; then
  setup_luajit_sim_env
  echo "LUAJIT_IOS=$LUAJIT" >> "$GITHUB_ENV"
  echo "DYLD_ROOT_PATH=$DYLD_ROOT_PATH" >> "$GITHUB_ENV"
  echo "SDKROOT=$SDKROOT" >> "$GITHUB_ENV"
fi
echo "LuaJIT iOS simulator build ready: $LUAJIT"
