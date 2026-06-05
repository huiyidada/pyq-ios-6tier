#!/usr/bin/env python3
"""Apply iOS-native bytecode patches (guest login + room player counts)."""
import argparse
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from patch_hf_player_num import apply_patch as patch_hf
from patch_login_guest_ios import apply_patch as patch_login
from patch_sss_player_num import apply_patch as patch_sss

MODULES = {
    "login": ("app.scenes.LoginScene", patch_login),
    "hf": ("app.module.lobby.view.createRoom.HFCreateRoomLayer", patch_hf),
    "sss": ("app.module.lobby.view.createRoom.CreateRoomLayer_Sss", patch_sss),
}


def validate_mac_luajit(path, luajit):
    try:
        subprocess.check_output([luajit, "-bl", str(path)], stderr=subprocess.STDOUT)
        return True
    except subprocess.CalledProcessError as exc:
        msg = exc.output.decode("utf-8", "replace").strip().splitlines()
        print("luajit -bl failed:", msg[-1] if msg else exc)
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", type=Path, required=True)
    ap.add_argument("--luajit", default="luajit")
    ap.add_argument("--only", choices=list(MODULES.keys()), action="append")
    args = ap.parse_args()

    keys = args.only or list(MODULES.keys())
    for key in keys:
        module, fn = MODULES[key]
        path = args.work / module
        if not path.is_file():
            print("skip missing", module)
            continue
        src = path.read_bytes()
        if src[4] != 0x08:
            raise SystemExit("%s: not iOS bytecode" % module)
        backup = path.with_suffix(path.suffix + ".bak_ios")
        if not backup.exists():
            backup.write_bytes(src)
        patched = fn(src)
        path.write_bytes(patched)
        print("patched", module, len(src), "->", len(patched))
        if not validate_mac_luajit(path, args.luajit):
            backup.replace(path)
            raise SystemExit("rejected patch for %s" % module)
        print("validated", module, "with luajit -bl")


if __name__ == "__main__":
    main()
