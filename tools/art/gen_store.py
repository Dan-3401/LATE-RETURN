"""Convenience store environment art: back wall, tiles, props, foreground."""
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import (Canvas, c, PAL, value_noise, crack, stain, drips, speckle,  # noqa: E402
                    rust_patch, text, preview, TRANSPARENT)

OUT = "environment/store"
WALL_W, WALL_H = 1024, 224

# ---------------------------------------------------------------------------
# Products (tiny front-facing goods used on shelves)
# ---------------------------------------------------------------------------
PRODUCT_COLS = ["red", "yellow", "blue", "paper", "green", "cloth2"]


def can(cv, x, y, rng, lying=False):
    col = rng.choice(PRODUCT_COLS)
    if lying:
        cv.rect(x, y + 3, 8, 5, c("metal", 5))
        cv.rect(x + 2, y + 3, 4, 5, c(col, 3))
        cv.hline(x, y + 3, 8, c("metal", 7))
        cv.vline(x, y + 3, 5, c("metal", 6))
        return 8
    cv.rect(x, y, 5, 8, c(col, 3))
    cv.hline(x, y, 5, c("metal", 7))
    cv.hline(x, y + 7, 5, c("metal", 4))
    cv.vline(x, y + 1, 6, c(col, 4))
    cv.vline(x + 4, y + 1, 6, c(col, 1))
    cv.hline(x + 1, y + 3, 3, c("paper", 5))
    return 5


def bottle(cv, x, y, rng, water=False):
    col = "cold" if water else rng.choice(["green", "blue", "red", "yellow"])
    base = 4 if water else 3
    cv.rect(x, y + 4, 4, 9, c(col, base))
    cv.rect(x + 1, y + 1, 2, 3, c(col, base))
    cv.hline(x + 1, y, 2, c("white", 0) if water else c("red", 3))
    cv.vline(x, y + 5, 7, c(col, base + 1))
    cv.vline(x + 3, y + 5, 7, c(col, base - 2))
    cv.rect(x, y + 7, 4, 3, c("paper", 5) if water else c("paper", 4))
    cv.px(x + 1, y + 8, c("blue", 4) if water else c(col, 2))
    return 4


