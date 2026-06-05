#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=luajit_sim_env.sh
source "$SCRIPT_DIR/luajit_sim_env.sh"
cd "$ROOT"

if [ -f "$ROOT/.luajit_env" ]; then
  # shellcheck disable=SC1091
  source "$ROOT/.luajit_env"
elif [ -f "$ROOT/.luajit_ios_path" ]; then
  LUAJIT="$(cat "$ROOT/.luajit_ios_path")"
  write_luajit_env_file "$ROOT" "$LUAJIT"
  # shellcheck disable=SC1091
  source "$ROOT/.luajit_env"
elif [ -n "${LUAJIT_IOS:-}" ]; then
  write_luajit_env_file "$ROOT" "$LUAJIT_IOS"
  # shellcheck disable=SC1091
  source "$ROOT/.luajit_env"
else
  echo "LUAJIT_IOS not set; run build_luajit_ios.sh first"
  exit 1
fi

mkdir -p build dist reports

echo "=== compile LbShopLayer.lua ==="
echo "DYLD_ROOT_PATH=$DYLD_ROOT_PATH"
run_luajit "$LUAJIT_IOS" -b -s client/LbShopLayer.lua build/LbShopLayer

{
  echo "luajit -v:"
  run_luajit "$LUAJIT_IOS" -v
  echo
  echo "LbShopLayer size:"
  wc -c build/LbShopLayer
  echo
  echo "header xxd -l 8:"
  xxd -l 8 build/LbShopLayer
  echo
  echo "key strings:"
  strings build/LbShopLayer | grep -E "mallPayCashier|payBtnClick|shop_btn_diamond|CONFIG_SHOP" || true
} | tee reports/build_report.txt

python3 - <<'PY'
import sys
d = open("build/LbShopLayer", "rb").read()
if d[4] != 0x08:
    sys.exit("FAIL: LbShopLayer flag 0x%02x" % d[4])
for s in (b"mallPayCashier", b"payBtnClick", b"shop_btn_diamond"):
    if s not in d:
        sys.exit("FAIL: missing " + s.decode())
if len(d) == 4196:
    sys.exit("FAIL: 4196 bytes looks like Android/Linux bytecode")
print("OK: compiled LbShopLayer", len(d), "bytes")
PY

echo "=== pack pyq64.zip ==="
python3 tools/pack_ios_lbshop.py \
  --lbshop build/LbShopLayer \
  --base base/pyq64_base.zip \
  --out dist/pyq64.zip

python3 tools/validate_pyq64_ios.py dist/pyq64.zip | tee -a reports/build_report.txt

cp build/LbShopLayer dist/app.module.lobby.view.layer.LbShopLayer
echo "done: dist/pyq64.zip"
