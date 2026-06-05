#!/usr/bin/env bash
# Run iOS-simulator luajit on macOS host (needs DYLD_ROOT_PATH).
setup_luajit_sim_env() {
  export SIMSYS="${SIMSYS:-$(xcrun --sdk iphonesimulator --show-sdk-path)}"
  export SDKROOT="$SIMSYS"
  export DYLD_ROOT_PATH="$SIMSYS"
}

run_luajit() {
  local bin="$1"
  shift
  setup_luajit_sim_env
  "$bin" "$@"
}

write_luajit_env_file() {
  local root="$1"
  local bin="$2"
  setup_luajit_sim_env
  cat > "$root/.luajit_env" <<EOF
LUAJIT_IOS=$bin
SIMSYS=$SIMSYS
SDKROOT=$SIMSYS
DYLD_ROOT_PATH=$SIMSYS
EOF
}
