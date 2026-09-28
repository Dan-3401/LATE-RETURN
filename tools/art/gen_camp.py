"""School camp (classroom turned into a home) + the sister."""
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import (Canvas, c, value_noise, crack, stain, drips, speckle, rust_patch,  # noqa: E402
                    text, make_sheet, TRANSPARENT)
from character import Pose, Style, render, stamp, capsule, FW, FH  # noqa: E402
from godot_res import write_sprite_frames  # noqa: E402

OUT = "environment/camp"
W, H = 640, 224


def backwall():
    rng = random.Random(8)
    cv = Canvas(W, H)
    # upper wall: pale green school paint, worn
    n = value_noise(W, H, 22, 3, 4)
    cv.fill_field(0, 0, W, 150, "tile", np.clip(n[:150] * 0.7 + 0.25, 0, 1), lo=3, hi=6)
    # lower wall: darker green dado with a rail
    cv.fill_field(0, 150, W, 62, "tile", n[150:212] * 0.6, lo=2, hi=3)
    cv.rect(0, 148, W, 3, c("wood", 3))
    cv.hline(0, 148, W, c("wood", 5))
    cv.rect(0, 212, W, 12, c("wood", 1))
    cv.hline(0, 212, W, c("wood", 3))
    # ceiling edge & shadow
    cv.rect(0, 0, W, 8, c("tile", 1))
    for y in range(8, 18):
        for x in range(W):
            if rng.random() < 1 - (y - 8) / 10:
                cv.darken(x, y, 0.2)
    # water stains / peeling
    for _ in range(10):
        stain(cv, rng.randint(0, W), rng.randint(10, 140), rng.randint(8, 24), rng.randint(8, 20), 0.18, rng, rng.randint(0, 999), 0, 0, W, 150)
    for _ in range(12):
        drips(cv, rng.randint(0, W), 8, rng.randint(1, 4), rng.randint(20, 70), 0.2, rng)
    for _ in range(8):
        crack(cv, rng.randint(0, W), rng.randint(20, 140), rng.randint(10, 30), c("tile", 1), rng, 0.2)

    # --- chalkboard with tally marks (days), a route map and a note
    bx, by, bw, bh = 150, 40, 200, 86
    cv.rect(bx - 4, by - 4, bw + 8, bh + 10, c("wood", 2))
    cv.hline(bx - 4, by - 4, bw + 8, c("wood", 4))
    nb = value_noise(bw, bh, 10, 5)
    cv.fill_field(bx, by, bw, bh, "grass", nb * 0.35, lo=0, hi=1)
    cv.rect(bx - 6, by + bh + 2, bw + 12, 4, c("wood", 3))  # chalk ledge
    cv.rect(bx + 20, by + bh + 1, 5, 2, c("white", 0))
    # smudged old lesson
    for k in range(6):
        y = by + 8 + k * 7
        for x in range(bx + 110, bx + 110 + rng.randint(30, 70)):
            if rng.random() < 0.35:
                cv.px(x, y + rng.randint(0, 2), c("grass", 2))
    # tally marks in groups of five
    tx, ty = bx + 8, by + 8
    count = 0
    for g in range(9):
        gx = tx + (g % 5) * 18
        gy = ty + (g // 5) * 16
        for m in range(4):
            cv.line(gx + m * 3, gy, gx + m * 3 + 1, gy + 10, c("paper", 5))
        if g < 8:
            cv.line(gx - 2, gy + 8, gx + 12, gy + 2, c("paper", 5))
        count += 1
    # a map: streets + route in red chalk, X at the store, house at school
    mx, my = bx + 10, by + 44
    cv.rect(mx, my, 90, 36, c("grass", 0))
    for k in range(4):
        cv.hline(mx + 2, my + 6 + k * 8, 86, c("paper", 3))
    cv.vline(mx + 30, my + 2, 32, c("paper", 3))
    cv.vline(mx + 64, my + 2, 32, c("paper", 3))
    cv.line(mx + 8, my + 22, mx + 80, my + 14, c("red", 4))
    cv.line(mx + 6, my + 20, mx + 10, my + 24, c("red", 5))
    cv.line(mx + 10, my + 20, mx + 6, my + 24, c("red", 5))
    cv.rect(mx + 78, my + 10, 6, 6, c("paper", 5))
    text(cv, bx + 110, by + 50, "早点回来", c("paper", 4), 12)

    # --- children's drawings on the wall (from before)
    for i, (dx, dy) in enumerate([(26, 50), (60, 44), (100, 58), (380, 46), (560, 52)]):
        cv.rect(dx, dy, 22, 18, c("paper", 5 if i % 2 else 4))
        cv.rect(dx + 2, dy + 12, 18, 4, c("grass", 4))
        cv.disc(dx + 16, dy + 5, 2, c("yellow", 5))
        cv.px(dx + 7, dy + 7, c("red", 4))
        cv.vline(dx + 7, dy + 8, 4, c("blue", 4))
        cv.px(dx + 11, dy + 1, c("metal", 6))
    # a family photo pinned near the bed
    cv.rect(520, 96, 16, 12, c("white", 0))
    cv.rect(521, 97, 14, 8, c("warm", 2))
    for k in range(3):
        cv.vline(524 + k * 4, 100, 5, c("concrete", 2))
    cv.px(528, 95, c("red", 4))

    # --- window (moonlit, cracked, half covered by a curtain)
    wx, wy, ww, wh = 420, 30, 80, 90
    cv.rect(wx - 4, wy - 4, ww + 8, wh + 8, c("wood", 2))
    nwin = value_noise(ww, wh, 16, 9)
    cv.fill_field(wx, wy, ww, wh, "cold", nwin * 0.5 + np.linspace(0.3, 0, wh)[:, None], lo=0, hi=3)
    for sx in range(wx, wx + ww, rng.randint(8, 14)):
        bh_ = rng.randint(10, 35)
        cv.rect(sx, wy + wh - bh_, rng.randint(6, 12), bh_, c("ink", 1))
    cv.disc(wx + 60, wy + 16, 5, c("cold", 5))
    cv.vline(wx + ww // 2, wy, wh, c("wood", 3))
    cv.hline(wx, wy + wh // 2, ww, c("wood", 3))
    crack(cv, wx + 12, wy + 6, 20, c("cold", 5), rng, 0.3)
    cv.rect(wx - 4, wy + wh + 4, ww + 8, 3, c("wood", 4))
    # tape X on a pane
    cv.line(wx + 44, wy + 50, wx + 76, wy + 86, c("paper", 3))
    cv.line(wx + 76, wy + 50, wx + 44, wy + 86, c("paper", 3))

    # --- door (left) — separate sprite, leave frame here
    cv.rect(46, 110, 44, 102, c("wood", 1))
    # --- clock stopped
    cv.disc(386, 30, 7, c("wood", 2))
    cv.disc(386, 30, 6, c("paper", 5))
    cv.line(386, 30, 386, 26, c("ink", 1))
    cv.line(386, 30, 389, 31, c("ink", 1))
    # --- clothesline with laundry across the right side
    cv.line(520, 22, 636, 26, c("paper", 2))
    for i, lx in enumerate([530, 560, 596]):
        col = ["cloth2", "blue", "paper"][i]
        cv.poly([(lx, 23 + i), (lx + 20, 24 + i), (lx + 18, 50 + i * 2), (lx + 2, 48 + i)], c(col, 3))
        cv.hline(lx, 23 + i, 20, c(col, 5))
    return cv


def floor_tiles():
    rng = random.Random(4)
    atlas = Canvas(16 * 8, 16 * 4)
    for row in range(3):
        for v in range(8):
            t = Canvas(16, 16)
            n = value_noise(16, 16, 5, rng.randint(0, 9999))
            # parquet planks
            for y in range(16):
                for x in range(16):
                    plank = ((x + (y // 4) * 5 + v * 3) // 8) % 2
                    base = 3 + plank - (1 if n[y, x] < 0.3 else 0)
                    t.px(x, y, c("wood", base))
            for y in range(0, 16, 4):
                t.hline(0, y, 16, c("wood", 1))
            if row == 0:
                t.hline(0, 0, 16, c("wood", 0))
                t.hline(0, 1, 16, c("wood", 1))
            if v in (2, 5):
                crack(t, rng.randint(2, 13), 1, 10, c("wood", 0), rng, 0.2, dirx=1, diry=0)
            if v == 3:
                stain(t, 8, 8, 5, 3, 0.3, rng, rng.randint(0, 99))
            if row == 2:
                for y in range(8, 16):
                    for x in range(16):
                        t.darken(x, y, (y - 8) / 8 * 0.3)
            atlas.blit(t, v * 16, row * 16)
    for v in range(4):
        t = Canvas(16, 16)
        n = value_noise(16, 16, 6, rng.randint(0, 999))
        t.fill_field(0, 0, 16, 16, "tile", n, lo=1, hi=3)
        t.hline(0, 7, 16, c("tile", 0))
        atlas.blit(t, v * 16, 48)
    return atlas


def door(open_=False):
    w, h = 44, 100
    cv = Canvas(w, h)
    n = value_noise(w, h, 8, 3)
    cv.fill_field(0, 0, w, h, "wood", n, lo=2, hi=4)
    cv.rect(0, 0, w, 2, c("wood", 5))
    cv.rect(6, 8, 32, 30, c("cold", 1))  # small window
    cv.line(8, 10, 34, 36, c("cold", 3))
    cv.rect(34, 52, 4, 3, c("metal", 6))
    for k in range(3):
        cv.hline(4, 60 + k * 12, 36, c("wood", 1))
    if open_:
        cv.rect(0, 0, 14, h, c("ink", 0))
    cv.outline(c("ink", 0))
    return cv


def bedroll():
    rng = random.Random(3)
    w, h = 96, 20
    cv = Canvas(w, h)
    cv.poly([(0, 10), (94, 8), (96, 20), (0, 20)], c("blue", 2))
    for x in range(0, w, 6):
        cv.vline(x, 12, 8, c("blue", 1))
    cv.hline(0, 10, 94, c("blue", 4))
    # pillow
    cv.ellipse(84, 7, 10, 4, c("paper", 4))
    cv.hline(76, 5, 14, c("paper", 5))
    # folded blanket
    cv.poly([(4, 8), (30, 6), (32, 13), (4, 14)], c("red", 2))
    cv.hline(4, 8, 26, c("red", 4))
    cv.outline(c("ink", 0))
    return cv


def desk_table():
    """Two school desks pushed together: lamp, medicine, inhaler, book."""
    w, h = 84, 52
    cv = Canvas(w, h)
    for dx in (0, 42):
        cv.rect(dx, 18, 42, 5, c("wood", 4))
        cv.hline(dx, 18, 42, c("wood", 6))
        cv.rect(dx + 2, 23, 38, 8, c("wood", 2))
        for lx in (dx + 3, dx + 37):
            cv.rect(lx, 23, 2, h - 23, c("metal", 3))
        cv.hline(dx + 3, h - 12, 36, c("metal", 3))
    # medicine bottles + inhaler + blister pack
    cv.rect(40, 11, 5, 7, c("paper", 5))
    cv.rect(40, 10, 5, 2, c("red", 3))
    cv.rect(47, 13, 4, 5, c("warm", 2))
    cv.rect(47, 12, 4, 1, c("paper", 5))
    # inhaler (L shape, blue)
    cv.rect(54, 9, 4, 9, c("blue", 4))
    cv.rect(54, 15, 8, 3, c("blue", 3))
    cv.px(55, 10, c("blue", 5))
    cv.rect(60, 16, 6, 2, c("paper", 4))  # blister
    # book & paper crane
    cv.rect(12, 14, 16, 4, c("red", 2))
    cv.hline(12, 14, 16, c("paper", 4))
    cv.poly([(30, 17), (34, 11), (38, 17)], c("paper", 5))
    cv.outline(c("ink", 0))
    return cv


def lamp():
    """Battery camping lantern (the warm light source)."""
    cv = Canvas(12, 16)
    cv.rect(3, 0, 6, 2, c("metal", 4))
    cv.rect(2, 2, 8, 11, c("warm", 5))
    cv.rect(3, 3, 6, 9, c("warm", 6))
    cv.vline(2, 2, 11, c("metal", 3))
    cv.vline(9, 2, 11, c("metal", 3))
    cv.rect(1, 13, 10, 3, c("metal", 3))
    cv.outline(c("ink", 0))
    return cv


def candle_frames():
    frames = []
    for f in range(3):
        cv = Canvas(6, 14)
        cv.rect(1, 7, 4, 7, c("white", 0))
        cv.vline(1, 7, 7, c("white", 1))
        cv.px(3, 6, c("ink", 1))
        h = [4, 5, 3][f]
        for y in range(h):
            cv.px(2 + (1 if (y + f) % 3 == 0 else 0), 5 - y, c("warm", 6 if y < 2 else 5))
        frames.append(cv)
    return frames


def supplies():
    """Temporary storage: crates, water bottles, cans, a backpack."""
    rng = random.Random(6)
    w, h = 90, 48
    cv = Canvas(w, h)
    # shelf made of planks on bricks
    for ly in (18, 36):
        cv.rect(0, ly, w, 3, c("wood", 4))
        cv.hline(0, ly, w, c("wood", 6))
        for bx in (4, w - 12):
            cv.rect(bx, ly + 3, 8, (18 if ly == 18 else h - ly - 3), c("rust", 2))
    # few items (they don't have much)
    for i, x in enumerate([8, 13, 18]):
        cv.rect(x, 5, 4, 13, c("cold", 4))
        cv.rect(x + 1, 3, 2, 2, c("white", 0))
    for i, x in enumerate([40, 47]):
        cv.rect(x, 10, 6, 8, c("metal", 5))
        cv.rect(x, 12, 6, 4, c("red", 3))
    cv.rect(60, 26, 20, 10, c("wood", 3))  # empty crate
    cv.hline(60, 26, 20, c("wood", 5))
    cv.rect(26, 28, 12, 8, c("yellow", 3))  # biscuit box
    cv.outline(c("ink", 0))
    return cv


def stacked_chairs():
    w, h = 50, 70
    cv = Canvas(w, h)
    for k in range(4):
        y = h - 30 - k * 10
        cv.rect(4 + k * 2, y, 34, 4, c("wood", 3 + (k % 2)))
        cv.rect(4 + k * 2, y - 14, 3, 14, c("metal", 3))
        cv.rect(34 + k * 2, y - 14, 3, 14, c("metal", 3))
    for lx in (6, 36):
        cv.rect(lx, h - 26, 2, 26, c("metal", 3))
    cv.rect(0, h - 30, 48, 4, c("wood", 3))
    cv.outline(c("ink", 0))
    return cv


# ---------------------------------------------------------------------------
# the sister
# ---------------------------------------------------------------------------
HEAD = [
    "..hhhhhh..",
    ".hhhhhhhh.",
    "hhhhhhhhhh",
    "hhhhhhhhHh",
    "hhhhhsssss",
    "hhhhsseSss",
    "hhhhdsssSs",
    "hhhhdssssS",
    "hhh.ddsmd.",
    "hh...ddd..",
    "h.........",
]
HEAD_DOWN = [r.replace("e", "d") for r in HEAD]


def sister_head(cv, nx, ny, tor, pose):
    tpl = HEAD_DOWN if pose.head == "down" else HEAD
    cmap = {"h": c("hair", 1), "H": c("hair", 3), "s": c("skin", 4), "S": c("skin", 5), "d": c("skin", 3),
            "e": c("ink", 1), "m": c("red", 3)}
    dy = 1 if pose.head == "down" else (-1 if pose.head == "up" else 0)
    dx = 1 if pose.head == "down" else 0
    stamp(cv, tpl, int(round(nx - 5 + dx)), int(round(ny - len(tpl) + 1 + dy)), cmap)
    # ponytail over the back
    for k in range(6):
        cv.px(int(round(nx - 6 - (k > 3))), int(round(ny - 7 + k + dy)), c("hair", 1))
    # hair tie
    cv.px(int(round(nx - 5)), int(round(ny - 8 + dy)), c("red", 4))


SISTER = Style(top="cloth2", top_base=3, legs="blue", legs_base=2, boots=("paper", 3), hand=("skin", 4),
               head_fn=sister_head, torso_w=4.2, hip_w=3.6, leg_r=1.8, arm_r=1.5, upper=5.5, fore=5.5,
               thigh=6.0, shin=6.5)


def sit(breath=0, head="normal", torso=6, arms="lap"):
    arm = {"lap": ((30, 70), (20, 80)), "chest": ((20, 100), (10, 110)), "knees": ((50, 60), (40, 70))}[arms]
    return Pose(hip=(21, 41), torso=torso + breath, neck_len=11.5, head=head,
                leg_f=(88, 92), leg_b=(86, 90), arm_f=arm[0], arm_b=arm[1])


def sister_anims():
    return {
        "sit_idle": ([sit(0), sit(0), sit(1), sit(1)], 2, True),
        "sit_down": ([sit(4, "down"), sit(4, "down"), sit(5, "down"), sit(5, "down")], 2, True),
        "sit_up": ([sit(-2, "up"), sit(-2, "up"), sit(-1, "up"), sit(-1, "up")], 2, True),
        "sit_talk": ([sit(0, "up"), sit(1, "normal"), sit(0, "up"), sit(-1, "up")], 3, True),
        "cough": ([sit(10, "down", arms="chest"), sit(16, "down", arms="chest"), sit(8, "down", arms="chest")], 6, False),
        "hug_knees": ([sit(10, "down", arms="knees"), sit(11, "down", arms="knees")], 1, True),
    }


def blanket():
    """Drawn in front of the sister's legs."""
    w, h = 30, 12
    cv = Canvas(w, h)
    cv.poly([(0, 6), (14, 1), (29, 3), (30, 12), (0, 12)], c("red", 2))
    cv.line(0, 6, 14, 1, c("red", 4))
    cv.line(14, 1, 29, 3, c("red", 3))
    for x in range(3, 28, 5):
        cv.vline(x, 5, 6, c("red", 1))
    cv.outline(c("ink", 0))
    return cv


def main():
    backwall().save(f"{OUT}/backwall.png")
    floor_tiles().save(f"{OUT}/tiles.png")
    door(False).save(f"{OUT}/door.png")
    door(True).save(f"{OUT}/door_open.png")
    bedroll().save(f"{OUT}/bedroll.png")
    desk_table().save(f"{OUT}/desk_table.png")
    lamp().save(f"{OUT}/lamp.png")
    make_sheet(candle_frames()).save(f"{OUT}/candle.png")
    supplies().save(f"{OUT}/supplies.png")
    stacked_chairs().save(f"{OUT}/stacked_chairs.png")
    blanket().save(f"{OUT}/blanket.png")
    meta = {}
    frames_all = {}
    for name, (poses, fps, loop) in sister_anims().items():
        frames = [render(SISTER, p) for p in poses]
        frames_all[name] = frames
        make_sheet(frames).save(f"characters/sister/{name}.png")
        meta[name] = {"png": f"characters/sister/{name}.png", "count": len(frames), "fps": fps, "loop": loop}
    write_sprite_frames("characters/sister/sister_frames.tres", meta, FW, FH)
    pdir = os.environ.get("LR_PREVIEW")
    if pdir:
        from PIL import Image
        sheet = Canvas(FW * 4, FH * len(frames_all), fill=(40, 44, 50, 255))
        for r, (n, fr) in enumerate(frames_all.items()):
            for i, f in enumerate(fr):
                sheet.blit(f, i * FW, r * FH)
        bl = blanket()
        for r in range(len(frames_all)):
            for i in range(4):
                sheet.blit(bl, i * FW + 20, r * FH + 36)
        im = Image.fromarray(sheet.a, "RGBA")
        im.resize((im.width * 5, im.height * 5), Image.NEAREST).save(os.path.join(pdir, "sister.png"))
    print("camp ok")


if __name__ == "__main__":
    main()


# ---------------------------------------------------------------------------
# Demo 2: camp storage whose look follows the real stock level (0..3)
# ---------------------------------------------------------------------------
def water_storage(level):
    """Blue water drum + bottles lined up in front (more stock = more bottles)."""
    w, h = 56, 44
    cv = Canvas(w, h)
    # drum
    cv.rect(4, 6, 22, 38, c("blue", 2))
    cv.vline(4, 6, 38, c("blue", 3))
    cv.vline(25, 6, 38, c("blue", 1))
    for y in (14, 28, 40):
        cv.hline(4, y, 22, c("blue", 1))
    cv.ellipse(15, 6, 11, 3, c("blue", 3))
    cv.ellipse(15, 6, 4, 1, c("blue", 1))
    cv.rect(8, 20, 14, 6, c("paper", 4))
    text(cv, 9, 18, "水", c("blue", 2), 12)
    bottles = [0, 2, 5, 8][level]
    for i in range(bottles):
        bx = 28 + (i % 4) * 7
        by = h - 14 - (i // 4) * 14
        cv.rect(bx, by + 3, 5, 11, c("cold", 4))
        cv.rect(bx + 1, by, 3, 3, c("cold", 5))
        cv.px(bx + 1, by - 1, c("white", 0))
        cv.rect(bx, by + 6, 5, 3, c("paper", 5))
    cv.outline(c("ink", 0))
    return cv


def food_storage(level):
    """Wooden crate with the food they have; fuller crate = more food."""
    rng = random.Random(9 + level)
    w, h = 50, 40
    cv = Canvas(w, h)
    cv.rect(0, 14, 50, 26, c("wood", 3))
    for x in range(0, 50, 10):
        cv.vline(x, 14, 26, c("wood", 2))
    cv.hline(0, 14, 50, c("wood", 5))
    cv.hline(0, 27, 50, c("wood", 2))
    text(cv, 4, 18, "粮", c("wood", 1), 12)
    items = [0, 3, 7, 11][level]
    for i in range(items):
        x = 2 + (i * 7) % 44
        y = 13 - (i // 6) * 7
        k = rng.random()
        if k < 0.4:
            cv.rect(x, y - 7, 6, 7, c("metal", 5))
            cv.rect(x, y - 5, 6, 3, c("red", 3))
        elif k < 0.7:
            cv.rect(x, y - 6, 7, 6, c("yellow", 4))
            cv.hline(x, y - 6, 7, c("yellow", 6))
        else:
            cv.poly([(x, y - 7), (x + 6, y - 7), (x + 5, y), (x + 1, y)], c("red", 3))
            cv.hline(x, y - 7, 6, c("paper", 6))
    cv.outline(c("ink", 0))
    return cv


def storage_shelf():
    """The siblings' storage shelf: planks on bricks, plastic bins, cardboard
    boxes, a toolbox, a coil of rope, a spare backpack hanging off the side
    and odds and ends they brought home."""
    rng = random.Random(44)
    w, h = 58, 74
    cv = Canvas(w, h)
    # uprights (stacked bricks) and three plank shelves
    for bx in (2, w - 9):
        for y in range(0, h, 6):
            cv.rect(bx, y, 7, 5, c("rust", 2 + (y // 6) % 2))
            cv.hline(bx, y + 5, 7, c("rust", 1))
    for ly in (22, 46, h - 3):
        cv.rect(0, ly, w, 3, c("wood", 4))
        cv.hline(0, ly, w, c("wood", 6))
    # top: two plastic bins (translucent blue-grey) with things inside
    for bx in (10, 30):
        cv.rect(bx, 8, 18, 14, c("cold", 3))
        cv.hline(bx, 8, 18, c("cold", 5))
        cv.rect(bx + 1, 10, 16, 3, c("cold", 2))
        for k in range(3):
            cv.rect(bx + 2 + k * 5, 11, 3, 2, c(rng.choice(["yellow", "red", "paper"]), 4))
    # middle: cardboard boxes, one open, a toolbox
    cv.rect(10, 30, 16, 16, c("wood", 3))
    cv.hline(10, 30, 16, c("wood", 5))
    cv.rect(16, 30, 4, 16, c("paper", 4))  # tape
    cv.rect(28, 36, 16, 10, c("red", 2))
    cv.hline(28, 36, 16, c("red", 4))
    cv.rect(33, 33, 6, 3, c("metal", 3))   # toolbox handle
    # bottom: rope coil, a wrench, loose cans / soap
    cv.ellipse(18, h - 8, 6, 4, c("wood", 5))
    cv.ellipse(18, h - 8, 3, 2, c("wood", 2))
    cv.line(28, h - 6, 38, h - 10, c("metal", 5))
    cv.rect(38, h - 12, 3, 3, c("metal", 5))
    cv.rect(42, h - 10, 5, 7, c("metal", 5))
    cv.rect(42, h - 8, 5, 2, c("red", 3))
    # spare backpack hanging from the side
    cv.rect(w - 6, 26, 6, 16, c("jacket", 3))
    cv.rect(w - 6, 26, 6, 3, c("jacket", 5))
    cv.px(w - 4, 24, c("ink", 1))
    cv.px(w - 4, 25, c("ink", 1))
    cv.outline(c("ink", 0))
    return cv


def storage_main():
    for lv in range(4):
        water_storage(lv).save(f"{OUT}/water_storage_{lv}.png")
        food_storage(lv).save(f"{OUT}/food_storage_{lv}.png")
    storage_shelf().save(f"{OUT}/storage_shelf.png")


if __name__ == "__main__":
    storage_main()
