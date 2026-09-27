"""UI art: cursors, panels, bubble, item icons, logo, app icon."""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, c, text, FONT_PATH, stain, crack, TRANSPARENT  # noqa: E402

OUT = "ui"


def cursors():
    a = Canvas(8, 10)
    shape = [
        "X.......",
        "XX......",
        "XWX.....",
        "XWWX....",
        "XWWWX...",
        "XWWWWX..",
        "XWWXXX..",
        "XXWX....",
        "X.XWX...",
        "...XX...",
    ]
    for y, r in enumerate(shape):
        for x, ch in enumerate(r):
            if ch == "X":
                a.px(x, y, c("ink", 0))
            elif ch == "W":
                a.px(x, y, c("paper", 5))
    a.save(f"{OUT}/cursor_arrow.png")
    x = Canvas(11, 11)
    col = c("paper", 6)
    dark = c("ink", 0)
    for i in (0, 1, 2):
        for (px_, py_) in [(5, i), (5, 10 - i), (i, 5), (10 - i, 5)]:
            x.px(px_, py_, col)
    x.px(5, 5, c("red", 5))
    x.outline(dark)
    # shrink canvas back (outline may add a ring) — keep 11x11 centred
    x.save(f"{OUT}/crosshair.png")
    blank = Canvas(1, 1)
    blank.save(f"{OUT}/cursor_blank.png")


def ninepatch(name, w, h, fill, border, highlight=None, alpha=None, corner_cut=True):
    cv = Canvas(w, h)
    cv.rect(1, 1, w - 2, h - 2, fill)
    cv.rect(1, 0, w - 2, 1, border)
    cv.rect(1, h - 1, w - 2, 1, border)
    cv.rect(0, 1, 1, h - 2, border)
    cv.rect(w - 1, 1, 1, h - 2, border)
    if highlight:
        cv.hline(2, 1, w - 4, highlight)
    if not corner_cut:
        for (xx, yy) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
            cv.px(xx, yy, border)
    cv.save(f"{OUT}/{name}.png")
    if alpha is not None:
        im = Image.open(os.path.join(os.path.dirname(__file__), "..", "..", "art", OUT, name + ".png")).convert("RGBA")
        arr = np.array(im)
        mask = arr[:, :, 3] > 0
        inner = np.zeros_like(mask)
        inner[1:-1, 1:-1] = True
        arr[:, :, 3] = np.where(mask & inner, int(alpha * 255), arr[:, :, 3])
        # border pixels remain opaque
        Image.fromarray(arr).save(os.path.join(os.path.dirname(__file__), "..", "..", "art", OUT, name + ".png"))


def panels():
    ninepatch("bubble", 8, 8, c("ink", 2), c("concrete", 5), alpha=0.82)
    ninepatch("prompt", 8, 8, c("ink", 1), c("concrete", 4), alpha=0.72)
    ninepatch("panel", 12, 12, c("ink", 2), c("concrete", 4), highlight=c("concrete", 2), alpha=0.92)
    ninepatch("slot", 8, 8, c("concrete", 0), c("concrete", 3), alpha=0.9)
    ninepatch("slot_focus", 8, 8, c("concrete", 1), c("paper", 4), alpha=0.95)
    ninepatch("button_focus", 8, 8, c("concrete", 1), c("paper", 3), alpha=0.6)
    tail = Canvas(5, 4)
    rows = ["XWWWX", ".XWX.", "..X..", "....."]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == "X":
                tail.px(x, y, c("concrete", 5))
            elif ch == "W":
                tail.px(x, y, c("ink", 2))
    tail.save(f"{OUT}/bubble_tail.png")
    im_path = os.path.join(os.path.dirname(__file__), "..", "..", "art", OUT, "bubble_tail.png")
    arr = np.array(Image.open(im_path).convert("RGBA"))
    ink = np.array(c("ink", 2)[:3])
    m = (arr[:, :, :3] == ink).all(axis=2) & (arr[:, :, 3] > 0)
    arr[:, :, 3] = np.where(m, int(0.82 * 255), arr[:, :, 3])
    Image.fromarray(arr).save(im_path)


