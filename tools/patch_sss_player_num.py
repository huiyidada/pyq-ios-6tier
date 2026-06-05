#!/usr/bin/env python3
"""CreateRoomLayer_Sss player count patch."""
SSS6_NUM_BYTE_PATCHES = [
    (0x4B5, 2), (0x4B7, 4), (0x4B9, 6), (0x4BB, 4),
    (0xDD2, 2), (0xDD4, 4), (0xDD6, 6), (0xDD8, 4),
]


def build_word5_replacement():
    def kgc_str(text):
        raw = text.encode("utf-8")
        return bytes([5 + len(raw)]) + raw
    old = b"".join(kgc_str(s) for s in ["6人", "5人", "4人", "3人", "2人"])
    new = b"".join(kgc_str(s) for s in ["2人", "4人", "6人", "7人", "8人"])
    return old, new


def build_newsss_num_replacement():
    old = bytes.fromhex("01070000030803060305030403030302")
    new = bytes.fromhex("01070000030803020304030603070308")
    return old, new


def build_sss6_word_replacement():
    old = bytes.fromhex("010400000934e4baba0933e4baba0932e4baba")
    new = bytes.fromhex("010400000932e4baba0934e4baba0936e4baba")
    return old, new


def apply_patch(data):
    if data[4] != 0x08:
        raise ValueError("not iOS bytecode")
    data = bytearray(data)
    for old, new in (build_word5_replacement(), build_newsss_num_replacement(), build_sss6_word_replacement()):
        if data.count(old) == 0:
            raise ValueError("missing pattern %s" % old[:8].hex())
        data = bytearray(data.replace(old, new))
    for offset, value in SSS6_NUM_BYTE_PATCHES:
        data[offset] = value
    return bytes(data)
