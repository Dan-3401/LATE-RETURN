"""Near-camera foreground pieces for every main map.

Two kinds:
  * sharp  — pixel-art silhouettes between the player and the camera
             (Foreground layer, parallax ~1.25-1.3). Palette-quantised.
  * blur   — objects almost touching the lens (Foreground Blur layer,
             faster parallax). Drawn as pixel shapes, then upscaled x2,
             Gaussian-blurred and lowered in contrast. They are displayed
             with LINEAR filtering; only these pieces are allowed to be soft.

Everything is dark (the camera looks out of the shadows), with a faint rim
of the scene's ambient colour. No green: green is reserved for hide spots.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import ART, Canvas, c  # noqa: E402

OUT = "environment/foreground"


def save_blur(cv, name, radius=3.0, lift=(22, 24, 32), contrast=0.7, alpha=0.92):
    im = Image.fromarray(cv.a, "RGBA").resize((cv.w * 2, cv.h * 2), Image.NEAREST)
    # blur premultiplied so the dark colour does not bleed into transparent black
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb = a[:, :, :3] * a[:, :, 3:4]
    pm = np.concatenate([rgb, a[:, :, 3:4]], axis=2)
    pm_im = Image.fromarray((pm * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(radius))
    b = np.asarray(pm_im).astype(np.float32) / 255.0
    al = b[:, :, 3:4]
    col = np.where(al > 1e-4, b[:, :, :3] / np.maximum(al, 1e-4), 0.0)
    lift_c = np.array(lift, dtype=np.float32) / 255.0
    col = lift_c + (col - lift_c) * contrast
    out = np.concatenate([np.clip(col, 0, 1), np.clip(al * alpha, 0, 1)], axis=2)
    path = os.path.join(ART, OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray((out * 255).astype(np.uint8), "RGBA").save(path)


# --- store ------------------------------------------------------------------------
def store_curtain(rng):
    """Plastic strip curtain hanging from the top of the frame (cold rim)."""
    w, h = 74, 128
    cv = Canvas(w, h)
    cv.rect(0, 0, w, 5, c("ink", 0))
    cv.hline(0, 5, w, c("metal", 2))
    x = 2
    while x < w - 6:
        sw = rng.randint(6, 9)
        ln = rng.randint(70, h - 1)
        sway = rng.uniform(-3, 3)
        for y in range(6, ln):
            off = int(sway * (y / ln) ** 2)
            cv.rect(x + off, y, sw - 1, 1, c("cold", 0))
            cv.px(x + off, y, c("cold", 2))
            if y % 23 == 0:
                cv.px(x + off + sw // 2, y, c("cold", 3))
        # torn strip ends
        cv.px(x + int(sway), ln, c("cold", 1))
        x += sw + rng.randint(0, 3)
    return cv


def store_ad(rng):
    """Broken ad board hanging askew on two wires."""
    w, h = 96, 76
    cv = Canvas(w, h)
    cv.line(20, 0, 22, 30, c("ink", 1))
    cv.line(76, 0, 80, 20, c("ink", 1))
    pts = [(8, 32), (86, 20), (92, 56), (14, 70)]
    cv.poly(pts, c("ink", 0))
    inner = [(14, 36), (82, 25), (86, 52), (18, 64)]
    cv.poly(inner, c("red", 0))
    for k in range(6):
        cv.line(22 + k * 9, 44 - k, 30 + k * 9, 42 - k, c("yellow", 0))
    # a torn corner
    cv.poly([(70, 48), (92, 56), (84, 62)], (0, 0, 0, 0))
    for i in range(len(pts)):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % len(pts)]
        cv.line(x0, y0, x1, y1, c("metal", 1))
    return cv


def near_shelf(rng):
    """Shelf edge almost touching the lens (blur layer)."""
    w, h = 64, 150
    cv = Canvas(w, h)
    cv.rect(w - 14, 0, 14, h, c("ink", 0))
    for ly in (18, 64, 110):
        cv.rect(0, ly, w, 6, c("ink", 1))
        for k in range(3):
            bx = rng.randint(2, w - 26)
            bh = rng.randint(10, 22)
            cv.rect(bx, ly - bh, rng.randint(8, 14), bh, c("concrete", 1))
    return cv


# --- street -----------------------------------------------------------------------
def street_sign(rng):
    """Road sign on its pole, very close to the camera (sharp)."""
    w, h = 64, 270
    cv = Canvas(w, h)
    cv.rect(29, 60, 6, h - 60, c("ink", 0))
    cv.vline(34, 60, h - 60, c("metal", 1))
    cv.rect(4, 20, 56, 40, c("ink", 0))
    cv.rect(7, 23, 50, 34, c("blue", 0))
    cv.hline(7, 23, 50, c("blue", 2))
    # arrow + faded school pictogram
    cv.rect(14, 38, 20, 3, c("cold", 2))
    cv.poly([(34, 34), (42, 39), (34, 45)], c("cold", 2))
    cv.disc(48, 32, 2, c("cold", 1))
    cv.rect(46, 35, 4, 8, c("cold", 1))
    for k in range(3):
        cv.px(rng.randint(8, 54), rng.randint(25, 55), c("rust", 2))
    # bent corner
    cv.poly([(50, 56), (60, 50), (60, 60)], c("ink", 1))
    return cv


def street_fence(rng):
    """Leaning chain-link fence section with dead (brown) vines."""
    w, h = 136, 84
    cv = Canvas(w, h)
    cv.rect(2, 6, 4, h - 6, c("ink", 0))
    cv.rect(w - 8, 14, 4, h - 14, c("ink", 0))
    cv.line(4, 6, w - 6, 14, c("metal", 1))
    for x in range(6, w - 8, 6):
        top = 7 + int((x / w) * 8)
        for y in range(top, h, 6):
            cv.px(x, y, c("metal", 0))
            cv.px(x + 3, y + 3, c("metal", 0))
    for k in range(5):
        x = rng.randint(6, w - 12)
        y = h - 1
        for s in range(rng.randint(20, 50)):
            cv.px(x, y, c("wood", 1))
            if s % 7 == 3:
                cv.px(x + 1, y, c("wood", 2))
            x += rng.choice([-1, 0, 0, 1])
            y -= 1
    return cv


def street_branch(rng):
    """Branch hanging into the frame from the top (blur layer)."""
    w, h = 170, 104
    cv = Canvas(w, h)

    def limb(x, y, ang, ln, width, depth):
        for i in range(ln):
            nx = x + math.cos(ang)
            ny = y + math.sin(ang)
            cv.rect(int(x), int(y), width, width, c("ink", 0))
            x, y = nx, ny
            ang += rng.uniform(-0.06, 0.06)
            if depth < 3 and i > 6 and rng.random() < 0.08:
                limb(x, y, ang + rng.choice([-0.7, 0.7]), ln // 2, max(1, width - 1), depth + 1)
        # clumps of dry leaves
        for k in range(6):
            cv.ellipse(int(x) + rng.randint(-6, 6), int(y) + rng.randint(-4, 4), rng.randint(3, 6), rng.randint(2, 4), c("wood", 0))

    limb(-2, 4, 0.32, 120, 4, 0)
    limb(40, 0, 1.1, 60, 2, 1)
    return cv


def near_car(rng):
    """Front corner of a wrecked car right in front of the lens (blur)."""
    w, h = 170, 64
    cv = Canvas(w, h)
    cv.poly([(0, 20), (40, 8), (120, 6), (170, 22), (170, h), (0, h)], c("ink", 0))
    cv.hline(40, 9, 80, c("metal", 1))
    cv.ellipse(46, h - 4, 18, 12, c("ink", 1))
    cv.rect(130, 26, 26, 8, c("metal", 0))
    return cv


# --- camp -----------------------------------------------------------------------------
def camp_curtain(rng):
    """Heavy cloth curtain hanging at the frame edge."""
    w, h = 58, 210
    cv = Canvas(w, h)
    cv.rect(0, 0, w, 4, c("wood", 0))
    for x in range(0, w - 6):
        fold = math.sin(x / 5.5) * 0.5 + 0.5
        ln = h - int(abs(math.sin(x / 13.0)) * 30)
        idx = 0 if fold < 0.45 else 1
        cv.vline(x, 4, ln - 4, c("cloth2", idx))
        if fold > 0.85:
            cv.vline(x, 4, ln - 4, c("cloth2", 2))
    return cv


def camp_laundry(rng):
    """A line of washing strung across the classroom (from the top)."""
    w, h = 176, 78
    cv = Canvas(w, h)
    sag = [int(8 + 10 * math.sin(math.pi * x / w)) for x in range(w)]
    for x in range(w):
        cv.px(x, sag[x], c("ink", 1))
    x = 12
    for k, (ramp, cw, ch) in enumerate([("cloth2", 22, 34), ("denim", 18, 44), ("paper", 26, 22), ("red", 16, 30), ("cloth2", 24, 40)]):
        top = sag[min(x + cw // 2, w - 1)]
        cv.rect(x, top, cw, ch, c(ramp, 0))
        cv.hline(x, top, cw, c(ramp, 2))
        if ramp == "denim":
            cv.rect(x + cw // 2 - 1, top + ch // 2, 2, ch // 2, (0, 0, 0, 0))
        cv.px(x + 2, top - 1, c("wood", 3))
        cv.px(x + cw - 3, top - 1, c("wood", 3))
        x += cw + rng.randint(6, 14)
    return cv


def near_chair(rng):
    """School chair right in front of the camera (blur)."""
    w, h = 80, 92
    cv = Canvas(w, h)
    cv.rect(8, 10, 6, 82, c("ink", 0))
    cv.rect(8, 10, 44, 24, c("wood", 0))
    cv.rect(8, 50, 64, 6, c("wood", 0))
    cv.rect(62, 50, 5, 42, c("ink", 0))
    cv.rect(30, 56, 4, 36, c("ink", 0))
    return cv


def door_frame(rng):
    """Door frame / wall edge at the side of the frame (sharp)."""
    w, h = 26, 270
    cv = Canvas(w, h)
    cv.rect(0, 0, 18, h, c("ink", 0))
    cv.rect(18, 0, 6, h, c("wood", 0))
    cv.vline(23, 0, h, c("wood", 2))
    for y in range(0, h, 37):
        cv.hline(18, y, 6, c("wood", 1))
    return cv


# --- warehouse --------------------------------------------------------------------------
def chain(rng):
    """Hanging chain with a hook (sharp)."""
    w, h = 16, 112
    cv = Canvas(w, h)
    for y in range(0, h - 12, 5):
        if (y // 5) % 2:
            cv.rect(6, y, 4, 6, c("metal", 1))
            cv.rect(7, y + 1, 2, 4, (0, 0, 0, 0))
        else:
            cv.rect(7, y, 2, 6, c("metal", 0))
    cv.rect(7, h - 12, 2, 8, c("metal", 1))
    cv.rect(3, h - 6, 6, 2, c("metal", 1))
    cv.rect(3, h - 9, 2, 3, c("metal", 1))
    return cv


def near_boxes(rng):
    """Stack of boxes almost at the lens (blur)."""
    w, h = 130, 96
    cv = Canvas(w, h)
    cv.rect(0, 40, 70, 56, c("wood", 0))
    cv.rect(58, 16, 60, 80, c("wood", 1))
    cv.rect(10, 8, 40, 32, c("wood", 0))
    for x0, y0, bw in [(0, 40, 70), (58, 16, 60), (10, 8, 40)]:
        cv.hline(x0, y0, bw, c("wood", 3))
        cv.rect(x0 + bw // 2 - 3, y0, 6, 8, c("paper", 1))
    return cv


def main():
    rng = random.Random(21)
    sharp = {
        "store_curtain": store_curtain, "store_ad": store_ad,
        "street_sign": street_sign, "street_fence": street_fence,
        "camp_curtain": camp_curtain, "camp_laundry": camp_laundry, "door_frame": door_frame,
        "chain": chain,
    }
    for name, fn in sharp.items():
        fn(rng).save(f"{OUT}/{name}.png")
    blur = {
        "store_shelf_blur": near_shelf, "street_branch_blur": street_branch, "street_car_blur": near_car,
        "camp_chair_blur": near_chair, "boxes_blur": near_boxes,
    }
    for name, fn in blur.items():
        save_blur(fn(rng), f"{name}.png")
    print("foreground ok")


if __name__ == "__main__":
    main()