# ---------------------------------------------------------------------------
# Item icons (16x16)
# ---------------------------------------------------------------------------
def icon(name, fn):
    cv = Canvas(16, 16)
    fn(cv)
    cv.outline(c("ink", 0))
    cv.save(f"{OUT}/icons/{name}.png")


def i_water(cv):
    cv.rect(6, 1, 4, 2, c("cold", 5))
    cv.rect(5, 3, 6, 2, c("cold", 4))
    cv.rect(4, 5, 8, 10, c("cold", 4))
    cv.vline(4, 5, 10, c("cold", 5))
    cv.vline(11, 5, 10, c("cold", 2))
    cv.rect(4, 8, 8, 4, c("paper", 5))
    cv.hline(5, 9, 6, c("blue", 4))
    cv.px(6, 6, c("white", 1))
    cv.px(6, 1, c("white", 0))


def i_food_can(cv):
    cv.rect(3, 4, 10, 10, c("metal", 5))
    cv.hline(3, 4, 10, c("metal", 7))
    cv.hline(3, 13, 10, c("metal", 3))
    cv.rect(3, 6, 10, 6, c("red", 3))
    cv.rect(5, 7, 6, 3, c("paper", 5))
    cv.px(6, 8, c("red", 2))
    cv.vline(12, 5, 8, c("metal", 2))
    cv.hline(4, 3, 8, c("metal", 6))


def i_biscuit(cv):
    cv.poly([(2, 5), (14, 3), (15, 11), (3, 13)], c("yellow", 4))
    cv.line(2, 5, 14, 3, c("yellow", 6))
    cv.rect(5, 6, 6, 3, c("red", 3))
    cv.px(7, 7, c("paper", 6))
    cv.line(3, 13, 15, 11, c("yellow", 2))


def i_noodle(cv):
    cv.poly([(3, 4), (13, 4), (12, 14), (4, 14)], c("red", 3))
    cv.rect(3, 3, 10, 2, c("paper", 6))
    cv.rect(5, 7, 6, 3, c("paper", 5))
    cv.px(7, 8, c("yellow", 5))
    cv.vline(12, 5, 8, c("red", 1))


def i_parts(cv):
    # gear + screw
    cx, cy = 7, 8
    cv.disc(cx, cy, 5, c("metal", 5))
    for a in range(0, 360, 45):
        cv.px(int(cx + math.cos(math.radians(a)) * 6), int(cy + math.sin(math.radians(a)) * 6), c("metal", 5))
    cv.disc(cx, cy, 2, c("metal", 2))
    cv.px(cx - 2, cy - 3, c("metal", 7))
    cv.line(11, 11, 14, 14, c("metal", 6))
    cv.px(10, 10, c("metal", 7))
    cv.px(11, 12, c("rust", 4))


def i_empty_bottle(cv):
    cv.rect(6, 1, 3, 3, c("green", 3))
    cv.rect(5, 4, 5, 11, c("green", 2))
    cv.vline(5, 5, 9, c("green", 4))
    cv.px(6, 6, c("green", 5))


def i_junk(cv):
    cv.poly([(2, 9), (7, 4), (13, 6), (14, 12), (6, 14)], c("paper", 3))
    cv.line(7, 4, 10, 10, c("paper", 1))
    cv.line(3, 10, 12, 9, c("paper", 5))
    cv.px(9, 7, c("red", 3))


def i_cash(cv):
    for k, (dx, dy) in enumerate([(1, 7), (2, 5), (3, 3)]):
        cv.rect(dx, dy, 12, 7, c("green", 1 + k))
        cv.hline(dx, dy, 12, c("green", 3 + k))
        cv.disc(dx + 6, dy + 3, 1.5, c("green", k))
    cv.rect(7, 3, 2, 7, c("paper", 5))


def i_pistol(cv):
    cv.rect(2, 4, 12, 3, c("metal", 4))
    cv.hline(2, 4, 12, c("metal", 6))
    cv.rect(4, 7, 4, 7, c("metal", 2))
    cv.vline(4, 7, 7, c("metal", 3))
    cv.px(9, 8, c("metal", 3))
    cv.px(10, 7, c("metal", 3))
    cv.px(13, 5, c("ink", 1))


