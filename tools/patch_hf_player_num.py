#!/usr/bin/env python3
"""HFCreateRoomLayer player counts {6,7,8} -> {2,4,6,7,8}."""
from patch_login_guest import collect_protos, uleb128_write

OLD_TABLE = bytes.fromhex("01040000030603070308")
NEW_TABLE = bytes.fromhex("0106000003020304030603070308")


def find_proto(protos, offset):
    for proto in protos:
        if proto["bs"] <= offset < proto["be"]:
            return proto
    raise ValueError("offset not in proto")


def apply_patch(data):
    if data[4] != 0x08:
        raise ValueError("not iOS bytecode")
    data = bytearray(data)
    offsets = []
    idx = 0
    while True:
        hit = data.find(OLD_TABLE, idx)
        if hit < 0:
            break
        offsets.append(hit)
        idx = hit + 1
    if len(offsets) != 3:
        raise ValueError("expected 3 playerNum tables, found %d" % len(offsets))
    protos = collect_protos(data)
    growth = len(NEW_TABLE) - len(OLD_TABLE)
    for off in sorted(offsets, reverse=True):
        data[off : off + len(OLD_TABLE)] = NEW_TABLE
        proto = find_proto(protos, off)
        new_plen = proto["plen"] + growth
        old_enc = uleb128_write(proto["plen"])
        new_enc = uleb128_write(new_plen)
        if len(old_enc) != len(new_enc):
            raise ValueError("proto uleb size changed")
        data[proto["ps"] : proto["ps"] + len(old_enc)] = new_enc
        proto["plen"] = new_plen
        proto["be"] += growth
        mod = protos.index(proto)
        for later in protos[mod + 1 :]:
            later["ps"] += growth
            later["bs"] += growth
            later["be"] += growth
    if data.count(NEW_TABLE) != 3:
        raise ValueError("patch count mismatch")
    return bytes(data)
