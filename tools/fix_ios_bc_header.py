#!/usr/bin/env python3
"""Normalize LuaJIT bytecode header to match native iOS modules (1b4c4a02 08)."""
import argparse
import sys
from pathlib import Path

# Native iOS modules in pyq64_base.zip use: 1b 4c 4a 02 08 ...
IOS_VER = 0x02
IOS_FLAG = 0x08
STRIP_FLAG = 0x02


def normalize(data: bytearray, name: str) -> str:
    if len(data) < 6 or data[:3] != b"\x1bLJ":
        raise ValueError("%s: not LuaJIT bytecode" % name)
    if data[3] != IOS_VER:
        raise ValueError("%s: version byte 0x%02x (need 0x%02x)" % (name, data[3], IOS_VER))

    flag = data[4]
    if flag == IOS_FLAG:
        return "ok"
    if flag == (IOS_FLAG | STRIP_FLAG):
        data[4] = IOS_FLAG
        return "fixed_strip_flag_0x0a_to_0x08"
    if flag == STRIP_FLAG:
        raise ValueError(
            "%s: flag 0x02 looks like Linux/Android bytecode (use Mac luajit -bg)"
            % name
        )
    raise ValueError("%s: unfixable flag 0x%02x (need 0x%02x)" % (name, flag, IOS_FLAG))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path", type=Path)
    ap.add_argument("--in-place", action="store_true", default=True)
    args = ap.parse_args()
    data = bytearray(args.path.read_bytes())
    result = normalize(data, args.path.name)
    if result != "ok":
        args.path.write_bytes(data)
        print("%s: %s" % (args.path, result))
    else:
        print("%s: header ok (%s)" % (args.path, data[:6].hex()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
