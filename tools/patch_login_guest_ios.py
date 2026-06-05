#!/usr/bin/env python3
"""iOS guest login bytecode patch (run on Mac CI with luajit -bl validate)."""
from patch_login_guest import (
    BC_ADDVN,
    BC_KPRI,
    BC_KSHORT,
    BC_SUBVN,
    apply_proto_words,
    decode_ins,
    encode_ad,
    encode_ins,
    iter_proto_words,
    patch_ctor_spread_knum,
)

SPREAD_REG = 6
POS_Y_REG = 7
BUTTON_Y = 200
SPREAD_IDX = 0
AGREEMENT_HIDE_Y = -1000
IOS_AGREEMENT_Y_WORDS = (142, 159, 186, 211)
IOS_FAST_BTN_VISIBLE_WORD = 288


def find_button_blocks(words):
    blocks = []
    for i, word in enumerate(words):
        op, a, b, c = decode_ins(word)
        if op not in (BC_ADDVN, BC_SUBVN) or a != SPREAD_REG:
            continue
        if i + 1 >= len(words):
            continue
        nxt = decode_ins(words[i + 1])
        if nxt[0] != BC_KSHORT or nxt[1] != POS_Y_REG:
            continue
        y = (words[i + 1] >> 16) & 0xFFFF
        if y > 32767:
            y -= 65536
        if y != BUTTON_Y:
            continue
        blocks.append(i)
    if len(blocks) < 2:
        raise ValueError("iOS login button blocks not found")
    return blocks[-2], blocks[-1]


def apply_patch(data):
    if data[4] != 0x08:
        raise ValueError("not iOS bytecode (flag 0x%02x)" % data[4])
    data = bytearray(data)
    patch_ctor_spread_knum(data)
    for proto in iter_proto_words(data):
        if proto["firstline"] != 32:
            continue
        words = proto["words"]
        for y_word in IOS_AGREEMENT_Y_WORDS:
            op, a, b, c = decode_ins(words[y_word])
            if op != BC_KSHORT:
                raise ValueError("bad agreement insn word %d op=%d" % (y_word, op))
            words[y_word] = encode_ad(BC_KSHORT, a, AGREEMENT_HIDE_Y)
        login_i, fast_i = find_button_blocks(words)
        words[login_i] = encode_ins(BC_ADDVN, SPREAD_REG, SPREAD_REG, SPREAD_IDX)
        words[fast_i] = encode_ins(BC_SUBVN, SPREAD_REG, SPREAD_REG, SPREAD_IDX)
        words[login_i + 1] = encode_ad(BC_KSHORT, POS_Y_REG, BUTTON_Y)
        words[fast_i + 1] = encode_ad(BC_KSHORT, POS_Y_REG, BUTTON_Y)
        words[IOS_FAST_BTN_VISIBLE_WORD] = encode_ad(BC_KPRI, SPREAD_REG, 2)
        apply_proto_words(data, proto["bc_off"], words)
    return bytes(data)
