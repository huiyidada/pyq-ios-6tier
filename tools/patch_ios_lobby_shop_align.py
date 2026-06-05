#!/usr/bin/env python3
"""Skip shopLayer:align(CENTER, cx, cy) in iOS LobbyBattleView (flag 0x08).

Android uses patch_lobby_shop_align.py on the same logical bytecode. iOS FR2
cannot be disassembled by Linux luajit -bl, so we locate the align call chain
by pattern and replace it with JMPs to the original fall-through target.
"""
import struct
import sys
from pathlib import Path

BC_MOV = 0x12
BC_TGETS = 0x39
BC_CALL = 0x42
BC_JMP = 0x58
ALIGN_KIDX = 0x0C  # TGETS "align" in openShop proto (luajit -bl)


def find_shop_align_offset(data):
    n = len(data) // 4
    words = [struct.unpack_from("<I", data, i * 4)[0] for i in range(n)]
    hits = []
    for i in range(n - 10):
        if (words[i] & 0xFF) != BC_MOV:
            continue
        w1 = words[i + 1]
        if (w1 & 0xFF) != BC_TGETS:
            continue
        if ((w1 >> 16) & 0xFF) != ALIGN_KIDX:
            continue
        if (words[i + 8] & 0xFF) != BC_CALL:
            continue
        if (words[i + 9] & 0xFF) != BC_JMP:
            continue
        hits.append(i * 4)
    if len(hits) != 1:
        raise ValueError(
            "expected 1 shop align chain, found %d at %s" % (len(hits), hits)
        )
    return hits[0]


def patch_shop_align(data):
    off = find_shop_align_offset(data)
    if off is None:
        raise ValueError("shop align pattern not found in LobbyBattleView")

    insns = [struct.unpack_from("<I", data, off + k * 4)[0] for k in range(10)]
    jmp = insns[9]
    a = (jmp >> 8) & 0xFF
    d = jmp >> 16
    if d & 0x8000:
        d -= 0x10000
    target_idx = 9 + d + 1

    out = bytearray(data)
    for j in range(9):
        rel = target_idx - j - 1
        patched = BC_JMP | (a << 8) | ((rel & 0xFFFF) << 16)
        struct.pack_into("<I", out, off + j * 4, patched)
    return out, off


def main():
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "app.module.lobby.view.LobbyBattleView")
    data = path.read_bytes()
    if data[:3] != b"\x1bLJ" or data[4] != 0x08:
        raise SystemExit("%s: expected iOS bytecode flag 0x08" % path)
    patched, off = patch_shop_align(data)
    path.write_bytes(patched)
    print("patched shop align at byte offset %d" % off)


if __name__ == "__main__":
    main()