def i_knife(cv):
    cv.line(3, 13, 6, 10, c("wood", 3), 1)
    cv.line(4, 13, 7, 10, c("wood", 2), 1)
    cv.hline(6, 10, 3, c("metal", 3))
    cv.line(8, 9, 14, 2, c("metal", 7))
    cv.line(8, 8, 13, 2, c("metal", 5))
    cv.line(9, 9, 14, 3, c("metal", 4))


def i_backpack(cv):
    cv.rect(3, 4, 10, 11, c("wood", 4))
    cv.rect(4, 2, 8, 3, c("wood", 5))
    cv.rect(5, 9, 6, 4, c("wood", 3))
    cv.hline(5, 9, 6, c("wood", 5))
    cv.px(8, 11, c("metal", 6))
    cv.vline(12, 5, 9, c("wood", 2))


def i_helmet(cv):
    cv.ellipse(8, 9, 6, 5, c("concrete", 2))
    cv.rect(2, 9, 13, 5, TRANSPARENT)
    cv.hline(1, 9, 14, c("concrete", 2))


def i_armor(cv):
    cv.poly([(3, 3), (6, 3), (8, 5), (10, 3), (13, 3), (13, 14), (3, 14)], c("concrete", 2))


def i_ammo(cv):
    for k in range(3):
        x = 3 + k * 4
        cv.rect(x, 5, 3, 9, c("yellow", 4))
        cv.rect(x, 3, 3, 3, c("rust", 5))
        cv.vline(x, 5, 9, c("yellow", 6))


def i_bandage(cv):
    cv.rect(2, 5, 12, 7, c("paper", 5))
    cv.rect(6, 5, 4, 7, c("paper", 6))
    cv.rect(7, 7, 2, 3, c("red", 4))


def i_key(cv):
    cv.disc(4, 5, 3, c("yellow", 4))
    cv.disc(4, 5, 1, TRANSPARENT)
    cv.px(3, 3, c("yellow", 6))
    cv.rect(7, 5, 7, 2, c("yellow", 4))
    cv.hline(7, 5, 7, c("yellow", 6))
    cv.rect(11, 7, 1, 2, c("yellow", 3))
    cv.rect(13, 7, 1, 3, c("yellow", 3))
    # paper tag on a string
    cv.line(4, 8, 5, 11, c("paper", 3))
    cv.rect(3, 11, 5, 4, c("paper", 5))
    cv.hline(4, 13, 3, c("ink", 2))


def i_uniform(cv):
    cv.poly([(4, 2), (7, 3), (9, 3), (12, 2), (15, 6), (13, 8), (12, 7), (12, 15), (4, 15), (4, 7), (3, 8), (1, 6)], c("green", 2))
    cv.line(8, 3, 8, 15, c("green", 1))
    cv.rect(5, 9, 3, 2, c("green", 4))
    cv.rect(9, 9, 3, 2, c("green", 4))
    cv.rect(9, 5, 2, 2, c("paper", 5))
    cv.hline(5, 3, 2, c("green", 4))


def i_soap(cv):
    cv.rect(3, 7, 10, 6, c("blue", 4))
    cv.hline(3, 7, 10, c("blue", 5))
    cv.rect(5, 9, 6, 2, c("paper", 5))
    cv.rect(6, 3, 4, 4, c("white", 1))
    cv.rect(7, 2, 2, 1, c("red", 3))


def icons():
    for n, f in [("water", i_water), ("canned_food", i_food_can), ("biscuits", i_biscuit), ("noodles", i_noodle),
                 ("parts", i_parts), ("empty_bottle", i_empty_bottle), ("junk", i_junk), ("cash", i_cash),
                 ("pistol", i_pistol), ("knife", i_knife), ("backpack", i_backpack), ("helmet", i_helmet),
                 ("armor", i_armor), ("ammo", i_ammo), ("bandage", i_bandage),
                 ("warehouse_key", i_key), ("work_uniform", i_uniform), ("soap", i_soap)]:
        icon(n, f)


