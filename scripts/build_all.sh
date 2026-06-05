#!/usr/bin/env bash
# One-shot: build LuaJIT, compile 6-tier LbShopLayer, pack pyq64.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=luajit_sim_env.sh
source "$SCRIPT_DIR/luajit_sim_env.sh"
cd "$ROOT"

LJ_DIR="$ROOT/.luajit-src"
LUAJIT="$LJ_DIR/src/luajit"
export LJ_DIR

mkdir -p build dist reports

echo "========== 1/4 Build macOS host LuaJIT =========="
if [ ! -x "$LUAJIT" ]; then
  if [ ! -d "$LJ_DIR/.git" ]; then
    git clone https://github.com/LuaJIT/LuaJIT.git "$LJ_DIR"
  fi
  cd "$LJ_DIR"
  git fetch --tags --depth 1 2>/dev/null || true
  git checkout v2.1.0-beta3 2>/dev/null || git checkout "$(git rev-list -n 1 v2.1.0-beta3)"
  make clean >/dev/null 2>&1 || true
  unset DYLD_ROOT_PATH SDKROOT IPHONEOS_DEPLOYMENT_TARGET
  echo "make -j1 HOST_CC=clang -arch arm64"
  make -j1 HOST_CC="clang -arch arm64"
  cd "$ROOT"
fi
file "$LUAJIT"
run_luajit -v

echo "========== 2/4 Compile LbShopLayer (-bg, NOT -b alone) =========="
# CRITICAL: luajit -b defaults to STRIP -> flag 0x0a (0x08|0x02). iOS needs 0x08 -> use -bg.
run_luajit -bg "$ROOT/client/LbShopLayer.lua" "$ROOT/build/LbShopLayer"
xxd -l 8 build/LbShopLayer | tee reports/header_before_fix.txt

python3 "$ROOT/tools/fix_ios_bc_header.py" build/LbShopLayer
xxd -l 8 build/LbShopLayer | tee reports/header_after_fix.txt

python3 - <<'PY'
import sys
d = open("build/LbShopLayer", "rb").read()
print("header:", " ".join("%02x" % b for b in d[:6]))
if d[4] != 0x08:
    sys.exit("FAIL: flag 0x%02x" % d[4])
for s in (b"mallPayCashier", b"payBtnClick", b"shop_btn_diamond"):
    if s not in d:
        sys.exit("FAIL: missing " + s.decode())
if len(d) == 4196:
    sys.exit("FAIL: 4196 bytes = Linux/Android layout")
print("OK: LbShopLayer", len(d), "bytes, flag 0x08")
PY

{
  echo "luajit -v:"; run_luajit -v
  echo; echo "LbShopLayer:"; wc -c build/LbShopLayer
  echo; echo "header:"; xxd -l 8 build/LbShopLayer
  echo; strings build/LbShopLayer | grep -E "mallPayCashier|payBtnClick|shop_btn_diamond" || true
} | tee reports/build_report.txt

echo "========== 3/4 Pack pyq64.zip =========="
python3 tools/pack_ios_lbshop.py \
  --lbshop build/LbShopLayer \
  --base base/pyq64_base.zip \
  --out dist/pyq64.zip

echo "========== 4/4 Validate =========="
python3 tools/validate_pyq64_ios.py dist/pyq64.zip | tee -a reports/build_report.txt
cp build/LbShopLayer dist/app.module.lobby.view.layer.LbShopLayer
echo "DONE: dist/pyq64.zip"
