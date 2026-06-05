#!/usr/bin/env bash
# Build LuaJIT for iOS on GitHub Actions macOS runner.
set -euo pipefail

LJ_TAG="${LUAJIT_TAG:-v2.1.0-beta3}"
ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
LJ_DIR="$ROOT/.luajit-src"

if [ ! -d "$LJ_DIR/.git" ]; then
  git clone --depth 1 --branch "$LJ_TAG" https://github.com/LuaJIT/LuaJIT.git "$LJ_DIR"
fi

cd "$LJ_DIR"
make clean >/dev/null 2>&1 || true

DEVSYS="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "iOS SDK: $DEVSYS"

make -j1 \
  TARGET_SYS=iOS \
  TARGET_FLAGS="-arch arm64 -isysroot $DEVSYS -miphoneos-version-min=9.0 -Os"

LUAJIT="$LJ_DIR/src/luajit"
"$LUAJIT" -v

cat > /tmp/lj_smoke.lua <<'EOF'
LbShopLayer = class("LbShopLayer", function() return display.newNode() end)
function LbShopLayer:ctor() end
EOF

"$LUAJIT" -b -s /tmp/lj_smoke.lua /tmp/lj_smoke.bc
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

echo "LUAJIT_IOS=$LUAJIT" >> "${GITHUB_ENV:-/dev/null}"
echo "$LUAJIT" > "$ROOT/.luajit_ios_path"
echo "LuaJIT iOS build ready: $LUAJIT"
