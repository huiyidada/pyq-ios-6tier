#!/usr/bin/env python3
"""Pack Mac-built / patched iOS modules into pyq64.zip."""
import argparse
import shutil
import zipfile
from pathlib import Path

WELCOME = "app.scenes.WelcomeScene"
LBVIEW = "app.module.lobby.view.LobbyBattleView"
HTOOLS = "app.util.HttpTools"
OLD_AUTH = b"121.204.249.235"
NEW_AUTH = b"12345.nikyou.cn"
GOLD_OFF = 1510


def assert_ios(data, name):
    if data[:3] != b"\x1bLJ" or data[4] != 0x08:
        flag = data[4] if len(data) > 4 else -1
        raise ValueError("%s: not iOS bytecode (flag 0x%02x)" % (name, flag))


def patch_welcome(data):
    if NEW_AUTH in data:
        return
    if OLD_AUTH not in data:
        raise ValueError("%s: auth host missing" % WELCOME)
    data[:] = data.replace(OLD_AUTH, NEW_AUTH)


def patch_gold(data):
    if data[GOLD_OFF : GOLD_OFF + 7] == b"goldNum":
        return
    if data[GOLD_OFF : GOLD_OFF + 7] != b"cardNum":
        raise ValueError("%s: cardNum not at offset %d" % (LBVIEW, GOLD_OFF))
    data[GOLD_OFF : GOLD_OFF + 7] = b"goldNum"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--work", type=Path, default=Path("/tmp/pack_ios_work"))
    ap.add_argument("--skip-extract", action="store_true")
    ap.add_argument("--lbshop", type=Path, default=None)
    args = ap.parse_args()

    if not args.skip_extract:
        if args.work.exists():
            shutil.rmtree(args.work)
        args.work.mkdir(parents=True)
        with zipfile.ZipFile(args.base, "r") as zin:
            zin.extractall(args.work)

    for name, patchfn in ((WELCOME, patch_welcome), (LBVIEW, patch_gold)):
        path = args.work / name
        data = bytearray(path.read_bytes())
        assert_ios(data, name)
        patchfn(data)
        path.write_bytes(data)
        print("patched", name)

    if args.lbshop and args.lbshop.is_file():
        payload = args.lbshop.read_bytes()
        assert_ios(payload, "LbShopLayer")
        (args.work / "app.module.lobby.view.layer.LbShopLayer").write_bytes(payload)
        print("replaced LbShopLayer ->", len(payload), "bytes")

    ht = (args.work / HTOOLS).read_bytes()
    assert_ios(ht, HTOOLS)
    if b"103.217.187.82" not in ht:
        raise ValueError("%s: missing server IP" % HTOOLS)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    files = sorted(f for f in args.work.iterdir() if f.is_file())
    with zipfile.ZipFile(args.out, "w", zipfile.ZIP_DEFLATED) as zout:
        for f in files:
            zout.writestr(f.name, f.read_bytes())
    print("wrote %s (%d files, %d bytes)" % (args.out, len(files), args.out.stat().st_size))


if __name__ == "__main__":
    main()
