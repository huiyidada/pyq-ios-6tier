#!/usr/bin/env bash
# Mac CI: compile 6-tier LbShopLayer + bytecode patch login/HF/SSS on iOS native base
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=luajit_sim_env.sh
source "$SCRIPT_DIR/luajit_sim_env.sh"
cd "$ROOT"

LJ_DIR="$ROOT/.luajit-src"
LUAJIT="$LJ_DIR/src/luajit"
export LJ_DIR

mkdir -p build dist reports work

echo "========== 1/6 Build macOS host LuaJIT =========="
if [ ! -x "$LUAJIT" ]; then
  if [ ! -d "$LJ_DIR/.git" ]; then
    git clone https://github.com/LuaJIT/LuaJIT.git "$LJ_DIR"
  fi
  cd "$LJ_DIR"
  git fetch --tags --depth 1 2>/dev/null || true
  git checkout v2.1.0-beta3 2>/dev/null || true
  make clean >/dev/null 2>&1 || true
  unset DYLD_ROOT_PATH SDKROOT IPHONEOS_DEPLOYMENT_TARGET
  make -j1 HOST_CC="clang -arch arm64"
  cd "$ROOT"
fi
run_luajit -v | tee reports/luajit_version.txt
echo "smoke: luajit -bg from src/ (jit modules)"
cat > /tmp/lj_smoke.lua <<'EOF'
LbShopLayer = class("LbShopLayer", function() return display.newNode() end)
function LbShopLayer:ctor() end
EOF
run_luajit -bg /tmp/lj_smoke.lua /tmp/lj_smoke.bc
python3 "$ROOT/tools/fix_ios_bc_header.py" /tmp/lj_smoke.bc 2>/dev/null || true
python3 - <<'PY'
import sys
d = open("/tmp/lj_smoke.bc", "rb").read()
if d[4] != 0x08:
    sys.exit("FAIL smoke: bytecode flag 0x%02x" % d[4])
print("OK smoke: luajit -bg flag 0x08")
PY

echo "========== 2/6 Extract safe iOS base =========="
rm -rf work
mkdir -p work
unzip -q "$ROOT/base/pyq64_base.zip" -d work
echo "smoke: luajit -bl on base LoginScene"
run_luajit -bl "$ROOT/work/app.scenes.LoginScene" | head -5 | tee reports/login_base_disasm.txt

echo "========== 3/6 Bytecode patch (login + HF + SSS) =========="
python3 "$ROOT/tools/patch_ios_bytecode.py" --work "$ROOT/work" --luajit "$LUAJIT"

echo "========== 4/6 Compile 6-tier LbShopLayer (-bg) =========="
if [ -f "$ROOT/client/LbShopLayer.lua" ]; then
  run_luajit -bg "$ROOT/client/LbShopLayer.lua" "$ROOT/build/LbShopLayer"
  python3 "$ROOT/tools/fix_ios_bc_header.py" "$ROOT/build/LbShopLayer"
  xxd -l 8 build/LbShopLayer | tee reports/header_LbShopLayer.txt
  python3 - <<PY
import sys
d = open("$ROOT/build/LbShopLayer", "rb").read()
if d[4] != 0x08:
    sys.exit("FAIL LbShopLayer flag 0x%02x" % d[4])
for s in (b"mallPayCashier", b"payBtnClick"):
    if s not in d:
        sys.exit("FAIL missing " + s.decode())
print("OK LbShopLayer", len(d), "bytes")
PY
  cp "$ROOT/build/LbShopLayer" "$ROOT/work/app.module.lobby.view.layer.LbShopLayer"
  echo "replaced LbShopLayer in work/"
else
  echo "WARN: client/LbShopLayer.lua missing, keep base shop module"
fi

echo "========== 5/6 Pack pyq64.zip =========="
python3 "$ROOT/tools/pack_ios_modules.py" \
  --base "$ROOT/base/pyq64_base.zip" \
  --out "$ROOT/dist/pyq64.zip" \
  --work "$ROOT/work" \
  --skip-extract

echo "========== 6/6 Validate =========="
python3 "$ROOT/tools/validate_pyq64_ios.py" "$ROOT/dist/pyq64.zip" | tee reports/build_report.txt

cp "$ROOT/work/app.scenes.LoginScene" "$ROOT/dist/app.scenes.LoginScene"
cp "$ROOT/work/app.module.lobby.view.createRoom.HFCreateRoomLayer" "$ROOT/dist/app.module.lobby.view.createRoom.HFCreateRoomLayer"
cp "$ROOT/work/app.module.lobby.view.createRoom.CreateRoomLayer_Sss" "$ROOT/dist/app.module.lobby.view.createRoom.CreateRoomLayer_Sss"
if [ -f "$ROOT/work/app.module.lobby.view.layer.LbShopLayer" ]; then
  cp "$ROOT/work/app.module.lobby.view.layer.LbShopLayer" "$ROOT/dist/app.module.lobby.view.layer.LbShopLayer"
fi

echo "DONE: dist/pyq64.zip ($(wc -c < "$ROOT/dist/pyq64.zip") bytes)"
