"""Abandoned street: ground tiles, facade segments, vehicles, props, foreground."""
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import (Canvas, c, value_noise, crack, stain, drips, speckle, rust_patch,  # noqa: E402
                    text, make_sheet, BAYER4, TRANSPARENT)

OUT = "environment/street"
GROUND_Y = 224


# ---------------------------------------------------------------------------
# generic wall painters
# ---------------------------------------------------------------------------
def plaster(cv, x, y, w, h, ramp="plaster", lo=1, hi=4, seed=0, scale=16):
    n = value_noise(w, h, scale, seed, 3)
    grad = np.linspace(-0.12, 0.1, h)[:, None]
    cv.fill_field(x, y, w, h, ramp, np.clip(n * 0.8 + 0.1 + grad, 0, 1), lo=lo, hi=hi)


def bricks(cv, x, y, w, h, ramp="rust", seed=0, lo=1):
    rng = random.Random(seed)
    for by in range(y, y + h, 5):
        off = 0 if ((by - y) // 5) % 2 == 0 else 5
        for bx in range(x - off, x + w, 10):
            v = lo + rng.choice([0, 0, 1, 1, 2])
            x0, x1 = max(bx, x), min(bx + 9, x + w)
            if x1 > x0:
                cv.rect(x0, by, x1 - x0, 4, c(ramp, v))
                cv.hline(x0, by, x1 - x0, c(ramp, v + 1))
        cv.hline(x, by + 4, w, c("concrete", 1))


def grime(cv, x, y, w, h, rng, amount=1.0):
    for _ in range(int(6 * amount * w / 100)):
        stain(cv, x + rng.randint(0, w), y + rng.randint(0, h), rng.randint(5, 16), rng.randint(6, 20), 0.25, rng, rng.randint(0, 9999), x, y, w, h)
    for _ in range(int(4 * amount * w / 100)):
        drips(cv, x + rng.randint(0, w), y + rng.randint(0, max(1, h // 3)), rng.randint(1, 4), rng.randint(10, 40), 0.25, rng)
    for _ in range(int(3 * amount * w / 100)):
        crack(cv, x + rng.randint(0, w), y + rng.randint(0, h), rng.randint(8, 26), c("ink", 2), rng, 0.2)
    # damp dark band at the bottom
    for yy in range(y + h - 14, y + h):
        for xx in range(x, x + w):
            if rng.random() < (yy - (y + h - 14)) / 16.0:
                cv.darken(xx, yy, 0.18)


def moss(cv, x, y, w, rng, n=10):
    for _ in range(n):
        mx = x + rng.randint(0, w)
        for k in range(rng.randint(2, 6)):
            cv.px(mx + k, y - rng.randint(0, 3), c("grass", rng.randint(2, 4)))


def window(cv, x, y, w, h, rng, broken=True, boarded=False, lit=False):
    cv.rect(x - 2, y - 2, w + 4, h + 4, c("concrete", 2))
    cv.hline(x - 2, y + h + 2, w + 4, c("concrete", 4))
    if lit:
        cv.rect(x, y, w, h, c("warm", 2))
        cv.rect(x + 1, y + 1, w // 2, h - 2, c("warm", 3))
    else:
        cv.rect(x, y, w, h, c("ink", 1))
        # reflection streak
        for k in range(min(w, h) // 2):
            cv.px(x + 2 + k, y + h - 3 - k, c("cold", 1))
    cv.vline(x + w // 2, y, h, c("concrete", 2))
    if broken:
        cx, cy = x + rng.randint(2, w - 3), y + rng.randint(2, h - 3)
        for a in range(0, 360, 60):
            ln = rng.randint(2, 6)
            for i in range(ln):
                cv.px(int(cx + math.cos(math.radians(a)) * i), int(cy + math.sin(math.radians(a)) * i), c("cold", 2))
    if boarded:
        for k in range(3):
            yy = y + 2 + k * (h // 3)
            cv.poly([(x - 3, yy), (x + w + 3, yy + rng.randint(-2, 2)), (x + w + 3, yy + 4), (x - 3, yy + 4)], c("wood", 3))
            cv.hline(x - 3, yy, w + 6, c("wood", 5))


def shutter(cv, x, y, w, h, rng, open_gap=0, graffiti=True):
    cv.rect(x, y, w, h, c("metal", 3))
    for yy in range(y, y + h - open_gap, 3):
        cv.hline(x, yy, w, c("metal", 4))
        cv.hline(x, yy + 2, w, c("metal", 2))
    cv.rect(x - 2, y - 5, w + 4, 5, c("metal", 2))
    cv.hline(x - 2, y - 5, w + 4, c("metal", 5))
    if open_gap:
        cv.rect(x, y + h - open_gap, w, open_gap, c("ink", 0))
    for _ in range(4):
        rust_patch(cv, x + rng.randint(0, w), y + rng.randint(0, h), rng.randint(2, 4), rng)
    if graffiti:
        col = rng.choice([c("red", 3), c("blue", 4), c("paper", 4), c("green", 3)])
        px_, py_ = x + rng.randint(4, max(5, w - 30)), y + rng.randint(6, max(7, h - 20))
        for k in range(rng.randint(3, 5)):
            pts = [(px_ + rng.randint(0, 26), py_ + rng.randint(0, 12)) for _ in range(3)]
            cv.line(*pts[0], *pts[1], col)
            cv.line(*pts[1], *pts[2], col)


def sign_board(cv, x, y, w, h, label, ramp, rng, broken=False):
    cv.rect(x, y, w, h, c(ramp, 1))
    cv.hline(x, y, w, c(ramp, 3))
    cv.hline(x, y + h - 1, w, c("ink", 1))
    if label:
        text(cv, x + 4, y + (h - 12) // 2, label, c(ramp, 4) if not broken else c(ramp, 2), 12)
    if broken:
        cv.poly([(x + w - 16, y), (x + w, y), (x + w, y + h)], TRANSPARENT)
    stain(cv, x + w // 2, y + h // 2, w // 3, h // 2, 0.25, rng, rng.randint(0, 999))


def awning(cv, x, y, w, rng, ramp="red"):
    for k in range(0, w, 10):
        col = c(ramp, 2) if (k // 10) % 2 == 0 else c("paper", 2)
        dh = rng.randint(3, 9) if rng.random() < 0.4 else 8
        cv.poly([(x + k, y), (x + k + 10, y), (x + k + 10, y + dh), (x + k, y + dh + 2)], col)
    cv.hline(x, y, w, c("metal", 3))


def door(cv, x, y, w, h, rng, kind="glass"):
    cv.rect(x - 2, y - 2, w + 4, h + 2, c("concrete", 2))
    if kind == "glass":
        cv.rect(x, y, w, h, c("metal", 3))
        cv.rect(x + 2, y + 2, w - 4, h - 10, c("ink", 0))
        cv.line(x + 3, y + 3, x + w - 4, y + h - 12, c("cold", 1))
    elif kind == "metal":
        n = value_noise(w, h, 6, rng.randint(0, 999))
        cv.fill_field(x, y, w, h, "metal", n, lo=1, hi=3)
        cv.rect(x + w - 5, y + h // 2, 2, 3, c("metal", 6))
    else:  # open / dark
        cv.rect(x, y, w, h, c("ink", 0))


# ---------------------------------------------------------------------------
# facade segments (bottom = ground line). Each returns a Canvas.
# ---------------------------------------------------------------------------
def seg_store_exterior(seed=1):
    rng = random.Random(seed)
    w, h = 300, 200
    cv = Canvas(w, h)
    plaster(cv, 0, 20, w, h - 20, seed=seed)
    for wx in range(14, w - 30, 46):
        window(cv, wx, 36, 26, 30, rng, broken=rng.random() < 0.6, boarded=rng.random() < 0.3)
    cv.rect(0, 84, w, 22, c("green", 0))
    cv.hline(0, 84, w, c("green", 2))
    text(cv, 60, 89, "24H 便利店", c("green", 2), 12)
    awning(cv, 0, 107, w, rng)
    # shop windows + the door the player came out of
    for (wx, ww) in [(10, 90), (190, 100)]:
        cv.rect(wx, 124, ww, 70, c("ink", 1))
        cv.rect(wx, 124, ww, 2, c("metal", 4))
        cv.line(wx + 2, 128, wx + ww - 2, 190, c("paper", 1))
        cv.line(wx + ww - 2, 128, wx + 2, 190, c("paper", 1))
    door(cv, 120, 128, 52, 72, rng, "glass")
    grime(cv, 0, 20, w, h - 20, rng)
    moss(cv, 0, h, w, rng, 16)
    cv.outline(c("ink", 0))
    return cv


def seg_shops(seed=2):
    rng = random.Random(seed)
    w, h = 340, 176
    cv = Canvas(w, h)
    plaster(cv, 0, 10, w, h - 10, ramp="concrete", lo=2, hi=4, seed=seed)
    for wx in range(10, w - 20, 38):
        window(cv, wx, 22, 22, 26, rng, broken=True, boarded=rng.random() < 0.2)
    sign_board(cv, 6, 64, 150, 18, "五金 建材", "blue", rng)
    sign_board(cv, 176, 64, 150, 18, "兰州拉面", "yellow", rng, broken=True)
    shutter(cv, 10, 96, 140, h - 96, rng, open_gap=0)
    shutter(cv, 180, 96, 140, h - 96, rng, open_gap=22)
    grime(cv, 0, 10, w, h - 10, rng, 1.2)
    moss(cv, 0, h, w, rng, 14)
    cv.outline(c("ink", 0))
    return cv


def seg_alley(seed=3):
    rng = random.Random(seed)
    w, h = 150, 150
    cv = Canvas(w, h)
    # dark gap between buildings with a chain-link fence
    cv.rect(0, 0, w, h, c("ink", 0))
    for yy in range(40, h, 1):
        for xx in range(0, w):
            if (xx + yy) % 6 == 0 or (xx - yy) % 6 == 0:
                cv.px(xx, yy, c("metal", 2))
    cv.rect(0, 38, w, 2, c("metal", 4))
    for px_ in range(0, w, 50):
        cv.rect(px_, 36, 3, h - 36, c("metal", 3))
    # a tear in the fence
    cv.poly([(60, 90), (90, 84), (96, 150), (54, 150)], c("ink", 0))
    # trash bags behind the fence
    for k in range(3):
        cv.ellipse(20 + k * 14, h - 6, 9, 6, c("ink", 2))
    cv.outline(c("ink", 0))
    return cv


def seg_apartment(seed=4):
    rng = random.Random(seed)
    w, h = 290, 210
    cv = Canvas(w, h)
    bricks(cv, 0, 0, w, h, "rust", seed, lo=0)
    for fy in (12, 60, 108):
        for wx in range(14, w - 20, 44):
            window(cv, wx, fy, 24, 30, rng, broken=rng.random() < 0.5, boarded=rng.random() < 0.15, lit=(fy == 60 and wx == 190))
            # AC unit
            if rng.random() < 0.35:
                cv.rect(wx + 26, fy + 18, 12, 9, c("metal", 5))
                for k in range(fy + 20, fy + 26, 2):
                    cv.hline(wx + 27, k, 10, c("metal", 2))
    # entrance with steps and a lamp
    cv.rect(100, 150, 90, h - 150, c("concrete", 2))
    door(cv, 118, 158, 54, 46, rng, "glass")
    cv.rect(96, 146, 98, 5, c("concrete", 4))
    sign_board(cv, 124, 136, 42, 10, "", "paper", rng)
    # mailboxes
    for k in range(4):
        cv.rect(20 + k * 12, 168, 10, 8, c("metal", 4))
        cv.hline(20 + k * 12, 171, 10, c("ink", 1))
    grime(cv, 0, 0, w, h, rng, 1.0)
    moss(cv, 0, h, w, rng, 12)
    cv.outline(c("ink", 0))
    return cv


def seg_burnt(seed=5):
    rng = random.Random(seed)
    w, h = 300, 168
    cv = Canvas(w, h)
    plaster(cv, 0, 16, w, h - 16, seed=seed, lo=0, hi=3)
    # heavy soot above openings
    for (ox, ow) in [(20, 110), (160, 120)]:
        cv.rect(ox, 80, ow, h - 80, c("ink", 0))
        for yy in range(30, 80):
            for xx in range(ox - 10, ox + ow + 10):
                d = (80 - yy) / 50.0
                if rng.random() > d + 0.1:
                    cv.darken(xx, yy, 0.55)
        # charred beams inside
        cv.line(ox + 10, 90, ox + ow - 20, 140, c("wood", 0), 2)
        cv.line(ox + 30, h - 2, ox + 60, 100, c("wood", 1), 1)
    sign_board(cv, 30, 40, 220, 20, "      饭    店", "red", rng, broken=True)
    for _ in range(40):
        cv.darken(rng.randint(0, w - 1), rng.randint(16, 60), 0.5)
    grime(cv, 0, 16, w, h - 16, rng, 1.4)
    cv.outline(c("ink", 0))
    return cv


def seg_lot(seed=6):
    """Empty lot: low wall, billboard, weeds."""
    rng = random.Random(seed)
    w, h = 360, 150
    cv = Canvas(w, h)
    # billboard on posts
    cv.rect(60, 20, 220, 70, c("metal", 2))
    cv.rect(64, 24, 212, 62, c("paper", 3))
    cv.rect(64, 24, 212, 62, c("blue", 2))
    cv.rect(72, 32, 90, 46, c("paper", 4))
    text(cv, 180, 40, "新生活", c("paper", 5), 12)
    text(cv, 180, 58, "就在这里", c("paper", 4), 12)
    # torn poster strips
    for k in range(6):
        tx = rng.randint(64, 250)
        cv.poly([(tx, 24), (tx + 14, 24), (tx + 10, 24 + rng.randint(20, 60)), (tx + 2, 24 + rng.randint(10, 40))], c("metal", 2))
    cv.rect(100, 90, 6, h - 110, c("metal", 3))
    cv.rect(230, 90, 6, h - 110, c("metal", 3))
    # low wall
    bricks(cv, 0, h - 40, w, 40, "concrete", seed, lo=2)
    cv.hline(0, h - 41, w, c("concrete", 5))
    grime(cv, 0, 20, w, h - 20, rng, 0.8)
    for _ in range(40):
        gx = rng.randint(0, w - 2)
        for k in range(rng.randint(3, 9)):
            cv.px(gx + rng.randint(-1, 1), h - 40 - k, c("grass", rng.randint(2, 5)))
    cv.outline(c("ink", 0))
    return cv


def seg_school(seed=7):
    """School perimeter wall and gate — the end of the street."""
    rng = random.Random(seed)
    w, h = 420, 190
    cv = Canvas(w, h)
    # the school building behind the wall
    plaster(cv, 120, 0, 300, 120, ramp="paper", lo=1, hi=3, seed=seed)
    for fy in (12, 52):
        for wx in range(134, 410, 30):
            window(cv, wx, fy, 18, 26, rng, broken=rng.random() < 0.4, lit=(fy == 52 and wx == 254))
    cv.rect(120, 90, 300, 4, c("paper", 1))
    # perimeter wall
    plaster(cv, 0, 110, w, h - 110, ramp="concrete", lo=2, hi=4, seed=seed + 1)
    cv.rect(0, 108, w, 4, c("concrete", 5))
    # gate
    gx = 240
    cv.rect(gx, 100, 12, h - 100, c("concrete", 4))
    cv.rect(gx + 120, 100, 12, h - 100, c("concrete", 4))
    cv.rect(gx + 12, 120, 108, h - 120, c("ink", 0))
    for k in range(gx + 14, gx + 118, 6):
        cv.vline(k, 120, h - 120, c("metal", 3))
    cv.hline(gx + 12, 130, 108, c("metal", 4))
    cv.hline(gx + 12, h - 16, 108, c("metal", 4))
    # half-open gate leaf
    cv.poly([(gx + 70, 120), (gx + 118, 116), (gx + 118, h), (gx + 70, h)], c("ink", 0))
    for k in range(gx + 72, gx + 118, 7):
        cv.vline(k, 118, h - 118, c("metal", 2))
    # plaque
    cv.rect(40, 130, 150, 22, c("paper", 4))
    cv.rect(42, 132, 146, 18, c("paper", 5))
    text(cv, 56, 135, "市第三中学", c("red", 2), 12)
    # barbed wire on top
    for k in range(0, w, 4):
        cv.px(k, 106 - (k // 4) % 2, c("metal", 5))
    grime(cv, 0, 100, w, h - 100, rng, 1.0)
    moss(cv, 0, h, w, rng, 20)
    cv.outline(c("ink", 0))
    return cv


# ---------------------------------------------------------------------------
# ground tiles: row0 sidewalk, row1 curb+road, row2 road near, row3 blocks
# ---------------------------------------------------------------------------
def sidewalk_tile(rng, v):
    t = Canvas(16, 16)
    n = value_noise(16, 16, 6, rng.randint(0, 99999))
    t.fill_field(0, 0, 16, 16, "concrete", n * 0.7 + 0.2, lo=3, hi=5)
    t.hline(0, 0, 16, c("concrete", 6))
    t.hline(0, 1, 16, c("concrete", 5))
    for yy in (6, 12):
        t.hline(0, yy, 16, c("concrete", 2))
    t.vline(8 if v % 2 else 0, 2, 4, c("concrete", 2))
    t.vline(0 if v % 2 else 8, 7, 5, c("concrete", 2))
    if v in (1, 5):
        crack(t, rng.randint(2, 13), 2, 6, c("concrete", 2), rng, 0.0)
    if v in (2, 6):
        for k in range(rng.randint(2, 5)):
            gx = rng.randint(0, 15)
            t.vline(gx, 0, rng.randint(1, 3), c("grass", rng.randint(3, 5)))
            t.px(gx, 6, c("grass", 3))
    if v == 3:
        stain(t, 8, 8, 6, 4, 0.35, rng, rng.randint(0, 99))
    if v == 4:
        # dried blood smear
        for k in range(8):
            t.tint(4 + k, 8 + (k % 3), c("blood", 2), 0.6)
    if v == 7:
        t.rect(3, 3, 10, 9, c("concrete", 1))  # missing paver
        speckle(t, 3, 3, 10, 9, [c("concrete", 2), c("grass", 2)], 0.3, rng)
    return t


def road_tile(rng, row, v):
    t = Canvas(16, 16)
    n = value_noise(16, 16, 5, rng.randint(0, 99999))
    t.fill_field(0, 0, 16, 16, "concrete", n * 0.6, lo=1, hi=3)
    if row == 1:
        # curb at the top
        t.rect(0, 0, 16, 4, c("concrete", 5))
        t.hline(0, 0, 16, c("concrete", 7))
        t.hline(0, 4, 16, c("ink", 1))
        t.hline(0, 5, 16, c("concrete", 1))
        if v in (3, 6):
            t.rect(rng.randint(0, 10), 0, 5, 3, c("concrete", 2))  # chipped curb
    else:
        if v in (0, 4):
            t.rect(2, 7, 12, 2, c("paper", 2))  # faded lane dash
            t.rect(3, 7, 4, 2, c("paper", 3))
        if v == 5:
            t.ellipse(8, 8, 6, 3, c("metal", 2))  # manhole
            t.ellipse(8, 8, 5, 2, c("metal", 3))
            t.hline(4, 8, 9, c("metal", 1))
        if v == 6:
            t.ellipse(8, 9, 6, 2, c("cold", 1))
            t.hline(5, 8, 4, c("cold", 3))
    if v in (1, 7):
        crack(t, rng.randint(1, 14), 0 if row == 2 else 6, 7, c("ink", 1), rng, 0.0, dirx=rng.choice([-1, 1]), diry=0)
    if v == 2:
        speckle(t, 0, 0, 16, 16, [c("concrete", 4), c("paper", 2)], 0.08, rng)
    if v == 3 and row == 2:
        stain(t, 8, 8, 7, 3, 0.4, rng, rng.randint(0, 99))
    if row == 2:
        for y in range(8, 16):
            for x in range(16):
                t.darken(x, y, (y - 8) / 8 * 0.3)
    return t


def block_tile(rng, v):
    t = Canvas(16, 16)
    n = value_noise(16, 16, 6, rng.randint(0, 9999))
    t.fill_field(0, 0, 16, 16, "concrete", n, lo=2, hi=4)
    t.hline(0, 0, 16, c("concrete", 6))
    t.hline(0, 15, 16, c("concrete", 1))
    t.vline(15, 0, 16, c("concrete", 1))
    if v == 1:
        crack(t, 6, 0, 10, c("ink", 2), rng, 0.2)
    if v == 2:
        moss(t, 0, 2, 16, rng, 4)
    return t


def tiles():
    rng = random.Random(77)
    atlas = Canvas(16 * 8, 16 * 4)
    for i in range(8):
        atlas.blit(sidewalk_tile(rng, i), i * 16, 0)
        atlas.blit(road_tile(rng, 1, i), i * 16, 16)
        atlas.blit(road_tile(rng, 2, i), i * 16, 32)
    for i in range(4):
        atlas.blit(block_tile(rng, i % 3), i * 16, 48)
    return atlas


# ---------------------------------------------------------------------------
# vehicles & props
# ---------------------------------------------------------------------------
def car(seed=1, kind="sedan", ramp=None):
    rng = random.Random(seed)
    ramp = ramp or rng.choice(["blue", "red", "paper", "cloth2"])
    if kind == "sedan":
        w, h = 104, 42
    else:
        w, h = 118, 56
    cv = Canvas(w, h)
    body_top = 18 if kind == "sedan" else 6
    # body
    if kind == "sedan":
        pts = [(2, 34), (4, 24), (18, 20), (30, 8), (70, 6), (84, 20), (100, 23), (103, 34)]
    else:
        pts = [(2, 48), (3, 10), (8, 4), (84, 3), (100, 20), (116, 26), (117, 48)]
    cv.poly(pts, c(ramp, 2))
    n = value_noise(w, h, 10, seed)
    for y in range(h):
        for x in range(w):
            if cv.filled(x, y):
                v = 2 + (1 if n[y, x] > 0.6 else 0) - (1 if y > h - 14 else 0)
                cv.px(x, y, c(ramp, v))
    # highlight on the upper body line
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        if y1 < 30 and y0 < 30:
            cv.line(x0, y0, x1, y1, c(ramp, 4))
    # windows
    if kind == "sedan":
        cv.poly([(32, 10), (50, 9), (50, 20), (24, 21)], c("ink", 1))
        cv.poly([(53, 9), (69, 8), (80, 20), (53, 20)], c("ink", 1))
        cv.line(33, 11, 48, 11, c("cold", 2))
        # shattered rear window
        for k in range(8):
            cv.px(60 + rng.randint(0, 14), 10 + rng.randint(0, 9), c("cold", 2))
    else:
        cv.poly([(86, 6), (98, 21), (86, 21)], c("ink", 1))
        for wx in range(10, 78, 22):
            cv.rect(wx, 10, 18, 12, c("ink", 1))
        cv.hline(8, 30, 100, c(ramp, 4))
    # doors & handles
    dx = 50 if kind == "sedan" else 60
    cv.vline(dx, 21 if kind == "sedan" else 24, 12, c(ramp, 1))
    cv.hline(dx - 8, 25 if kind == "sedan" else 30, 4, c("metal", 5))
    # bumpers & lights
    cv.rect(0, 30 if kind == "sedan" else 44, 6, 4, c("metal", 4))
    cv.rect(w - 6, 30 if kind == "sedan" else 44, 6, 4, c("metal", 4))
    cv.rect(w - 5, 24 if kind == "sedan" else 34, 3, 3, c("yellow", 3))
    cv.rect(1, 25 if kind == "sedan" else 36, 3, 3, c("red", 2))
    # wheels (flat tires)
    for wx in ((22, 82) if kind == "sedan" else (22, 96)):
        cv.ellipse(wx, h - 6, 8, 6, c("ink", 1))
        cv.ellipse(wx, h - 6, 4, 3, c("metal", 3))
        cv.px(wx, h - 6, c("metal", 5))
        cv.hline(wx - 8, h - 1, 17, c("ink", 1))
    # rust, dents, dust
    for _ in range(9):
        rust_patch(cv, rng.randint(4, w - 4), rng.randint(body_top, h - 6), rng.randint(1, 3), rng)
    for _ in range(5):
        stain(cv, rng.randint(0, w), rng.randint(0, h), rng.randint(5, 12), rng.randint(3, 6), 0.25, rng, rng.randint(0, 999))
    for _ in range(3):
        crack(cv, rng.randint(10, w - 10), rng.randint(body_top + 4, h - 10), 6, c(ramp, 0), rng, 0.2)
    cv.outline(c("ink", 0))
    return cv


def car_door_open(seed=1, ramp=None):
    """Sedan with the driver door hanging open (hide spot state)."""
    cv = car(seed, "sedan", ramp)
    cv.poly([(42, 21), (52, 21), (54, 34), (40, 34)], c("ink", 0))
    cv.poly([(28, 20), (40, 21), (38, 35), (26, 33)], c(ramp or "blue", 1))
    cv.outline(c("ink", 0))
    return cv


def dumpster(open_lid=False, seed=3):
    rng = random.Random(seed)
    w, h = 64, 40
    cv = Canvas(w, h)
    cv.poly([(2, 10), (62, 10), (58, 36), (6, 36)], c("green", 1))
    for y in range(10, 36):
        for x in range(0, w):
            if cv.filled(x, y):
                cv.px(x, y, c("green", 2 if (x // 8) % 2 == 0 else 1))
    cv.hline(2, 10, 60, c("green", 3))
    cv.rect(0, 12, 64, 3, c("green", 3))
    if open_lid:
        cv.poly([(2, 10), (60, 10), (56, 0), (8, 2)], c("green", 0))
        cv.rect(6, 10, 52, 2, c("ink", 0))
    else:
        cv.poly([(0, 10), (64, 10), (62, 6), (2, 6)], c("green", 2))
        cv.hline(2, 6, 60, c("green", 4))
    for wx in (10, 54):
        cv.ellipse(wx, 37, 3, 3, c("ink", 1))
    for _ in range(8):
        rust_patch(cv, rng.randint(2, 60), rng.randint(12, 34), rng.randint(1, 3), rng)
    text(cv, 20, 18, "环卫", c("paper", 2), 12)
    # overflowing bag
    cv.ellipse(46, 8, 7, 5, c("ink", 2))
    cv.outline(c("ink", 0))
    return cv


def barrier(seed=4):
    rng = random.Random(seed)
    w, h = 50, 26
    cv = Canvas(w, h)
    cv.poly([(4, 0), (46, 0), (50, 26), (0, 26)], c("concrete", 4))
    cv.hline(4, 0, 42, c("concrete", 6))
    for k in range(0, 50, 12):
        cv.poly([(k, 8), (k + 6, 8), (k + 2, 16), (k - 4, 16)], c("red", 2))
    for _ in range(3):
        crack(cv, rng.randint(5, 45), 2, 10, c("concrete", 1), rng, 0.3)
    cv.outline(c("ink", 0))
    return cv


def fire_barrel_frames():
    frames = []
    for f in range(4):
        rng = random.Random(100 + f)
        cv = Canvas(22, 40)
        cv.rect(3, 18, 16, 22, c("rust", 2))
        for yy in (20, 29, 37):
            cv.hline(3, yy, 16, c("rust", 4))
        cv.vline(3, 18, 22, c("rust", 3))
        cv.vline(18, 18, 22, c("rust", 1))
        # flames
        for k in range(14):
            fx = 5 + rng.randint(0, 11)
            fh = rng.randint(4, 14)
            for y in range(fh):
                col = c("warm", 6) if y < fh * 0.3 else (c("warm", 5) if y < fh * 0.7 else c("warm", 3))
                cv.px(fx + (1 if (y + f) % 3 == 0 else 0), 18 - y, col)
        cv.px(8 + f, 2 + f, c("warm", 4))
        cv.outline(c("ink", 0))
        frames.append(cv)
    return frames


def grass_frames(seed, w=40, h=26, frames=4, tall=1.0):
    rng = random.Random(seed)
    blades = []
    for _ in range(int(w * 1.3)):
        bx = rng.randint(1, w - 2)
        bh = int(rng.randint(h // 3, h - 2) * tall)
        lean = rng.uniform(-0.25, 0.25)
        col = rng.randint(1, 5)
        blades.append((bx, bh, lean, col))
    out = []
    for f in range(frames):
        cv = Canvas(w, h)
        sway = math.sin(f / frames * math.tau) * 1.2
        for (bx, bh, lean, col) in sorted(blades, key=lambda b: b[3]):
            for y in range(bh):
                t = y / max(bh, 1)
                x = bx + (lean * y + sway * t * t)
                cv.px(int(round(x)), h - 1 - y, c("grass", min(6, col + (1 if t > 0.7 else 0))))
        # seed heads
        for (bx, bh, lean, col) in blades[::7]:
            cv.px(int(round(bx + lean * bh + sway)), h - bh - 1, c("yellow", 2))
        out.append(cv)
    return out


def bush(seed):
    rng = random.Random(seed)
    w, h = 44, 30
    cv = Canvas(w, h)
    for _ in range(26):
        cx, cy = rng.randint(6, w - 6), rng.randint(8, h - 4)
        cv.disc(cx, cy, rng.randint(4, 7), c("grass", rng.randint(1, 3)))
    for _ in range(60):
        x, y = rng.randint(0, w - 1), rng.randint(0, h - 1)
        if cv.filled(x, y):
            cv.px(x, y, c("grass", rng.randint(3, 5)))
    for k in range(3):
        cv.line(w // 2, h, w // 2 + rng.randint(-10, 10), h - rng.randint(8, 16), c("wood", 1))
    cv.outline(c("ink", 0))
    return cv


def dead_tree(seed=8):
    rng = random.Random(seed)
    w, h = 70, 120
    cv = Canvas(w, h)

    def branch(x, y, ang, ln, wd):
        if ln < 4:
            return
        x2 = x + math.cos(ang) * ln
        y2 = y + math.sin(ang) * ln
        cv.line(x, y, x2, y2, c("wood", 1), max(1, int(wd)))
        for _ in range(2):
            branch(x2, y2, ang + rng.uniform(-0.7, 0.7), ln * rng.uniform(0.55, 0.75), wd * 0.6)

    cv.rect(33, 70, 5, 50, c("wood", 1))
    cv.vline(33, 70, 50, c("wood", 2))
    branch(35, 72, -math.pi / 2, 30, 4)
    cv.outline(c("ink", 0))
    return cv


def road_sign(seed=9):
    w, h = 26, 70
    cv = Canvas(w, h)
    cv.line(12, h, 16, 18, c("metal", 4), 1)
    cv.line(13, h, 17, 18, c("metal", 3), 1)
    cv.poly([(4, 6), (22, 2), (24, 18), (6, 22)], c("blue", 3))
    cv.poly([(6, 8), (20, 5), (22, 16), (8, 19)], c("blue", 4))
    cv.line(9, 12, 19, 10, c("paper", 5))
    cv.px(19, 9, c("paper", 5))
    cv.px(19, 11, c("paper", 5))
    rust_patch(cv, 18, 16, 2, random.Random(1))
    cv.outline(c("ink", 0))
    return cv


def cone():
    cv = Canvas(12, 16)
    cv.poly([(5, 0), (7, 0), (11, 14), (1, 14)], c("red", 4))
    cv.hline(3, 6, 6, c("paper", 5))
    cv.rect(0, 14, 12, 2, c("red", 2))
    cv.outline(c("ink", 0))
    return cv


def trash_bags(seed=10):
    rng = random.Random(seed)
    w, h = 44, 20
    cv = Canvas(w, h)
    for k in range(4):
        cx = 8 + k * 10 + rng.randint(-2, 2)
        cv.ellipse(cx, h - 7, 8, 7, c("ink", 2))
        cv.ellipse(cx - 2, h - 9, 4, 3, c("concrete", 1))
        cv.px(cx - 3, h - 11, c("concrete", 3))
    cv.poly([(34, 18), (44, 16), (44, 20), (34, 20)], c("paper", 3))
    cv.outline(c("ink", 0))
    return cv


def bus_stop(seed=11):
    rng = random.Random(seed)
    w, h = 90, 76
    cv = Canvas(w, h)
    cv.rect(2, 4, 3, h - 4, c("metal", 4))
    cv.rect(w - 5, 4, 3, h - 4, c("metal", 4))
    cv.rect(0, 0, w, 6, c("metal", 3))
    cv.hline(0, 0, w, c("metal", 6))
    # cracked glass back panel
    cv.rect(5, 8, w - 10, 44, c("cold", 1))
    for _ in range(3):
        crack(cv, rng.randint(10, w - 10), 10, 30, c("cold", 3), rng, 0.4)
    cv.rect(30, 12, 30, 34, c("paper", 3))  # poster
    cv.rect(33, 15, 24, 18, c("red", 2))
    # bench
    cv.rect(10, 56, w - 20, 3, c("wood", 4))
    cv.rect(14, 59, 2, h - 59, c("metal", 3))
    cv.rect(w - 16, 59, 2, h - 59, c("metal", 3))
    cv.outline(c("ink", 0))
    return cv


def pole_fg(seed=12):
    """Foreground utility pole with sagging wires (silhouette)."""
    w, h = 60, 270
    cv = Canvas(w, h)
    cv.rect(26, 0, 7, h, c("ink", 0))
    cv.vline(32, 0, h, c("concrete", 1))
    cv.rect(10, 30, 40, 3, c("ink", 0))
    for k in (12, 22, 38, 48):
        cv.rect(k, 26, 2, 4, c("concrete", 1))
    return cv


def grass_fg(seed=13):
    frames = grass_frames(seed, 80, 40, 1, 1.3)
    cv = frames[0]
    # turn it into a dark silhouette
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.filled(x, y):
                cv.px(x, y, c("ink", 0) if (x + y) % 5 else c("grass", 0))
    return cv


def blood_decal(seed=14):
    rng = random.Random(seed)
    cv = Canvas(30, 6)
    for k in range(30):
        if rng.random() < 0.7:
            cv.px(k, 3 + rng.randint(-1, 1), c("blood", rng.randint(1, 3)))
    cv.ellipse(12, 3, 6, 2, c("blood", 2))
    return cv


def main():
    tiles().save(f"{OUT}/tiles.png")
    segs = {
        "seg_store": seg_store_exterior(), "seg_shops": seg_shops(), "seg_alley": seg_alley(),
        "seg_apartment": seg_apartment(), "seg_burnt": seg_burnt(), "seg_lot": seg_lot(), "seg_school": seg_school(),
    }
    for k, v in segs.items():
        v.save(f"{OUT}/{k}.png")
    car(1, "sedan", "blue").save(f"{OUT}/car_sedan_blue.png")
    car(2, "sedan", "red").save(f"{OUT}/car_sedan_red.png")
    car_door_open(1, "blue").save(f"{OUT}/car_sedan_blue_open.png")
    car(3, "van", "paper").save(f"{OUT}/car_van.png")
    dumpster(False).save(f"{OUT}/dumpster.png")
    dumpster(True).save(f"{OUT}/dumpster_open.png")
    barrier().save(f"{OUT}/barrier.png")
    make_sheet(fire_barrel_frames()).save(f"{OUT}/fire_barrel.png")
    make_sheet(grass_frames(21)).save(f"{OUT}/grass_a.png")
    make_sheet(grass_frames(22, 56, 30, 4, 1.15)).save(f"{OUT}/grass_b.png")
    make_sheet(grass_frames(23, 32, 20)).save(f"{OUT}/grass_c.png")
    bush(24).save(f"{OUT}/bush.png")
    dead_tree().save(f"{OUT}/dead_tree.png")
    road_sign().save(f"{OUT}/road_sign.png")
    cone().save(f"{OUT}/cone.png")
    trash_bags().save(f"{OUT}/trash_bags.png")
    bus_stop().save(f"{OUT}/bus_stop.png")
    pole_fg().save(f"{OUT}/fg_pole.png")
    grass_fg().save(f"{OUT}/fg_grass.png")
    blood_decal().save(f"{OUT}/blood_decal.png")
    print("street ok")


if __name__ == "__main__":
    main()
