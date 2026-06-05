#!/usr/bin/env bash
# Run uninstalled LuaJIT from its src/ directory (needs jit/*.lua modules).

write_luajit_env_file() {
  local root="$1"
  local lj_dir="$2"
  cat > "$root/.luajit_env" <<EOF
LJ_DIR=$lj_dir
LUAJIT_IOS=$lj_dir/src/luajit
EOF
}

run_luajit() {
  local lj_dir="${LJ_DIR:?LJ_DIR not set}"
  local bin="$lj_dir/src/luajit"
  if [ ! -x "$bin" ]; then
    echo "missing luajit binary: $bin"
    exit 1
  fi
  # Uninstalled build: must run inside src/ so jit.bcsave loads.
  (cd "$lj_dir/src" && ./luajit "$@")
}