def hud_icons():
    # footprint (sneak), lungs (oxygen), bullet (ammo), heart-ish (hp)
    def foot(cv):
        cv.ellipse(3, 6, 2, 3, c("paper", 4))
        cv.px(2, 1, c("paper", 4))
        cv.px(4, 1, c("paper", 4))
        cv.ellipse(8, 4, 2, 3, c("paper", 3))
        cv.px(7, 0, c("paper", 3))
    cv = Canvas(12, 10)
    foot(cv)
    cv.save(f"{OUT}/hud_sneak.png")
    cv = Canvas(5, 9)
    cv.rect(1, 3, 3, 6, c("yellow", 4))
    cv.rect(1, 1, 3, 2, c("rust", 5))
    cv.px(2, 0, c("rust", 5))
    cv.vline(1, 3, 6, c("yellow", 6))
    cv.save(f"{OUT}/hud_bullet.png")
    cv = Canvas(9, 8)
    for (x, y) in [(1, 0), (2, 0), (6, 0), (7, 0)]:
        cv.px(x, y, c("red", 4))
    cv.rect(0, 1, 9, 3, c("red", 4))
    cv.rect(1, 4, 7, 1, c("red", 4))
    cv.rect(2, 5, 5, 1, c("red", 4))
    cv.rect(3, 6, 3, 1, c("red", 4))
    cv.px(4, 7, c("red", 4))
    cv.px(1, 1, c("red", 5))
    cv.save(f"{OUT}/hud_heart.png")


