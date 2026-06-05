#!/usr/bin/env python3
"""Validate iOS pyq64.zip bytecode integrity."""
import sys
import zipfile
from pathlib import Path

LBSHOP = "app.module.lobby.view.layer.LbShopLayer"
LOGIN = "app.scenes.LoginScene"
HF = "app.module.lobby.view.createRoom.HFCreateRoomLayer"


def validate(path: Path) -> int:
    errors = []
    with zipfile.ZipFile(path, "r") as z:
        names = z.namelist()
        if len(names) != len(set(names)):
            errors.append("duplicate zip entries")

        for name in names:
            data = z.read(name)
            if data[:3] != b"\x1bLJ":
                continue
            if data[4] != 0x08:
                errors.append("%s: bad arch flag 0x%02x" % (name, data[4]))

        lb = z.read(LBSHOP)
        if lb[4] != 0x08:
            errors.append("%s: not iOS header" % LBSHOP)
        if len(lb) == 4196 and lb[5:8] == b"\x00\x00\x01":
            errors.append("%s: Linux/Android bytecode" % LBSHOP)
        if b"UIListView" in lb and b"mallPayCashier" not in lb and b"reqPayHttp" not in lb:
            errors.append("%s: old shop without payment" % LBSHOP)
        if b"mallPayCashier" in lb and b"payBtnClick" not in lb:
            errors.append("%s: mallPayCashier without payBtnClick" % LBSHOP)

        login = z.read(LOGIN)
        if login[4] != 0x08:
            errors.append("%s: bad login header" % LOGIN)
        if login[0x9A8 : 0x9AA] != bytes.fromhex("f403"):
            errors.append("%s: guest login knum not patched" % LOGIN)

        hf = z.read(HF)
        new_table = bytes.fromhex("0106000003020304030603070308")
        if hf.count(new_table) != 3:
            errors.append("%s: playerNum tables not patched (count=%d)" % (HF, hf.count(new_table)))

        main = z.read("main")
        if main[4] != 0x08:
            errors.append("main: not iOS bytecode")

    if errors:
        for e in errors:
            print("FAIL:", e)
        return 1

    print("OK:", path, "(%d files)" % len(names))
    print("  LbShopLayer:", len(lb), "bytes")
    print("  LoginScene:", len(login), "bytes (guest login)")
    print("  HFCreateRoomLayer:", len(hf), "bytes (2/4/6/7/8)")
    if b"mallPayCashier" in lb:
        print("  shop: 6-tier H5 cashier")
    elif b"reqPayHttp" in lb:
        print("  shop: legacy + reqPayHttp")
    return 0


if __name__ == "__main__":
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/pyq64.zip")
    raise SystemExit(validate(path))
