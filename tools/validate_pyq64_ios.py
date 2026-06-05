#!/usr/bin/env python3
"""Validate iOS pyq64.zip bytecode integrity (supports 6-tier LbShopLayer)."""
import sys
import zipfile
from pathlib import Path

LBSHOP = "app.module.lobby.view.layer.LbShopLayer"


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
                errors.append("%s: bad arch flag 0x%02x (need 0x08)" % (name, data[4]))

        lb = z.read(LBSHOP)
        if lb[4] != 0x08:
            errors.append("%s: not iOS FR2 header" % LBSHOP)
        if len(lb) == 4196 and lb[5:8] == b"\x00\x00\x01":
            errors.append(
                "%s: looks like Linux/Android stripped bytecode (4196 bytes)" % LBSHOP
            )
        if b"UIListView" in lb and b"mallPayCashier" not in lb:
            errors.append("%s: old 3-tier UIListView shop without H5 cashier" % LBSHOP)
        if b"mallPayCashier" in lb and b"payBtnClick" not in lb:
            errors.append("%s: mallPayCashier present but payBtnClick missing" % LBSHOP)
        if b"mallPayCashier" in lb and len(lb) == 4196:
            errors.append("%s: mallPayCashier in Android-sized bytecode" % LBSHOP)

        main = z.read("main")
        if main[4] != 0x08:
            errors.append("main: not iOS bytecode")

    if errors:
        for e in errors:
            print("FAIL:", e)
        return 1
    print("OK:", path, "(%d files)" % len(names))
    print("  LbShopLayer:", len(lb), "bytes, flag 0x%02x" % lb[4])
    if b"mallPayCashier" in lb:
        print("  mode: 6-tier H5 cashier (Android parity)")
    elif b"reqPayHttp" in lb:
        print("  mode: legacy 3-tier + reqPayHttp")
    return 0


if __name__ == "__main__":
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/pyq64.zip")
    raise SystemExit(validate(path))