# ---------------------------------------------------------------------------
# Logo: 迟归 rendered from the pixel font, scaled up by 4 into eroded blocks.
# ---------------------------------------------------------------------------
def logo():
    f = ImageFont.truetype(FONT_PATH, 12)
    s = "迟归"
    bbox = f.getbbox(s)
    w, h = bbox[2] + 1, bbox[3] + 1
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).text((0, 0), s, font=f, fill=255)
    m = np.array(im)[bbox[1]:, :] > 127
    S = 4
    rng = random.Random(11)
    H, W = m.shape
    cv = Canvas(W * S + 8, H * S + 8)
    for y in range(H):
        for x in range(W):
            if m[y, x]:
                for yy in range(S):
                    for xx in range(S):
                        px_, py_ = 4 + x * S + xx, 4 + y * S + yy
                        col = c("paper", 5)
                        if yy == 0 and (y == 0 or not m[y - 1, x]):
                            col = c("paper", 6)
                        elif yy == S - 1 and (y == H - 1 or not m[y + 1, x]):
                            col = c("paper", 3)
                        elif xx == S - 1 and (x == W - 1 or not m[y, x + 1]):
                            col = c("paper", 4)
                        cv.px(px_, py_, col)
    # erosion: knock out pixels near edges, add cracks and grime
    for _ in range(140):
        x = rng.randrange(cv.w)
        y = rng.randrange(cv.h)
        if cv.filled(x, y):
            edge = not (cv.filled(x - 1, y) and cv.filled(x + 1, y) and cv.filled(x, y - 1) and cv.filled(x, y + 1))
            if edge and rng.random() < 0.6:
                cv.px(x, y, TRANSPARENT)
            else:
                cv.px(x, y, c("paper", 3))
    for _ in range(5):
        x0 = rng.randrange(8, cv.w - 8)
        y0 = rng.randrange(6, cv.h - 6)
        for k in range(rng.randint(3, 6)):
            if cv.filled(x0 + k, y0 + (k // 2)):
                cv.px(x0 + k, y0 + (k // 2), c("paper", 2))
    for y in range(cv.h):
        for x in range(cv.w):
            if cv.filled(x, y) and y > cv.h * 0.6 and rng.random() < 0.25:
                cv.darken(x, y, 0.2)
    # a small red drip from the second glyph
    # drip from the lowest stroke pixel of the second glyph
    dx = None
    for x in range(cv.w - 1, cv.w // 2, -1):
        for y in range(cv.h - 1, 0, -1):
            if cv.filled(x, y) and x % 4 == 1:
                if dx is None or y > dx[1]:
                    dx = (x, y)
                break
    if dx:
        for k in range(1, 8):
            cv.px(dx[0], dx[1] + k, c("red", 3 if k < 5 else 2))
        cv.px(dx[0], dx[1], c("red", 3))
    shadow = cv.copy()
    out = Canvas(cv.w + 2, cv.h + 2)
    for y in range(shadow.h):
        for x in range(shadow.w):
            if shadow.filled(x, y):
                out.px(x + 2, y + 2, c("ink", 0))
    out.blit(cv, 0, 0)
    out.outline(c("ink", 0))
    out.save(f"{OUT}/logo.png")
    # small logo for loading screen (x2)
    S2 = 2
    sm = Canvas(W * S2 + 4, H * S2 + 4)
    for y in range(H):
        for x in range(W):
            if m[y, x]:
                sm.rect(2 + x * S2, 2 + y * S2, S2, S2, c("paper", 4))
    sm.outline(c("ink", 0))
    sm.save(f"{OUT}/logo_small.png")


def app_icon():
    cv = Canvas(64, 64, fill=c("ink", 1))
    im = Image.open(os.path.join(os.path.dirname(__file__), "..", "..", "art", OUT, "logo_small.png")).convert("RGBA")
    arr = np.array(im)
    ox = (64 - arr.shape[1]) // 2
    oy = (64 - arr.shape[0]) // 2
    for y in range(arr.shape[0]):
        for x in range(arr.shape[1]):
            if arr[y, x, 3] > 0:
                cv.px(ox + x, oy + y, tuple(int(v) for v in arr[y, x]))
    cv.hline(10, 50, 44, c("warm", 3))
    cv.save(f"{OUT}/icon.png")


if __name__ == "__main__":
    cursors()
    panels()
    icons()
    hud_icons()
    logo()
    app_icon()
    print("ui ok")


def vignette():
    """Alpha vignette (white, alpha grows toward edges) — tinted in engine."""
    w, h = 160, 90
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    from pixlib import BAYER4
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            dy = (y + 0.5 - h / 2) / (h / 2)
            d = math.sqrt(dx * dx * 0.8 + dy * dy * 1.0)
            v = max(0.0, (d - 0.55) / 0.6)
            v = math.floor(min(1.0, v) * 5 + BAYER4[y % 4, x % 4] * 0.8) / 5
            arr[y, x] = (255, 255, 255, int(max(0, min(1, v)) * 255))
    Image.fromarray(arr, "RGBA").save(os.path.join(os.path.dirname(__file__), "..", "..", "art", OUT, "vignette.png"))


if __name__ == "__main__":
    vignette()


# ---------------------------------------------------------------------------
# Demo 2: region map, diary paper
# ---------------------------------------------------------------------------
def aged_paper(w, h, seed, base=5, folds=True):
    """Old paper: uneven tone, darker edges, creases, cup ring, water marks.
    All darkening tints toward warm browns so quantisation stays in the paper hues."""
    rng = random.Random(seed)
    cv = Canvas(w, h)
    from pixlib import value_noise
    n = value_noise(w, h, 22, seed, 4)
    cv.fill_field(0, 0, w, h, "paper", np.clip(n * 0.6 + 0.35, 0, 1), lo=base - 2, hi=base)
    brown = c("wood", 5)
    dark = c("paper", 2)

    def pd(x, y, a):
        cv.tint(x, y, dark, min(1.0, a))

    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d < 7 and rng.random() < (7 - d) / 8:
                pd(x, y, 0.25 + (7 - d) * 0.08)
    cv.poly([(w - 14, 0), (w, 0), (w, 11)], TRANSPARENT)
    for x in range(0, w, 3):
        if rng.random() < 0.3:
            cv.px(x, h - 1, TRANSPARENT)
    if folds:
        fx, fy = w // 2 + rng.randint(-6, 6), h // 2 + rng.randint(-4, 4)
        for y in range(h):
            pd(fx, y, 0.45)
            cv.tint(fx + 1, y, c("paper", 6), 0.5)
        for x in range(w):
            pd(x, fy, 0.4)
            cv.tint(x, fy + 1, c("paper", 6), 0.45)
    # cup ring
    cx, cy, r = rng.randint(30, w - 30), rng.randint(30, h - 30), 13
    for a in range(0, 360, 3):
        for dr in (0, 1):
            x = int(cx + math.cos(math.radians(a)) * (r + dr))
            y = int(cy + math.sin(math.radians(a)) * (r + dr) * 0.9)
            if rng.random() < 0.75:
                cv.tint(x, y, brown, 0.45)
    # water / dirt marks
    for _ in range(6):
        sx, sy = rng.randint(0, w), rng.randint(0, h)
        rx, ry = rng.randint(6, 16), rng.randint(4, 10)
        nn = value_noise(rx * 2 + 3, ry * 2 + 3, 3, rng.randint(0, 999), 2)
        for yy in range(-ry, ry + 1):
            for xx in range(-rx, rx + 1):
                dd = (xx / rx) ** 2 + (yy / ry) ** 2
                if dd < 0.6 + nn[yy + ry, xx + rx] * 0.5:
                    edge = 0.35 if dd > 0.7 else 0.18
                    cv.tint(sx + xx, sy + yy, brown, edge)
    return cv


def diary_paper():
    w, h = 300, 214
    cv = aged_paper(w, h, 17)
    # faint ruled lines and a margin, like a school exercise book
    for y in range(40, h - 10, 18):
        for x in range(10, w - 10):
            if x % 3 != 0:
                cv.px(x, y, c("paper", 3))
    for y in range(8, h - 6):
        cv.tint(34, y, c("red", 4), 0.45)
    # binding holes
    for y in (24, 104, 184):
        cv.disc(12, y, 3, TRANSPARENT)
    cv.save(f"{OUT}/diary_paper.png", ramps=["paper", "wood", "red", "blue", "ink"])


def region_map():
    """A hand-marked city map: streets, the river, route traces, circled places."""
    rng = random.Random(23)
    w, h = 400, 236
    cv = aged_paper(w, h, 29, base=5)
    ink = c("wood", 1)
    faint = c("paper", 2)
    # river
    pts = [(0, 150), (60, 140), (120, 160), (200, 150), (280, 170), (400, 158)]
    for i in range(len(pts) - 1):
        for k in range(-4, 5):
            cv.line(pts[i][0], pts[i][1] + k, pts[i + 1][0], pts[i + 1][1] + k, c("cold", 4) if abs(k) < 3 else c("cold", 3))
    # street grid (slightly irregular, hand drawn)
    for x in range(20, w, 46):
        cv.line(x + rng.randint(-3, 3), 10, x + rng.randint(-6, 6), h - 12, faint)
    for y in range(22, h, 38):
        cv.line(10, y + rng.randint(-3, 3), w - 10, y + rng.randint(-4, 4), faint)
    # main roads
    cv.line(10, 96, w - 10, 88, ink, 1)
    cv.line(10, 97, w - 10, 89, ink, 1)
    cv.line(150, 10, 170, h - 12, ink, 1)
    cv.line(262, 12, 250, h - 14, ink, 1)
    # bridge
    cv.rect(160, 148, 8, 16, c("wood", 2))
    # blocks shading
    for _ in range(40):
        bx, by = rng.randint(14, w - 30), rng.randint(14, h - 30)
        cv.rect(bx, by, rng.randint(6, 16), rng.randint(5, 12), c("paper", 3))
    # the school (home) with a little house mark
    hx, hy = 70, 64
    cv.poly([(hx - 7, hy), (hx, hy - 7), (hx + 7, hy)], c("red", 3))
    cv.rect(hx - 5, hy, 10, 7, c("red", 3))
    cv.rect(hx - 1, hy + 3, 2, 4, c("paper", 5))
    text(cv, hx - 12, hy + 8, "学校", ink, 12)
    # dashed route traces from home (in red pencil)
    for (tx, ty) in [(112, 98), (300, 52), (322, 196), (220, 214)]:
        steps = int(math.hypot(tx - hx, ty - hy) / 3)
        for s in range(steps):
            if (s // 2) % 2 == 0:
                x = hx + (tx - hx) * s / steps
                y = hy + (ty - hy) * s / steps + math.sin(s / 5) * 2
                cv.px(int(x), int(y), c("red", 2))
    # an X over a blocked road and a skull-ish scribble for danger
    for d in range(-4, 5):
        cv.px(205 + d, 120 + d, c("red", 3))
        cv.px(205 + d, 120 - d, c("red", 3))
    # tape at the corners
    for (tx, ty) in [(6, 4), (w - 38, h - 14)]:
        cv.rect(tx, ty, 30, 9, c("paper", 4))
        cv.hline(tx, ty, 30, c("paper", 5))
    cv.save(f"{OUT}/region_map.png", ramps=["paper", "wood", "red", "cold", "ink"])


if __name__ == "__main__":
    diary_paper()
    region_map()
