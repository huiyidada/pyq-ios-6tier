#!/usr/bin/env bash
# Run luajit on macOS CI (host build preferred; simulator fallback needs dyld_sim).

setup_luajit_sim_env() {
  export SIMSYS="${SIMSYS:-$(xcrun --sdk iphonesimulator --show-sdk-path)}"
  export SDKROOT="$SIMSYS"
  export DYLD_ROOT_PATH="$SIMSYS"
  export DYLD_LIBRARY_PATH="${SIMSYS}/usr/lib:${SIMSYS}/System/Library/Frameworks"
}

run_luajit() {
  local bin="$1"
  shift
  # Host macOS luajit: run directly (no DYLD_ROOT_PATH).
  if file "$bin" | grep -q "macOS"; then
    "$bin" "$@"
    return
  fi
  # iOS-simulator binary fallback.
  setup_luajit_sim_env
  local dyld_sim
  dyld_sim="$(xcrun --sdk iphonesimulator --find dyld_sim 2>/dev/null || true)"
  if [ -n "$dyld_sim" ] && [ -x "$dyld_sim" ]; then
    "$dyld_sim" "$bin" "$@"
  else
    "$bin" "$@"
  fi
}

write_luajit_env_file() {
  local root="$1"
  local bin="$2"
  cat > "$root/.luajit_env" <<EOF
LUAJIT_IOS=$bin
LUAJIT_MODE=host
EOF
}