def box(cv, x, y, w, h, rng):
    col = rng.choice(PRODUCT_COLS)
    cv.rect(x, y, w, h, c(col, 3))
    cv.vline(x, y, h, c(col, 4))
    cv.vline(x + w - 1, y, h, c(col, 1))
    cv.hline(x, y, w, c(col, 5))
    cv.rect(x + 1, y + h // 3, w - 2, max(1, h // 4), c("paper", 5))
    if rng.random() < 0.5:
        cv.px(x + w // 2, y + h // 3 + 1, c(col, 2))
    # dent / torn corner
    if rng.random() < 0.4:
        cv.px(x + w - 1, y, TRANSPARENT)
        cv.px(x + w - 2, y + 1, c(col, 1))
    return w


def bag(cv, x, y, rng):
    col = rng.choice(["red", "yellow", "blue", "green"])
    pts = [(x, y + 1), (x + 8, y), (x + 9, y + 10), (x - 1, y + 10)]
    cv.poly(pts, c(col, 3))
    cv.hline(x, y + 1, 8, c("metal", 7))
    cv.hline(x - 1, y + 9, 10, c("metal", 5))
    cv.rect(x + 2, y + 4, 4, 3, c("paper", 5))
    cv.vline(x + 7, y + 2, 6, c(col, 1))
    cv.px(x + 1, y + 3, c(col, 5))
    return 9


def noodle_cup(cv, x, y, rng):
    col = rng.choice(["red", "yellow"])
    cv.poly([(x, y), (x + 7, y), (x + 6, y + 8), (x + 1, y + 8)], c(col, 3))
    cv.hline(x, y, 7, c("paper", 6))
    cv.rect(x + 2, y + 3, 3, 2, c("paper", 5))
    cv.vline(x + 6, y + 1, 6, c(col, 1))
    return 7


def dust_outline(cv, x, y, w, h):
    """A cleaner rectangle where something used to stand (the rest is dusty)."""
    for xx in range(w):
        cv.darken(x + xx, y + h, -0.0)
    cv.hline(x, y + h - 1, w, c("metal", 4))


# ---------------------------------------------------------------------------
# Shelves
# ---------------------------------------------------------------------------
def shelf(seed, w=64, h=88, broken=False, fill=0.45, sign=None):
    rng = random.Random(seed)
    cv = Canvas(w, h)
    # back panel (pegboard)
    n = value_noise(w, h, 10, seed)
    cv.fill_field(3, 4, w - 6, h - 12, "metal", n[4:h - 8, 3:w - 3], lo=1, hi=3)
    for yy in range(7, h - 12, 4):
        for xx in range(6 + (yy // 4) % 2 * 2, w - 6, 4):
            cv.px(xx, yy, c("metal", 0))
    # uprights
    for ux in (0, w - 4):
        cv.rect(ux, 0, 4, h, c("metal", 4))
        cv.vline(ux, 0, h, c("metal", 6))
        cv.vline(ux + 3, 0, h, c("metal", 2))
        for yy in range(4, h - 8, 5):
            cv.px(ux + 1, yy, c("metal", 1))
            cv.px(ux + 2, yy, c("metal", 1))
        for _ in range(3):
            rust_patch(cv, ux + rng.randint(0, 3), rng.randint(10, h - 5), rng.randint(1, 2), rng)
    # top sign strip
    cv.rect(0, 0, w, 6, c("metal", 3))
    cv.hline(0, 0, w, c("metal", 6))
    cv.hline(0, 5, w, c("metal", 1))
    if sign:
        cv.rect(8, 1, w - 16, 4, c(sign, 2))
        cv.hline(8, 1, w - 16, c(sign, 3))
    # base kick plate
    cv.rect(0, h - 8, w, 8, c("metal", 2))
    cv.hline(0, h - 8, w, c("metal", 5))
    for xx in range(2, w - 2, 3):
        cv.px(xx, h - 3, c("metal", 1))
    # shelf boards
    levels = [18, 38, 58, 76]
    for li, ly in enumerate(levels):
        sag = broken and li == 1
        if sag:
            # broken board hanging diagonally from right upright
            cv.line(w - 5, ly - 2, 6, ly + 12, c("metal", 5), 1)
            cv.line(w - 5, ly - 1, 6, ly + 13, c("metal", 3), 1)
            cv.line(w - 5, ly, 6, ly + 14, c("metal", 2), 1)
            # stuff slid to the floor of the next level
            continue
        cv.rect(3, ly, w - 6, 3, c("metal", 5))
        cv.hline(3, ly, w - 6, c("metal", 7))
        cv.hline(3, ly + 2, w - 6, c("metal", 2))
        # price tag strip
        for tx in range(6, w - 8, rng.choice([9, 11, 13])):
            if rng.random() < 0.6:
                cv.rect(tx, ly + 1, 4, 2, c("yellow", 5) if rng.random() < 0.7 else c("paper", 5))
                cv.px(tx + 1, ly + 1, c("ink", 2))
        # goods on this level
        x = 5
        top = ly - 1
        while x < w - 10:
            r = rng.random()
            if r > fill:
                # empty gap with dust ring
                gap = rng.randint(5, 12)
                if rng.random() < 0.5:
                    cv.hline(x, top, gap - 2, c("metal", 0))
                x += gap
                continue
            kind = rng.random()
            if kind < 0.3:
                ww = can(cv, x, top - 8, rng)
            elif kind < 0.5:
                ww = bottle(cv, x, top - 13, rng)
            elif kind < 0.7:
                bh = rng.randint(8, 13)
                ww = box(cv, x, top - bh, rng.randint(6, 9), bh, rng)
            elif kind < 0.85:
                ww = bag(cv, x + 1, top - 11, rng) + 1
            elif kind < 0.93:
                ww = noodle_cup(cv, x, top - 9, rng)
            else:
                ww = can(cv, x, top - 8, rng, lying=True)
            x += ww + rng.randint(0, 2)
    if broken:
        # goods scattered on the lower board after the break
        for i in range(4):
            can(cv, 10 + i * 9, 57 - 5, rng, lying=True)
    # grime + rust
    for _ in range(6):
        stain(cv, rng.randint(0, w), rng.randint(0, h), rng.randint(3, 8), rng.randint(3, 10), 0.18, rng, rng.randint(0, 999))
    for _ in range(3):
        crack(cv, rng.randint(4, w - 4), rng.randint(h - 8, h - 4), 4, c("metal", 0), rng, 0, diry=-1)
    cv.outline(c("ink", 1))
    return cv


def cooler(seed, open_door=False):
    rng = random.Random(seed)
    w, h = 60, 104
    cv = Canvas(w, h)
    # body
    cv.rect(0, 0, w, h, c("metal", 3))
    cv.vline(0, 0, h, c("metal", 5))
    cv.vline(w - 1, 0, h, c("metal", 1))
    # dead light header
    cv.rect(2, 2, w - 4, 10, c("metal", 1))
    cv.rect(4, 4, w - 8, 6, c("cold", 1))
    for k in range(8, w - 8, 6):
        cv.rect(k, 6, 3, 2, c("cold", 2))
    # doors
    for d in range(2):
        dx = 2 + d * 28
        cv.rect(dx, 14, 27, 80, c("metal", 5))
        cv.rect(dx + 2, 16, 23, 76, c("ink", 2))
        # interior shelves + bottles
        for sy in (34, 54, 74, 90):
            cv.hline(dx + 2, sy, 23, c("metal", 3))
            xx = dx + 3
            while xx < dx + 22:
                if rng.random() < 0.28:
                    bottle(cv, xx, sy - 13, rng, water=rng.random() < 0.6)
                    xx += 5
                else:
                    xx += rng.randint(3, 6)
        # glass: grime gradient + reflection
        for yy in range(16, 92):
            for xx in range(dx + 2, dx + 25):
                t = (yy - 16) / 76.0
                if rng.random() < 0.10 + t * 0.25:
                    cv.tint(xx, yy, c("tile", 3), 0.35)
        for k in range(0, 60):
            rx = dx + 4 + k // 3
            ry = 18 + k
            if ry < 92 and rx < dx + 25:
                cv.tint(rx, ry, c("cold", 5), 0.25)
                cv.tint(rx + 1, ry, c("cold", 5), 0.15)
        # handle
        hx = dx + (23 if d == 0 else 3)
        cv.rect(hx, 44, 1, 20, c("metal", 7))
    # spiderweb crack on right door
    cx, cy = 44, 40
    for a in range(0, 360, 45):
        ln = rng.randint(6, 12)
        for i in range(ln):
            cv.px(int(cx + math.cos(math.radians(a)) * i), int(cy + math.sin(math.radians(a)) * i), c("cold", 5))
    cv.disc(cx, cy, 1, c("white", 0))
    # bottom grill
    cv.rect(2, 95, w - 4, 8, c("metal", 1))
    for xx in range(4, w - 4, 2):
        cv.vline(xx, 96, 6, c("metal", 0))
    for _ in range(4):
        rust_patch(cv, rng.randint(0, w), rng.randint(90, h), 2, rng)
    for _ in range(4):
        stain(cv, rng.randint(0, w), rng.randint(0, h), rng.randint(4, 8), rng.randint(4, 12), 0.15, rng, rng.randint(0, 99))
    # sticker
    cv.rect(8, 80, 6, 5, c("red", 3))
    cv.px(9, 81, c("paper", 6))
    cv.outline(c("ink", 1))
    return cv


def counter(seed):
    rng = random.Random(seed)
    w, h = 100, 44
    cv = Canvas(w, h)
    n = value_noise(w, h, 8, seed)
    cv.fill_field(0, 6, w, h - 6, "wood", n[6:, :], lo=2, hi=4)
    # laminate top
    cv.rect(0, 0, w, 6, c("concrete", 5))
    cv.hline(0, 0, w, c("concrete", 7))
    cv.hline(0, 5, w, c("concrete", 2))
    # front panels
    for px_ in range(4, w - 4, 24):
        cv.rect(px_, 10, 20, h - 16, c("wood", 3))
        cv.hline(px_, 10, 20, c("wood", 1))
        cv.vline(px_, 10, h - 16, c("wood", 1))
        cv.hline(px_, h - 7, 20, c("wood", 5))
    # kick
    cv.rect(0, h - 4, w, 4, c("ink", 2))
    # stickers / posters on the counter
    cv.rect(30, 14, 10, 12, c("yellow", 4))
    cv.rect(31, 16, 8, 3, c("red", 3))
    cv.rect(31, 21, 8, 1, c("ink", 2))
    cv.rect(71, 14, 14, 13, c("paper", 5))
    text(cv, 72, 14, "烟", c("red", 3), 12)
    # scratches / chips
    for _ in range(18):
        x = rng.randint(2, w - 3)
        y = rng.randint(8, h - 6)
        cv.line(x, y, x + rng.randint(-3, 3), y + rng.randint(1, 3), c("wood", 1))
    for _ in range(6):
        stain(cv, rng.randint(0, w), rng.randint(6, h), rng.randint(4, 10), rng.randint(3, 6), 0.2, rng, rng.randint(0, 99))
    # a torn corner of laminate
    cv.rect(w - 14, 0, 6, 2, c("wood", 2))
    # candy rack on top left
    cv.rect(4, -0, 0, 0, c("metal", 3))
    cv.outline(c("ink", 1))
    return cv


def register(opened=False):
    w, h = 30, 22
    cv = Canvas(w, h)
    # body
    cv.poly([(2, 8), (26, 8), (28, 18), (1, 18)], c("concrete", 4))
    cv.hline(2, 8, 24, c("concrete", 6))
    # screen
    cv.rect(16, 1, 10, 7, c("concrete", 3))
    cv.rect(17, 2, 8, 4, c("green", 0))
    cv.px(18, 3, c("green", 2))
    cv.vline(20, 6, 3, c("concrete", 2))
    # keys
    for ky in range(10, 15, 2):
        for kx in range(4, 14, 2):
            cv.px(kx, ky, c("concrete", 6))
    # drawer
    if opened:
        cv.rect(0, 18, 30, 4, c("concrete", 2))
        cv.hline(0, 18, 30, c("concrete", 5))
        for kx in range(3, 27, 5):
            cv.rect(kx, 19, 3, 2, c("ink", 1))
    else:
        cv.rect(1, 18, 28, 4, c("concrete", 3))
        cv.hline(1, 18, 28, c("concrete", 5))
        cv.px(14, 20, c("metal", 7))
    cv.outline(c("ink", 1))
    return cv


def magazine_rack(seed):
    rng = random.Random(seed)
    w, h = 34, 48
    cv = Canvas(w, h)
    cv.rect(0, 0, 2, h, c("metal", 4))
    cv.rect(w - 2, 0, 2, h, c("metal", 3))
    for i, ly in enumerate([12, 26, 40]):
        cv.hline(0, ly, w, c("metal", 6))
        cv.hline(0, ly + 1, w, c("metal", 2))
        xx = 3
        while xx < w - 6:
            if rng.random() < 0.6:
                col = rng.choice(PRODUCT_COLS)
                mh = rng.randint(8, 11)
                tilt = rng.choice([0, 0, 1])
                cv.poly([(xx + tilt, ly - mh), (xx + 6 + tilt, ly - mh), (xx + 6, ly), (xx, ly)], c(col, 3))
                cv.hline(xx + tilt + 1, ly - mh + 2, 4, c("paper", 5))
                cv.px(xx + 2, ly - mh + 5, c(col, 5))
            xx += 7
    # torn paper hanging
    cv.poly([(20, 27), (27, 27), (25, 36), (21, 34)], c("paper", 4))
    cv.outline(c("ink", 1))
    return cv


def fallen_shelf(seed):
    rng = random.Random(seed)
    w, h = 86, 30
    cv = Canvas(w, h)
    # tipped gondola lying diagonally against the floor, top toward the right
    cv.poly([(2, h - 2), (10, h - 12), (84, 8), (80, h - 2)], c("metal", 3))
    cv.line(2, h - 3, 84, 8, c("metal", 6))
    cv.line(10, h - 12, 84, 7, c("metal", 5))
    for i in range(5):
        x = 16 + i * 14
        cv.line(x, h - 3, x + 4, int(h - 12 - (x - 10) * 0.2), c("metal", 1))
    cv.rect(0, h - 3, w - 4, 3, c("metal", 2))
    # spilled goods
    for i in range(6):
        can(cv, rng.randint(4, w - 12), h - 8, rng, lying=True)
    for _ in range(3):
        rust_patch(cv, rng.randint(10, 70), rng.randint(10, 25), 2, rng)
    cv.outline(c("ink", 1))
    return cv


def boxes_stack(seed):
    rng = random.Random(seed)
    w, h = 36, 34
    cv = Canvas(w, h)

    def cbox(x, y, bw, bh, open_top=False):
        cv.rect(x, y, bw, bh, c("wood", 4))
        cv.vline(x, y, bh, c("wood", 5))
        cv.vline(x + bw - 1, y, bh, c("wood", 2))
        cv.hline(x, y, bw, c("wood", 6))
        cv.hline(x, y + bh - 1, bw, c("wood", 2))
        cv.rect(x + bw // 2 - 2, y, 4, bh // 2, c("paper", 3))  # tape
        cv.rect(x + 3, y + bh - 8, 6, 4, c("paper", 4))  # label
        cv.hline(x + 4, y + bh - 7, 4, c("ink", 2))
        if open_top:
            cv.poly([(x, y), (x - 3, y - 4), (x + 6, y - 3)], c("wood", 5))
        for _ in range(3):
            stain(cv, x + rng.randint(0, bw), y + rng.randint(0, bh), 3, 3, 0.2, rng, rng.randint(0, 99))

    cbox(0, 14, 20, 20)
    cbox(19, 18, 17, 16)
    cbox(5, 1, 16, 14, open_top=True)
    cv.outline(c("ink", 1))
    return cv


def trash(seed, kind):
    rng = random.Random(seed)
    if kind == "pile":
        w, h = 40, 16
        cv = Canvas(w, h)
        # papers, cans, crushed boxes, bag
        cv.poly([(0, h), (8, 7), (18, 4), (30, 6), (40, h)], c("concrete", 2))
        for _ in range(9):
            x = rng.randint(2, w - 10)
            y = rng.randint(5, h - 4)
            k = rng.random()
            if k < 0.35:
                cv.poly([(x, y), (x + rng.randint(5, 9), y - 1), (x + rng.randint(5, 9), y + 3), (x, y + 3)], c("paper", rng.randint(3, 5)))
            elif k < 0.6:
                can(cv, x, y - 3, rng, lying=True)
            elif k < 0.8:
                cv.rect(x, y, 7, 4, c("wood", 4))
                cv.hline(x, y, 7, c("wood", 5))
            else:
                cv.disc(x + 3, y + 1, 3, c("concrete", 1))
                cv.px(x + 2, y, c("concrete", 4))
        cv.outline(c("ink", 1))
        return cv
    if kind == "bag":
        w, h = 18, 16
        cv = Canvas(w, h)
        cv.ellipse(9, 10, 8, 6, c("ink", 2))
        cv.ellipse(8, 9, 6, 4, c("concrete", 1))
        cv.px(6, 7, c("concrete", 4))
        cv.px(7, 6, c("concrete", 3))
        cv.line(9, 3, 11, 5, c("concrete", 2))
        cv.line(12, 3, 11, 5, c("concrete", 2))
        cv.rect(2, 14, 14, 2, c("ink", 2))
        cv.outline(c("ink", 1))
        return cv
    if kind == "papers":
        w, h = 30, 6
        cv = Canvas(w, h)
        for _ in range(7):
            x = rng.randint(0, w - 8)
            y = rng.randint(1, 4)
            cv.poly([(x, y), (x + 7, y - 1), (x + 8, y + 1), (x + 1, y + 2)], c("paper", rng.randint(2, 5)))
        cv.outline(c("ink", 1))
        return cv
    if kind == "bottles":
        w, h = 22, 12
        cv = Canvas(w, h)
        bottle(cv, 2, 0, rng)
        cv.rect(8, 8, 12, 4, c("green", 2))
        cv.hline(8, 8, 12, c("green", 4))
        cv.px(19, 9, c("green", 5))
        cv.rect(14, 6, 2, 2, c("green", 3))  # shard
        cv.outline(c("ink", 1))
        return cv
    if kind == "basket":
        w, h = 22, 12
        cv = Canvas(w, h)
        cv.poly([(0, 2), (20, 0), (22, 10), (2, 12)], c("red", 3))
        for xx in range(2, 20, 3):
            cv.vline(xx, 3, 8, c("red", 1))
        cv.hline(0, 2, 20, c("red", 5))
        cv.hline(4, -1, 10, c("metal", 4))
        cv.outline(c("ink", 1))
        return cv
    if kind == "wet_sign":
        w, h = 16, 26
        cv = Canvas(w, h)
        cv.poly([(7, 0), (9, 0), (15, 25), (1, 25)], c("yellow", 4))
        cv.line(8, 0, 15, 25, c("yellow", 2))
        cv.rect(5, 8, 6, 5, c("ink", 2))
        cv.px(7, 9, c("yellow", 5))
        cv.px(8, 10, c("yellow", 5))
        cv.rect(3, 17, 10, 2, c("ink", 3))
        cv.outline(c("ink", 1))
        return cv
    raise ValueError(kind)


def ceiling_lamp(broken=True):
    w, h = 40, 30
    cv = Canvas(w, h)
    # chains
    cv.vline(4, 0, 6, c("metal", 3))
    cv.vline(35, 0, 16 if broken else 6, c("metal", 3))
    # fixture hanging at an angle (one chain snapped)
    if broken:
        cv.line(4, 6, 35, 16, c("metal", 5), 1)
        cv.line(4, 7, 35, 17, c("metal", 3), 1)
        cv.line(5, 8, 34, 18, c("metal", 2), 1)
        # dangling tube
        cv.line(30, 18, 33, 29, c("white", 0), 1)
        cv.px(33, 29, c("metal", 5))
        # wires
        cv.line(35, 16, 38, 26, c("ink", 2))
    else:
        cv.rect(2, 6, 36, 3, c("metal", 5))
        cv.rect(4, 9, 32, 2, c("white", 0))
    cv.outline(c("ink", 1))
    return cv


def exit_sign(lit=True):
    w, h = 36, 15
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, c("metal", 2))
    cv.rect(1, 1, w - 2, h - 2, c("green", 3 if lit else 1))
    text(cv, 3, 1, "出口", c("white", 1) if lit else c("green", 2), 12)
    cv.rect(28, 6, 4, 4, c("white", 1) if lit else c("green", 2))
    cv.px(29, 4, c("white", 1) if lit else c("green", 2))
    cv.px(30, 5, c("white", 1) if lit else c("green", 2))
    cv.outline(c("ink", 1))
    return cv


def exit_door(opened=False):
    """Front glass door of the store (the level exit)."""
    rng = random.Random(7)
    w, h = 52, 86
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, c("metal", 4))
    cv.vline(0, 0, h, c("metal", 6))
    cv.vline(w - 1, 0, h, c("metal", 1))
    cv.rect(0, 0, w, 4, c("metal", 3))
    # glass panel showing the night outside
    gx, gy, gw, gh = 4, 6, w - 8, h - 14
    n = value_noise(gw, gh, 12, 3)
    cv.fill_field(gx, gy, gw, gh, "cold", n * 0.5 + np.linspace(0.35, 0, gh)[:, None], lo=0, hi=3)
    # distant silhouettes of buildings through glass
    sx = gx
    while sx < gx + gw:
        bw = rng.randint(4, 9)
        bh = rng.randint(10, 30)
        cv.rect(sx, gy + gh - bh, bw, bh, c("ink", 2))
        sx += bw + rng.randint(0, 2)
    # cardboard taped over lower part
    cv.rect(gx + 2, gy + gh - 22, gw - 6, 18, c("wood", 4))
    cv.hline(gx + 2, gy + gh - 22, gw - 6, c("wood", 5))
    for tx in (gx + 2, gx + gw - 7):
        cv.rect(tx, gy + gh - 24, 4, 3, c("paper", 4))
    text(cv, gx + 4, gy + gh - 19, "营业中", c("red", 2), 12)
    # glass crack + reflection
    crack(cv, gx + gw - 8, gy + 4, 14, c("cold", 5), rng, 0.3)
    for k in range(30):
        cv.tint(gx + 3 + k // 2, gy + 2 + k, c("cold", 6), 0.3)
    # push bar
    cv.rect(4, 44, w - 8, 3, c("metal", 7))
    cv.hline(4, 46, w - 8, c("metal", 3))
    # kick plate
    cv.rect(0, h - 8, w, 8, c("metal", 2))
    for _ in range(4):
        rust_patch(cv, rng.randint(0, w), rng.randint(h - 8, h), 2, rng)
    if opened:
        # door pushed ajar: a bright cold slit on the right side
        cv.rect(w - 10, gy, 6, gh, c("cold", 5))
        cv.vline(w - 11, gy, gh, c("metal", 6))
    cv.outline(c("ink", 1))
    return cv


def storeroom_door():
    rng = random.Random(3)
    w, h = 36, 66
    cv = Canvas(w, h)
    n = value_noise(w, h, 10, 11)
    cv.fill_field(0, 0, w, h, "metal", n, lo=2, hi=4)
    cv.rect(0, 0, w, 2, c("metal", 5))
    cv.vline(0, 0, h, c("metal", 5))
    # the door is ajar: dark gap on the left
    cv.rect(2, 3, 5, h - 3, c("ink", 0))
    cv.vline(7, 3, h - 3, c("metal", 6))
    cv.rect(26, 34, 5, 2, c("metal", 7))  # handle
    cv.rect(8, 10, 26, 14, c("paper", 4))
    text(cv, 9, 11, "仓库", c("ink", 2), 12)
    for _ in range(5):
        rust_patch(cv, rng.randint(0, w), rng.randint(40, h), rng.randint(1, 3), rng)
    for _ in range(3):
        stain(cv, rng.randint(0, w), rng.randint(0, h), 4, 10, 0.2, rng, rng.randint(0, 99))
    cv.outline(c("ink", 1))
    return cv


# ---------------------------------------------------------------------------
# Back wall (painted, 1024x224)
# ---------------------------------------------------------------------------
def backwall():
    rng = random.Random(1234)
    W, H = WALL_W, WALL_H
    cv = Canvas(W, H)
    CEIL = 22
    TILE_TOP = 128
    BASE = 212

    # --- upper plaster
    n = value_noise(W, H, 24, 5, 4)
    grad = np.clip(np.linspace(-0.25, 0.15, H)[:, None], -1, 1)
    field = np.clip(n * 0.75 + 0.25 + grad * 0.4, 0, 1)
    cv.fill_field(0, CEIL, W, TILE_TOP - CEIL, "plaster", field[CEIL:TILE_TOP], lo=1, hi=5)

    # --- ceiling: drop panels, some missing
    cv.rect(0, 0, W, CEIL, c("plaster", 2))
    nc = value_noise(W, CEIL, 8, 9)
    cv.fill_field(0, 0, W, CEIL, "plaster", nc, lo=2, hi=4)
    for x in range(0, W, 32):
        cv.vline(x, 0, CEIL, c("metal", 3))
        missing = rng.random() < 0.25
        if missing and x > 0:
            cv.rect(x + 1, 0, 31, CEIL - 3, c("ink", 0))
            # pipes and wires in the void
            cv.hline(x + 1, 6, 31, c("metal", 2))
            cv.hline(x + 1, 7, 31, c("metal", 1))
            for k in range(rng.randint(1, 3)):
                wx = x + rng.randint(4, 28)
                ln = rng.randint(8, 26)
                cv.line(wx, CEIL - 3, wx + rng.randint(-3, 3), CEIL - 3 + ln, c("ink", 2))
        elif rng.random() < 0.5:
            stain(cv, x + 16, rng.randint(4, 16), rng.randint(6, 12), rng.randint(3, 7), 0.35, rng, rng.randint(0, 999), 0, 0, W, CEIL)
    cv.rect(0, CEIL - 3, W, 3, c("metal", 3))
    cv.hline(0, CEIL - 3, W, c("metal", 5))
    cv.hline(0, CEIL - 1, W, c("ink", 2))
    # ambient occlusion under ceiling
    for yy in range(CEIL, CEIL + 10):
        for xx in range(W):
            if rng.random() < 1.0 - (yy - CEIL) / 10.0:
                cv.darken(xx, yy, 0.18)

    # --- water streaks from ceiling
    for _ in range(26):
        x = rng.randint(0, W)
        drips(cv, x, CEIL, rng.randint(2, 6), rng.randint(20, 80), 0.28, rng)
    # large damp stains
    for _ in range(12):
        stain(cv, rng.randint(0, W), rng.randint(CEIL + 5, TILE_TOP - 10), rng.randint(10, 30), rng.randint(8, 22), 0.22, rng, rng.randint(0, 999), 0, CEIL, W, TILE_TOP - CEIL)

    # --- peeling paint patches exposing concrete
    for _ in range(14):
        px_ = rng.randint(10, W - 30)
        py_ = rng.randint(CEIL + 10, TILE_TOP - 16)
        pw, ph = rng.randint(6, 18), rng.randint(4, 10)
        pts = []
        for k in range(8):
            a = k / 8 * math.tau
            rr = 0.7 + rng.random() * 0.5
            pts.append((px_ + math.cos(a) * pw / 2 * rr, py_ + math.sin(a) * ph / 2 * rr))
        cv.poly(pts, c("concrete", 3))
        for (x0, y0) in pts[::2]:
            cv.px(x0, y0, c("plaster", 6))
        speckle(cv, px_ - pw // 3, py_ - ph // 3, pw // 2 + 1, ph // 2 + 1, [c("concrete", 2), c("concrete", 4)], 0.2, rng)

    # --- cracks in plaster
    for _ in range(12):
        crack(cv, rng.randint(0, W), rng.randint(CEIL + 2, TILE_TOP - 30), rng.randint(10, 35), c("plaster", 0), rng, 0.15, light=c("plaster", 6))

    # --- tiled wainscot
    TW, TH = 10, 10
    nt = value_noise(W, BASE - TILE_TOP, 30, 17, 2)
    cv.rect(0, TILE_TOP - 2, W, 3, c("tile", 2))
    cv.hline(0, TILE_TOP - 2, W, c("tile", 5))
    for ty in range(TILE_TOP + 1, BASE, TH):
        for tx in range(0, W, TW):
            base = 4 + (1 if rng.random() < 0.15 else 0) - (1 if rng.random() < 0.15 else 0)
            dirt = (ty - TILE_TOP) / (BASE - TILE_TOP)
            base -= int(dirt * 1.8 + nt[min(ty - TILE_TOP, nt.shape[0] - 1), tx] * 1.2)
            if rng.random() < 0.018:
                # missing tile: adhesive comb
                cv.rect(tx, ty, TW - 1, TH - 1, c("concrete", 3))
                for k in range(ty + 1, ty + TH - 1, 2):
                    cv.hline(tx + 1, k, TW - 3, c("concrete", 2))
                cv.hline(tx, ty, TW - 1, c("concrete", 1))
                continue
            cv.rect(tx, ty, TW - 1, TH - 1, c("tile", base))
            cv.hline(tx, ty, TW - 1, c("tile", base + 1))
            cv.px(tx + 1, ty + 1, c("tile", base + 2))
            cv.vline(tx + TW - 2, ty + 1, TH - 2, c("tile", base - 1))
            if rng.random() < 0.08:
                cv.line(tx + rng.randint(0, 8), ty, tx + rng.randint(0, 8), ty + TH - 2, c("tile", 0))
        # grout lines
        cv.hline(0, ty + TH - 1, W, c("tile", 1))
    for tx in range(TW - 1, W, TW):
        cv.vline(tx, TILE_TOP + 1, BASE - TILE_TOP - 1, c("tile", 1))
    # grime near the floor
    for yy in range(BASE - 22, BASE):
        for xx in range(W):
            if rng.random() < (yy - (BASE - 22)) / 30.0:
                cv.darken(xx, yy, 0.15)

    # --- baseboard
    cv.rect(0, BASE, W, H - BASE, c("concrete", 1))
    cv.hline(0, BASE, W, c("concrete", 4))
    cv.hline(0, BASE + 1, W, c("concrete", 2))
    for _ in range(40):
        x = rng.randint(0, W)
        cv.hline(x, BASE + rng.randint(3, 10), rng.randint(2, 6), c("concrete", 3))

    # --- decor: category signs
    for sx, label, col in [(128, "饮料", "blue"), (360, "零食", "red"), (600, "日用品", "yellow"), (820, "收银", "green")]:
        cv.vline(sx + 4, CEIL, 12, c("metal", 3))
        cv.vline(sx + 36, CEIL, 10 if label != "零食" else 16, c("metal", 3))
        if label == "零食":
            # hanging by one wire, tilted
            pts = [(sx, CEIL + 12), (sx + 40, CEIL + 16), (sx + 40, CEIL + 28), (sx, CEIL + 24)]
            cv.poly(pts, c(col, 2))
            cv.line(sx, CEIL + 12, sx + 40, CEIL + 16, c(col, 4))
            text(cv, sx + 10, CEIL + 14, label, c("paper", 5), 12)
        else:
            cv.rect(sx, CEIL + 10, 40 if len(label) == 2 else 50, 13, c(col, 2))
            cv.hline(sx, CEIL + 10, 40 if len(label) == 2 else 50, c(col, 4))
            text(cv, sx + 8, CEIL + 11, label, c("paper", 5), 12)
        stain(cv, sx + 20, CEIL + 16, 14, 5, 0.2, rng, sx)

    # --- clock (stopped)
    cx, cy = 520, 64
    cv.disc(cx, cy, 9, c("metal", 2))
    cv.disc(cx, cy, 7, c("paper", 5))
    for a in range(0, 360, 30):
        cv.px(int(cx + math.cos(math.radians(a)) * 6), int(cy + math.sin(math.radians(a)) * 6), c("ink", 2))
    cv.line(cx, cy, cx - 3, cy - 3, c("ink", 1))
    cv.line(cx, cy, cx + 1, cy - 5, c("ink", 1))
    cv.line(cx + 2, cy - 6, cx + 5, cy + 2, c("paper", 3))  # glass crack

    # --- torn posters & notices
    def poster(x, y, w, h, col):
        cv.rect(x, y, w, h, c(col, 3))
        cv.rect(x + 2, y + 2, w - 4, h // 2, c(col, 4))
        cv.rect(x + 3, y + h // 2 + 3, w - 6, 2, c("paper", 5))
        cv.rect(x + 3, y + h // 2 + 7, w - 10, 1, c("paper", 4))
        # torn corner
        cv.poly([(x + w - 7, y + h), (x + w, y + h - 9), (x + w, y + h)], c("plaster", 3))
        for k in range(0, h, 2):
            cv.darken(x + rng.randint(0, w - 1), y + k, 0.2)

    poster(236, 60, 22, 30, "red")
    poster(700, 70, 18, 26, "yellow")
    # missing-person notices (small papers with a photo box)
    for i, (nx_, ny_) in enumerate([(272, 72), (286, 78), (744, 64)]):
        cv.rect(nx_, ny_, 11, 14, c("paper", 5))
        cv.rect(nx_ + 3, ny_ + 2, 5, 5, c("concrete", 3))
        cv.hline(nx_ + 2, ny_ + 9, 7, c("ink", 2))
        cv.hline(nx_ + 2, ny_ + 11, 5, c("ink", 2))
        cv.px(nx_ + 5, ny_ + 1, c("metal", 6))  # pin
    text(cv, 268, 94, "寻人", c("ink", 2), 12)

    # --- boarded window (moonlight source) at x 400..456
    wx, wy, ww, wh = 402, 44, 56, 60
    cv.rect(wx - 3, wy - 3, ww + 6, wh + 6, c("concrete", 2))
    cv.rect(wx, wy, ww, wh, c("cold", 1))
    nn = value_noise(ww, wh, 10, 77)
    cv.fill_field(wx, wy, ww, wh, "cold", nn * 0.6 + 0.2, lo=1, hi=4)
    for (y0, y1, off) in [(wy + 6, wy + 12, 0), (wy + 22, wy + 18, 1), (wy + 36, wy + 40, 0), (wy + 50, wy + 48, 1)]:
        cv.poly([(wx - 6, y0), (wx + ww + 6, y1), (wx + ww + 6, y1 + 8), (wx - 6, y0 + 8)], c("wood", 3 + off))
        cv.line(wx - 6, y0, wx + ww + 6, y1, c("wood", 5))
        cv.line(wx - 6, y0 + 8, wx + ww + 6, y1 + 8, c("wood", 1))
        cv.px(wx - 2, y0 + 3, c("metal", 6))
        cv.px(wx + ww + 1, y1 + 3, c("metal", 6))
    cv.rect(wx - 4, wy + wh + 3, ww + 8, 3, c("concrete", 4))

    # --- vent grate
    vx, vy = 660, 36
    cv.rect(vx, vy, 26, 14, c("metal", 3))
    for k in range(vy + 2, vy + 13, 2):
        cv.hline(vx + 2, k, 22, c("ink", 1))
    drips(cv, vx + 13, vy + 14, 3, 30, 0.3, rng)

    # --- CCTV camera
    cx_, cy_ = 900, CEIL
    cv.vline(cx_, cy_, 5, c("metal", 3))
    cv.poly([(cx_ - 6, cy_ + 5), (cx_ + 6, cy_ + 5), (cx_ + 8, cy_ + 10), (cx_ - 4, cy_ + 11)], c("metal", 5))
    cv.px(cx_ + 7, cy_ + 8, c("red", 1))

    # --- cigarette rack behind the counter
    rx, ry = 790, 88
    cv.rect(rx, ry, 70, 40, c("wood", 2))
    for ly in (ry + 12, ry + 25, ry + 38):
        cv.hline(rx, ly, 70, c("wood", 5))
        xx = rx + 3
        while xx < rx + 66:
            if rng.random() < 0.3:
                col = rng.choice(["red", "blue", "paper", "yellow"])
                cv.rect(xx, ly - 7, 4, 7, c(col, 4))
                cv.hline(xx, ly - 7, 4, c("paper", 6))
            xx += 5
    cv.rect(rx, ry, 70, 1, c("wood", 5))

    # --- storeroom door (painted into the wall, left side)
    sd = storeroom_door()
    cv.blit(sd, 40, BASE - sd.h + 12)
    # door frame shadow
    for yy in range(BASE - sd.h + 8, BASE + 12):
        cv.darken(38, yy, 0.4)
        cv.darken(39, yy, 0.3)

    # --- handwritten warning near the exit
    text(cv, 896, 150, "它们", c("red", 1), 12, jitter=0.12, rng=rng)
    text(cv, 896, 164, "听得见", c("red", 1), 12, jitter=0.12, rng=rng)
    # --- old dried hand smear
    for k in range(18):
        x = 330 + k
        y = 150 + int(k * 0.3)
        cv.tint(x, y, c("blood", 2), 0.55)
        cv.tint(x, y + 1, c("blood", 1), 0.5)
        if k % 4 == 0:
            drips(cv, x, y + 2, 1, 14, 0.2, rng)

    return cv


# ---------------------------------------------------------------------------
# Tiles (16x16 atlas, 8 columns)
# ---------------------------------------------------------------------------
def floor_plane_tile(rng, row, variant):
    """Floor seen from the side-top: a band of worn checker linoleum.
    row 0 = far (against the wall), 2 = nearest the camera."""
    t = Canvas(16, 16)
    base = [3, 4, 4][row]
    n = value_noise(16, 16, 6, rng.randint(0, 99999), 2)
    for y in range(16):
        # far rows are compressed: tiles 4px tall at row 0, 8 at row 2
        cell_h = [4, 6, 8][row]
        cy = (y + row * 3) // cell_h
        for x in range(16):
            cx = (x + (cy % 2) * 8) // 8
            dark = (cx + cy) % 2 == 0
            v = base + (0 if dark else 1)
            f = n[y, x]
            if f < 0.3:
                v -= 1
            elif f > 0.78:
                v += 1
            t.px(x, y, c("concrete", v))
        # grout line at tile boundaries
        if (y + row * 3) % cell_h == 0:
            t.hline(0, y, 16, c("concrete", base - 1))
    if row == 0:
        # contact shadow under the baseboard
        t.hline(0, 0, 16, c("concrete", 1))
        t.hline(0, 1, 16, c("concrete", 2))
    # wear variants
    if variant == 1:
        crack(t, rng.randint(2, 13), 0, 16, c("concrete", 1), rng, 0.25, light=c("concrete", base + 2))
    elif variant == 2:
        stain(t, rng.randint(4, 12), rng.randint(4, 12), 7, 4, 0.35, rng, rng.randint(0, 999))
    elif variant == 3:
        # missing tile chunk showing screed
        x0, y0 = rng.randint(1, 8), rng.randint(3, 9)
        t.rect(x0, y0, 7, 4, c("concrete", 2))
        t.hline(x0, y0, 7, c("concrete", 1))
        speckle(t, x0, y0 + 1, 7, 3, [c("concrete", 3)], 0.3, rng)
    elif variant == 4:
        # dark puddle with cold highlight
        t.ellipse(8, 9, 6, 2, c("cold", 1))
        t.hline(5, 8, 4, c("cold", 3))
    elif variant == 5:
        speckle(t, 0, 0, 16, 16, [c("concrete", 2), c("paper", 3), c("concrete", 6)], 0.08, rng)
    elif variant == 6:
        # scuff marks
        for _ in range(3):
            y = rng.randint(2, 14)
            x = rng.randint(0, 10)
            t.hline(x, y, rng.randint(3, 6), c("concrete", base - 1))
    elif variant == 7:
        # dried dark stain (old blood)
        stain(t, rng.randint(5, 11), rng.randint(5, 11), 5, 3, 0.25, rng, rng.randint(0, 999))
        for _ in range(6):
            t.tint(rng.randint(4, 12), rng.randint(6, 12), c("blood", 2), 0.4)
    # the nearest row gets darker toward the camera (vignette-ish falloff)
    if row == 2:
        for y in range(8, 16):
            for x in range(16):
                t.darken(x, y, (y - 8) / 8 * 0.35)
    return t


def wall_tile(rng, variant):
    t = Canvas(16, 16)
    n = value_noise(16, 16, 6, rng.randint(0, 9999))
    t.fill_field(0, 0, 16, 16, "concrete", n, lo=1, hi=3)
    # block joints
    t.hline(0, 7, 16, c("concrete", 0))
    t.hline(0, 15, 16, c("concrete", 0))
    t.vline(4 if variant % 2 else 12, 0, 7, c("concrete", 0))
    t.vline(12 if variant % 2 else 4, 8, 7, c("concrete", 0))
    t.hline(0, 0, 16, c("concrete", 4))
    t.hline(0, 8, 16, c("concrete", 4))
    if variant == 2:
        crack(t, 8, 0, 10, c("concrete", 0), rng, 0.2)
    if variant == 3:
        rust_patch(t, 8, 12, 2, rng)
    return t


def tiles():
    """Atlas: rows 0-2 floor plane (far/mid/near, 8 variants), row 3 wall blocks."""
    rng = random.Random(99)
    atlas = Canvas(16 * 8, 16 * 4)
    for row in range(3):
        for i in range(8):
            atlas.blit(floor_plane_tile(rng, row, i), i * 16, row * 16)
    for i in range(4):
        atlas.blit(wall_tile(rng, i), i * 16, 48)
    return atlas


def foreground():
    """Near-black foreground silhouettes with faint rim light."""
    rng = random.Random(5)
    out = {}
    # debris heap in front of the camera
    w, h = 140, 44
    cv = Canvas(w, h)
    pts = [(0, h), (10, 26), (28, 20), (40, 8), (58, 14), (70, 4), (86, 16), (104, 12), (120, 24), (140, h)]
    cv.poly(pts, c("ink", 0))
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        cv.line(x0, y0, x1, y1, c("concrete", 1))
    # sticking rebar / plank
    cv.line(60, 14, 50, -2, c("ink", 1), 1)
    cv.line(61, 14, 51, -2, c("concrete", 1), 1)
    cv.line(96, 16, 120, 2, c("ink", 1), 1)
    out["fg_debris"] = cv
    # hanging cables from the top of the frame
    w, h = 60, 80
    cv = Canvas(w, h)
    for k in range(3):
        x0 = 10 + k * 16
        ln = rng.randint(40, 78)
        for y in range(ln):
            x = x0 + int(math.sin(y / 9.0 + k) * 3)
            cv.px(x, y, c("ink", 0))
            cv.px(x + 1, y, c("ink", 1))
        cv.rect(x0 - 1, ln - 2, 4, 3, c("ink", 1))
    out["fg_cables"] = cv
    # foreground shelf edge (big, blurry-dark, near camera)
    w, h = 70, 150
    cv = Canvas(w, h)
    cv.rect(0, 0, 10, h, c("ink", 0))
    cv.vline(9, 0, h, c("concrete", 1))
    for ly in (20, 60, 100, 140):
        cv.rect(0, ly, w, 5, c("ink", 0))
        cv.hline(0, ly, w, c("concrete", 1))
        for k in range(rng.randint(2, 4)):
            bx = rng.randint(12, w - 10)
            bh = rng.randint(6, 14)
            cv.rect(bx, ly - bh, rng.randint(5, 9), bh, c("ink", 1))
    out["fg_shelf"] = cv
    return out


def main():
    rng = random.Random(42)
    backwall().save(f"{OUT}/backwall.png")
    tiles().save(f"{OUT}/tiles.png")
    shelf(1, sign="blue").save(f"{OUT}/shelf_a.png")
    shelf(2, broken=True, fill=0.35, sign="red").save(f"{OUT}/shelf_b.png")
    shelf(3, fill=0.5, sign="yellow").save(f"{OUT}/shelf_c.png")
    shelf(4, w=48, h=56, fill=0.4).save(f"{OUT}/shelf_low.png")
    cooler(5).save(f"{OUT}/cooler.png")
    counter(6).save(f"{OUT}/counter.png")
    register(False).save(f"{OUT}/register.png")
    register(True).save(f"{OUT}/register_open.png")
    magazine_rack(8).save(f"{OUT}/magazine_rack.png")
    fallen_shelf(9).save(f"{OUT}/fallen_shelf.png")
    boxes_stack(10).save(f"{OUT}/boxes.png")
    for k in ["pile", "bag", "papers", "bottles", "basket", "wet_sign"]:
        trash(11, k).save(f"{OUT}/trash_{k}.png")
    ceiling_lamp(True).save(f"{OUT}/ceiling_lamp_broken.png")
    exit_sign(True).save(f"{OUT}/exit_sign.png")
    exit_door(False).save(f"{OUT}/exit_door.png")
    exit_door(True).save(f"{OUT}/exit_door_open.png")
    for k, v in foreground().items():
        v.save(f"{OUT}/{k}.png")


if __name__ == "__main__":
    main()


# ---------------------------------------------------------------------------
# Back warehouse (Demo 2): cramped, cluttered, darker than the shop floor
# ---------------------------------------------------------------------------
WH_W = 512


def storeroom_door_open():
    """Overlay for the painted storeroom door once it is unlocked (ajar, dark gap)."""
    cv = storeroom_door()
    cv.rect(2, 3, 14, cv.h - 3, c("ink", 0))
    cv.vline(16, 3, cv.h - 3, c("metal", 6))
    cv.rect(18, 34, 3, 2, c("metal", 7))
    return cv


def warehouse_wall():
    rng = random.Random(4242)
    W, H = WH_W, 224
    cv = Canvas(W, H)
    # bare concrete block wall, water damage, exposed pipes
    n = value_noise(W, H, 18, 77, 4)
    cv.fill_field(0, 0, W, H, "concrete", np.clip(n * 0.8 + np.linspace(-0.2, 0.05, H)[:, None], 0, 1), lo=1, hi=4)
    for y in range(8, H, 12):
        off = 0 if (y // 12) % 2 else 12
        cv.hline(0, y, W, c("concrete", 1))
        for x in range(off, W, 24):
            cv.vline(x, y - 11, 11, c("concrete", 1))
    # low ceiling, pipes and a cable tray
    cv.rect(0, 0, W, 16, c("ink", 1))
    for py, col in [(18, 4), (24, 3)]:
        cv.rect(0, py, W, 3, c("metal", col))
        cv.hline(0, py, W, c("metal", col + 2))
        for x in range(30, W, 90):
            cv.rect(x, py - 2, 3, 7, c("metal", 2))
    drips(cv, 140, 27, 4, 90, 0.3, rng)
    drips(cv, 360, 27, 3, 70, 0.3, rng)
    for _ in range(10):
        stain(cv, rng.randint(0, W), rng.randint(30, H), rng.randint(10, 30), rng.randint(8, 24), 0.25, rng, rng.randint(0, 999))
    for _ in range(8):
        crack(cv, rng.randint(0, W), rng.randint(30, 200), rng.randint(10, 30), c("concrete", 0), rng, 0.2)
    # a staff notice board with a shift calendar, a photo and a note
    bx, by = 200, 60
    cv.rect(bx, by, 70, 46, c("wood", 3))
    cv.rect(bx + 2, by + 2, 66, 42, c("wood", 5))
    cv.rect(bx + 5, by + 5, 28, 30, c("paper", 5))  # calendar
    for r in range(5):
        for k in range(7):
            cv.px(bx + 7 + k * 4, by + 12 + r * 5, c("paper", 3))
    cv.px(bx + 7 + 5 * 4, by + 12 + 3 * 5, c("red", 4))
    cv.line(bx + 7, by + 27, bx + 30, by + 27, c("red", 3))
    cv.rect(bx + 38, by + 6, 14, 11, c("white", 0))  # staff photo
    cv.rect(bx + 39, by + 7, 12, 7, c("warm", 2))
    cv.rect(bx + 38, by + 22, 24, 14, c("yellow", 5))  # note
    text(cv, bx + 39, by + 23, "值班", c("ink", 2), 12)
    # a painted green marker next to the hide locker (visual language)
    for k in range(6):
        cv.px(410 + k, 130 + (k % 2), c("green", 3))
    cv.rect(0, H - 12, W, 12, c("concrete", 1))
    cv.hline(0, H - 12, W, c("concrete", 3))
    return cv


def warehouse_tiles():
    rng = random.Random(55)
    atlas = Canvas(16 * 8, 16 * 4)
    for row in range(3):
        for v in range(8):
            t = Canvas(16, 16)
            n = value_noise(16, 16, 5, rng.randint(0, 9999))
            t.fill_field(0, 0, 16, 16, "concrete", n * 0.7, lo=1, hi=3)
            if row == 0:
                t.hline(0, 0, 16, c("concrete", 0))
                t.hline(0, 1, 16, c("concrete", 4))
            if v in (1, 5):
                crack(t, rng.randint(2, 13), 0, 12, c("ink", 1), rng, 0.2)
            if v == 2:
                stain(t, 8, 8, 6, 3, 0.35, rng, rng.randint(0, 99))
            if v == 3:
                t.hline(2, 7, 11, c("yellow", 2))  # worn floor marking
            if v == 4:
                speckle(t, 0, 0, 16, 16, [c("paper", 2), c("concrete", 5)], 0.06, rng)
            if row == 2:
                for y in range(8, 16):
                    for x in range(16):
                        t.darken(x, y, (y - 8) / 8 * 0.35)
            atlas.blit(t, v * 16, row * 16)
    for v in range(4):
        atlas.blit(wall_tile(rng, v), v * 16, 48)
    return atlas


def locker(seed, open_=False, green=False):
    """Staff locker bank (2 doors). green=True: the hide-able one (paint mark + vines)."""
    rng = random.Random(seed)
    w, h = 40, 76
    cv = Canvas(w, h)
    cv.rect(0, 0, w, h, c("metal", 3))
    cv.vline(0, 0, h, c("metal", 5))
    cv.vline(w - 1, 0, h, c("metal", 1))
    for d in range(2):
        dx = 2 + d * 19
        cv.rect(dx, 3, 17, h - 8, c("metal", 4 if not (green and d == 1) else 3))
        for k in range(6, 16, 3):
            cv.hline(dx + 4, k, 9, c("metal", 1))  # vents
        cv.rect(dx + 13, 34, 2, 6, c("metal", 7))
        cv.rect(dx + 4, 22, 9, 6, c("paper", 4))  # name tag
        cv.hline(dx + 5, 24, 6, c("ink", 2))
    if open_:
        cv.rect(4, 5, 13, h - 12, c("ink", 0))
        cv.hline(4, 30, 13, c("metal", 2))
        cv.poly([(2, 3), (-4 + 2, 6), (-4 + 2, h - 6), (2, h - 5)], c("metal", 5))
    if green:
        # faded green paint stripe and a creeping vine: "you can hide in here"
        for y in range(8, h - 10, 2):
            cv.px(22, y, c("green", 3))
            cv.px(23, y + 1, c("green", 2))
        vx = w - 3
        for y in range(h - 1, 12, -1):
            vx += rng.choice([-1, 0, 0, 1])
            vx = max(w - 6, min(w - 1, vx))
            cv.px(vx, y, c("grass", 3))
            if rng.random() < 0.3:
                cv.px(vx - 1, y, c("grass", 5))
    for _ in range(5):
        rust_patch(cv, rng.randint(0, w), rng.randint(40, h), rng.randint(1, 3), rng)
    for _ in range(3):
        stain(cv, rng.randint(0, w), rng.randint(0, h), 4, 8, 0.2, rng, rng.randint(0, 99))
    cv.outline(c("ink", 1))
    return cv


def locker_hide_occupied():
    cv = locker(33, False, True)
    return cv


def cleaning_shelf(searched=False):
    rng = random.Random(21)
    w, h = 44, 58
    cv = Canvas(w, h)
    cv.rect(0, 0, 3, h, c("metal", 4))
    cv.rect(w - 3, 0, 3, h, c("metal", 3))
    for ly in (16, 34, 52):
        cv.rect(0, ly, w, 3, c("metal", 5))
        cv.hline(0, ly, w, c("metal", 7))
        if searched and ly != 52:
            continue
        x = 4
        while x < w - 8:
            if rng.random() < 0.7:
                col = rng.choice(["blue", "yellow", "red", "paper"])
                bh = rng.randint(8, 13)
                cv.rect(x, ly - bh, 6, bh, c(col, 3))
                cv.rect(x + 1, ly - bh - 2, 3, 2, c("white", 0))
                cv.rect(x + 1, ly - bh + 3, 4, 3, c("paper", 5))
            x += 8
    cv.outline(c("ink", 1))
    return cv


def mop_bucket():
    cv = Canvas(22, 36)
    cv.poly([(2, 22), (20, 22), (18, 35), (4, 35)], c("yellow", 3))
    cv.hline(2, 22, 18, c("yellow", 5))
    cv.line(12, 21, 16, 0, c("wood", 4), 1)
    cv.rect(8, 16, 8, 6, c("paper", 3))
    cv.outline(c("ink", 1))
    return cv


def storage_boxes(seed, searched=False):
    rng = random.Random(seed)
    w, h = 52, 44
    cv = Canvas(w, h)

    def cbox(x, y, bw, bh, open_=False):
        cv.rect(x, y, bw, bh, c("wood", 4))
        cv.vline(x, y, bh, c("wood", 5))
        cv.vline(x + bw - 1, y, bh, c("wood", 2))
        cv.hline(x, y, bw, c("wood", 6))
        cv.rect(x + bw // 2 - 2, y, 4, bh // 2, c("paper", 3))
        cv.rect(x + 3, y + bh - 8, 7, 4, c("paper", 4))
        if open_:
            cv.rect(x + 2, y, bw - 4, 3, c("ink", 1))
            cv.poly([(x, y), (x - 4, y - 5), (x + 8, y - 3)], c("wood", 5))
        for _ in range(2):
            stain(cv, x + rng.randint(0, bw), y + rng.randint(0, bh), 3, 3, 0.2, rng, rng.randint(0, 99))

    cbox(0, 20, 26, 24)
    cbox(25, 16, 27, 28, open_=searched)
    cbox(6, 2, 20, 18, open_=searched)
    cv.outline(c("ink", 1))
    return cv


def wh_main():
    OUTW = OUT
    storeroom_door_open().save(f"{OUTW}/storeroom_door_open.png")
    warehouse_wall().save(f"{OUTW}/warehouse_wall.png")
    warehouse_tiles().save(f"{OUTW}/warehouse_tiles.png")
    locker(31).save(f"{OUTW}/locker.png")
    locker(31, True).save(f"{OUTW}/locker_open.png")
    locker(33, True, True).save(f"{OUTW}/locker_hide.png")
    locker(33, False, True).save(f"{OUTW}/locker_hide_closed.png")
    cleaning_shelf(False).save(f"{OUTW}/cleaning_shelf.png")
    cleaning_shelf(True).save(f"{OUTW}/cleaning_shelf_searched.png")
    mop_bucket().save(f"{OUTW}/mop_bucket.png")
    storage_boxes(61).save(f"{OUTW}/storage_boxes.png")
    storage_boxes(61, True).save(f"{OUTW}/storage_boxes_open.png")


if __name__ == "__main__":
    wh_main()
