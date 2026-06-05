#!/usr/bin/env python3
"""Shared LuaJIT bytecode helpers (arch-agnostic)."""
import struct

BC_ADDVN = 22
BC_SUBVN = 23
BC_KSHORT = 41
BC_KPRI = 43
KNUM_250_OFF = 0x9A8
KNUM_250 = bytes.fromhex("f403")


def uleb128_read(data, pos):
    value = shift = 0
    while pos < len(data):
        byte = data[pos]
        pos += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, pos
        shift += 7
    raise ValueError("truncated uleb128")


def uleb128_write(value):
    out = []
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            byte |= 0x80
        out.append(byte)
        if not value:
            break
    return bytes(out)


def decode_ins(word):
    op = word & 0xFF
    a = (word >> 8) & 0xFF
    c = (word >> 16) & 0xFF
    b = (word >> 24) & 0xFF
    return op, a, b, c


def encode_ins(op, a=0, b=0, c=0):
    return op | (a << 8) | (b << 24) | (c << 16)


def encode_ad(op, a=0, d=0):
    return op | (a << 8) | ((d & 0xFFFF) << 16)


def collect_protos(data):
    pos = 5
    if not (data[4] & 0x02):
        nlen, pos = uleb128_read(data, pos)
        pos += nlen
    protos = []
    while pos < len(data) - 1:
        plen_start = pos
        plen, pos = uleb128_read(data, pos)
        if plen == 0:
            break
        body_start = pos
        body_end = body_start + plen
        protos.append({"ps": plen_start, "plen": plen, "bs": body_start, "be": body_end})
        pos = body_end
    return protos


def insert_bytes(data, offset, extra):
    data[offset:offset] = extra
    growth = len(extra)
    for proto in collect_protos(data):
        if proto["ps"] >= offset:
            proto["ps"] += growth
        if proto["bs"] >= offset:
            proto["bs"] += growth
        if proto["be"] > offset:
            proto["be"] += growth
            new_plen = proto["plen"] + growth
            old_enc = uleb128_write(proto["plen"])
            new_enc = uleb128_write(new_plen)
            if len(old_enc) != len(new_enc):
                raise ValueError("proto length encoding size changed")
            data[proto["ps"] : proto["ps"] + len(old_enc)] = new_enc
            proto["plen"] = new_plen


def iter_proto_words(data):
    pos = 5
    if not (data[4] & 0x02):
        nlen, pos = uleb128_read(data, pos)
        pos += nlen
    while pos < len(data) - 1:
        plen, pos = uleb128_read(data, pos)
        if plen == 0:
            break
        bs = pos
        p = bs + 4
        _, p = uleb128_read(data, p)
        _, p = uleb128_read(data, p)
        sizebc, p = uleb128_read(data, p)
        sizebc += 1
        sizedbg, p = uleb128_read(data, p)
        firstline = 0
        if sizedbg:
            firstline, p = uleb128_read(data, p)
            _, p = uleb128_read(data, p)
        bc_off = p
        words = [struct.unpack_from("<I", data, bc_off + i * 4)[0] for i in range(sizebc)]
        yield {"firstline": firstline, "bc_off": bc_off, "words": words}
        pos = bs + plen


def apply_proto_words(data, bc_off, words):
    for i, word in enumerate(words):
        struct.pack_into("<I", data, bc_off + i * 4, word)


def patch_ctor_spread_knum(data):
    if data[KNUM_250_OFF] != 0xA0:
        raise ValueError("unexpected knum byte at %#x: %#x" % (KNUM_250_OFF, data[KNUM_250_OFF]))
    insert_bytes(data, KNUM_250_OFF + 1, b"\x00")
    data[KNUM_250_OFF : KNUM_250_OFF + len(KNUM_250)] = KNUM_250
