#!/usr/bin/env bash
# Build LuaJIT for iOS simulator on macOS runner (can execute locally, emits iOS 0x08 bc).
set -euo pipefail

LJ_TAG="${LUAJIT_TAG:-v2.1.0-beta3}"
ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
LJ_DIR="$ROOT/.luajit-src"
LUAJIT="$LJ_DIR/src/luajit"

smoke_test() {
  local bin="$1"
  "$bin" -v
  cat > /tmp/lj_smoke.lua <<'EOF'
LbShopLayer = class("LbShopLayer", function() return display.newNode() end)
function LbShopLayer:ctor() end
EOF
  "$bin" -b -s /tmp/lj_smoke.lua /tmp/lj_smoke.bc
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
    echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
    [ -n "${GITHUB_ENV:-}" ] && echo "LUAJIT_IOS=$LUAJIT" >> "$GITHUB_ENV"
    exit 0
  fi
  echo "cached luajit failed smoke test, rebuilding..."
fi

if [ ! -d "$LJ_DIR/.git" ]; then
  git clone --depth 1 --branch "$LJ_TAG" https://github.com/LuaJIT/LuaJIT.git "$LJ_DIR"
fi

cd "$LJ_DIR"
make clean >/dev/null 2>&1 || true

# iphonesimulator: runs on GitHub macOS ARM runner; iphoneos binary cannot run (exit 137).
SIMSYS="$(xcrun --sdk iphonesimulator --show-sdk-path)"
echo "iOS Simulator SDK: $SIMSYS"
echo "building LuaJIT (-j1, simulator)..."

make -j1 \
  TARGET_SYS=iOS \
  TARGET_FLAGS="-arch arm64 -isysroot $SIMSYS -mios-simulator-version-min=9.0 -Os"

file "$LUAJIT"
smoke_test "$LUAJIT"

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "LUAJIT_IOS=$LUAJIT" >> "$GITHUB_ENV"
fi
echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
echo "LuaJIT iOS simulator build ready: $LUAJIT"
