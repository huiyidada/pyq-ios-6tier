#!/usr/bin/env bash
# Mac 云端一键：编译 iOS 原生字节码并打包 pyq64.zip
# 必须先有 client_qqdbl 工程里的 .lua 源码（见 client/MAC_COMPILE_README.md）
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

compile_module() {
  local lua_src="$1"
  local out_name="$2"
  local out_path="$ROOT/build/$out_name"
  if [ ! -f "$lua_src" ]; then
    echo "SKIP: missing $lua_src"
    return 1
  fi
  echo "========== Compile $out_name (-bg) =========="
  run_luajit -bg "$lua_src" "$out_path"
  python3 "$ROOT/tools/fix_ios_bc_header.py" "$out_path"
  xxd -l 8 "$out_path" | tee "reports/header_${out_name}.txt"
  python3 - <<PY
import sys
d = open("$out_path", "rb").read()
if d[4] != 0x08:
    sys.exit("FAIL $out_name: flag 0x%02x" % d[4])
print("OK:", "$out_name", len(d), "bytes, flag 0x08")
PY
  echo 0
}

echo "========== 1/5 Build macOS host LuaJIT =========="
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

HAS_LB=0
HAS_LOGIN=0
HAS_HF=0
HAS_SSS=0

if compile_module "$ROOT/client/LbShopLayer.lua" "LbShopLayer"; then HAS_LB=1; fi
if compile_module "$ROOT/client/LoginScene.lua" "LoginScene"; then HAS_LOGIN=1; fi
if compile_module "$ROOT/client/HFCreateRoomLayer.lua" "HFCreateRoomLayer"; then HAS_HF=1; fi
if compile_module "$ROOT/client/CreateRoomLayer_Sss.lua" "CreateRoomLayer_Sss"; then HAS_SSS=1; fi

if [ "$HAS_LB$HAS_LOGIN$HAS_HF$HAS_SSS" = "0000" ]; then
  echo "FAIL: no client/*.lua found. See client/MAC_COMPILE_README.md"
  exit 1
fi

PACK_ARGS=(--base "$ROOT/base/pyq64_base.zip" --out "$ROOT/dist/pyq64.zip")
[ "$HAS_LB" = 1 ] && PACK_ARGS+=(--lbshop "$ROOT/build/LbShopLayer")
[ "$HAS_LOGIN" = 1 ] && PACK_ARGS+=(--login "$ROOT/build/LoginScene")
[ "$HAS_HF" = 1 ] && PACK_ARGS+=(--hfroom "$ROOT/build/HFCreateRoomLayer")
[ "$HAS_SSS" = 1 ] && PACK_ARGS+=(--sssroom "$ROOT/build/CreateRoomLayer_Sss")

echo "========== Pack pyq64.zip =========="
python3 "$ROOT/tools/pack_ios_modules.py" "${PACK_ARGS[@]}"

echo "========== Validate =========="
python3 "$ROOT/tools/validate_pyq64_ios.py" "$ROOT/dist/pyq64.zip" | tee reports/build_report.txt

cp "$ROOT/dist/pyq64.zip" "$ROOT/dist/"
[ "$HAS_LB" = 1 ] && cp "$ROOT/build/LbShopLayer" "$ROOT/dist/app.module.lobby.view.layer.LbShopLayer"
[ "$HAS_LOGIN" = 1 ] && cp "$ROOT/build/LoginScene" "$ROOT/dist/app.scenes.LoginScene"
[ "$HAS_HF" = 1 ] && cp "$ROOT/build/HFCreateRoomLayer" "$ROOT/dist/app.module.lobby.view.createRoom.HFCreateRoomLayer"
[ "$HAS_SSS" = 1 ] && cp "$ROOT/build/CreateRoomLayer_Sss" "$ROOT/dist/app.module.lobby.view.createRoom.CreateRoomLayer_Sss"

echo "DONE: dist/pyq64.zip"
