"""Night city backdrops shared by the main menu and the street (parallax layers)."""
import math
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, c, value_noise, crack, stain, speckle, rust_patch, text, BAYER4, TRANSPARENT  # noqa: E402

OUT = "environment/city"


def sky(w=480, h=270, seed=3):
    rng = random.Random(seed)
    cv = Canvas(w, h)
    # vertical gradient cold -> slightly warmer haze near horizon (burning city far away)
    for y in range(h):
        t = y / h
        for x in range(w):
            v = t + BAYER4[y % 4, x % 4] * 0.12
            if v < 0.35:
                col = c("cold", 0)
            elif v < 0.6:
                col = c("cold", 1)
            elif v < 0.78:
                col = c("concrete", 1)
            elif v < 0.9:
                col = c("cloth2", 1)
            else:
                col = c("cloth2", 2)
            cv.px(x, y, col)
    # clouds
    n = value_noise(w, h, 40, seed + 1, 4)
    for y in range(20, int(h * 0.75)):
        for x in range(w):
            v = n[y, x] + BAYER4[y % 4, x % 4] * 0.05
            if v > 0.62:
                cv.px(x, y, c("cold", 1) if v < 0.68 else c("cold", 2))
    # moon behind clouds
    mx, my = int(w * 0.72), 48
    cv.disc(mx, my, 11, c("cold", 5))
    cv.disc(mx, my, 10, c("cold", 6))
    cv.disc(mx + 3, my - 2, 3, c("cold", 5))
    cv.disc(mx - 4, my + 3, 2, c("cold", 5))
    for y in range(my - 4, my + 3):
        for x in range(mx - 14, mx + 14):
            if n[y, x] > 0.55:
                cv.px(x, y, c("cold", 3))
    # sparse stars
    for _ in range(40):
        x, y = rng.randrange(w), rng.randrange(int(h * 0.4))
        if n[y, x] < 0.5:
            cv.px(x, y, c("cold", 4))
    return cv


def skyline(w=960, h=150, seed=5, far=True):
    """Tileable skyline silhouette. far=True: flat, low contrast."""
    rng = random.Random(seed)
    cv = Canvas(w, h)
    base = c("cold", 1) if far else c("ink", 2)
    edge = c("cold", 2) if far else c("concrete", 1)
    win = c("cold", 2) if far else c("concrete", 2)
    x = 0
    while x < w:
        bw = rng.randint(18, 46) if far else rng.randint(40, 90)
        bh = rng.randint(40, h - 10) if far else rng.randint(50, h - 4)
        top = h - bh
        broken = rng.random() < 0.45
        pts = [(x, h), (x, top), (x + bw, top), (x + bw, h)]
        if broken:
            # jagged collapsed top
            k = rng.randint(3, 6)
            pts = [(x, h), (x, top + rng.randint(0, 10))]
            for i in range(1, k):
                pts.append((x + bw * i / k, top + rng.randint(0, 22)))
            pts += [(x + bw, top + rng.randint(0, 10)), (x + bw, h)]
        cv.poly(pts, base)
        cv.line(pts[1][0], pts[1][1], pts[1][0], h, edge)
        # windows grid
        for wy in range(top + 6, h - 4, 7 if far else 9):
            for wx in range(x + 3, x + bw - 3, 5 if far else 8):
                if rng.random() < 0.55 and cv.filled(wx, wy - 2):
                    cv.rect(wx, wy, 2 if far else 3, 2 if far else 4, win)
        # antennas / cranes / rebar
        if rng.random() < 0.3:
            ax = x + rng.randint(3, bw - 3)
            cv.vline(ax, top - rng.randint(6, 18), rng.randint(6, 18), base)
        x += bw + (rng.randint(0, 6) if far else rng.randint(-8, 4))
    if far:
        # a distant construction crane
        cx = rng.randint(100, w - 100)
        cv.vline(cx, 20, h - 20, base)
        cv.hline(cx - 40, 22, 90, base)
        cv.line(cx, 12, cx - 38, 22, base)
        cv.line(cx, 12, cx + 48, 22, base)
        cv.vline(cx + 30, 22, 18, edge)
    # make it tile: copy left strip blend
    return cv


def fire_glow(w=960, h=150, seed=9):
    """A few faint orange glows (distant fires) to put behind the far skyline."""
    rng = random.Random(seed)
    cv = Canvas(w, h)
    for _ in range(2):
        cx = rng.randint(80, w - 80)
        for r in range(40, 0, -6):
            col = c("warm", 1) if r > 25 else c("warm", 2)
            for y in range(h - r, h):
                for x in range(cx - r * 2, cx + r * 2):
                    if ((x - cx) / (r * 2)) ** 2 + ((y - h) / r) ** 2 < 1 and (x + y) % 2 == 0:
                        cv.px(x, y, col)
    return cv


def mid_buildings(w=960, h=200, seed=11):
    """Closer ruined apartment blocks with detail, dark (used as a parallax mid layer)."""
    rng = random.Random(seed)
    cv = Canvas(w, h)
    x = 0
    while x < w:
        bw = rng.randint(90, 150)
        bh = rng.randint(120, h - 6)
        top = h - bh
        body = 1
        n = value_noise(bw, bh, 12, rng.randint(0, 999))
        cv.fill_field(x, top, bw, bh, "concrete", n * 0.5, lo=0, hi=2)
        # floors / slabs
        for fy in range(top + 18, h, 22):
            cv.hline(x, fy, bw, c("concrete", 2))
            cv.hline(x, fy + 1, bw, c("ink", 2))
            # balconies
            for bx in range(x + 8, x + bw - 20, 30):
                if rng.random() < 0.6:
                    cv.rect(bx, fy - 6, 18, 6, c("concrete", 1))
                    cv.hline(bx, fy - 6, 18, c("concrete", 3))
                    for k in range(bx + 1, bx + 18, 3):
                        cv.vline(k, fy - 5, 5, c("ink", 2))
        # windows
        for fy in range(top + 4, h - 10, 22):
            for wx in range(x + 6, x + bw - 10, 15):
                if rng.random() < 0.85:
                    cv.rect(wx, fy, 8, 10, c("ink", 1))
                    cv.hline(wx, fy + 10, 8, c("concrete", 3))
                    if rng.random() < 0.015:
                        # a faint lit window: someone else still alive?
                        cv.rect(wx + 1, fy + 1, 6, 8, c("warm", 2))
                        cv.rect(wx + 2, fy + 2, 3, 4, c("warm", 3))
                    elif rng.random() < 0.25:
                        cv.rect(wx + 1, fy + 1, 3, 9, c("cloth2", 1))  # curtain
        # ruined top: carve a ragged profile out of the roof line
        if rng.random() < 0.7:
            depth = 0
            for xx in range(x, x + bw):
                depth = max(0, min(18, depth + rng.choice([-2, -1, 0, 0, 1, 2])))
                for yy in range(top, top + depth):
                    cv.px(xx, yy, TRANSPARENT)
            # exposed rebar sticking out
            for _ in range(3):
                rx = x + rng.randint(4, bw - 4)
                ry = top
                while ry < h and not cv.filled(rx, ry):
                    ry += 1
                cv.vline(rx, ry - rng.randint(3, 8), rng.randint(3, 8), c("rust", 1))
        # cracks / stains / exposed rebar
        for _ in range(4):
            crack(cv, x + rng.randint(4, bw - 4), top + rng.randint(4, bh // 2), rng.randint(10, 30), c("ink", 1), rng, 0.2)
        for _ in range(5):
            stain(cv, x + rng.randint(0, bw), top + rng.randint(0, bh), rng.randint(6, 16), rng.randint(10, 30), 0.25, rng, rng.randint(0, 999))
        # vertical sign
        if rng.random() < 0.35:
            sx = x + rng.randint(10, bw - 20)
            sy = top + rng.randint(30, 60)
            cv.rect(sx, sy, 10, 34, c("red", 1))
            cv.rect(sx + 1, sy + 1, 8, 32, c("red", 2))
            for k in range(3):
                cv.rect(sx + 3, sy + 4 + k * 10, 4, 6, c("red", 3))
        x += bw + rng.randint(-4, 18)
    # the outline for readability against the sky
    cv.outline(c("ink", 0))
    return cv


def store_front(seed=21):
    """Main menu: the convenience store from outside, dead neon sign, one flickering tube."""
    rng = random.Random(seed)
    w, h = 220, 150
    cv = Canvas(w, h)
    n = value_noise(w, h, 14, seed)
    cv.fill_field(0, 20, w, h - 20, "plaster", n * 0.6, lo=0, hi=3)
    # upper floor
    for wx in range(12, w - 20, 34):
        cv.rect(wx, 30, 20, 22, c("ink", 1))
        cv.hline(wx, 52, 20, c("plaster", 4))
        cv.line(wx + 2, 32, wx + 17, 50, c("concrete", 1))
    # sign band
    cv.rect(0, 62, w, 20, c("green", 0))
    cv.hline(0, 62, w, c("green", 2))
    cv.hline(0, 81, w, c("ink", 1))
    text(cv, 20, 66, "24H 便利店", c("green", 2), 12)
    # awning (torn)
    for k in range(0, w, 12):
        col = c("red", 2) if (k // 12) % 2 == 0 else c("paper", 2)
        dh = rng.randint(4, 10)
        cv.poly([(k, 84), (k + 12, 84), (k + 12, 84 + dh), (k, 84 + dh + 2)], col)
    # shop windows (dark interior, taped X)
    for (wx, ww) in [(8, 70), (140, 72)]:
        cv.rect(wx, 98, ww, 46, c("ink", 1))
        cv.rect(wx, 98, ww, 2, c("metal", 3))
        cv.line(wx + 2, 100, wx + ww - 2, 142, c("paper", 2))
        cv.line(wx + ww - 2, 100, wx + 2, 142, c("paper", 2))
        crack(cv, wx + ww // 2, 102, 20, c("cold", 2), rng, 0.3)
    # door
    cv.rect(90, 96, 40, 54, c("metal", 2))
    cv.rect(94, 100, 32, 40, c("ink", 0))
    cv.hline(94, 122, 32, c("metal", 5))
    # half-open shutter over the right window
    for k in range(98, 118, 2):
        cv.hline(140, k, 72, c("metal", 3 if k % 4 else 4))
    # ground grime
    for _ in range(10):
        stain(cv, rng.randint(0, w), rng.randint(100, h), rng.randint(6, 16), rng.randint(6, 14), 0.25, rng, rng.randint(0, 999))
    for _ in range(6):
        crack(cv, rng.randint(0, w), rng.randint(20, 60), rng.randint(10, 30), c("plaster", 0), rng, 0.2)
    cv.outline(c("ink", 0))
    return cv


def street_lamp(broken=False):
    w, h = 40, 130
    cv = Canvas(w, h)
    cv.rect(18, 10, 3, h - 10, c("metal", 3))
    cv.vline(18, 10, h - 10, c("metal", 5))
    cv.rect(15, h - 8, 9, 8, c("metal", 2))
    if broken:
        cv.line(20, 12, 34, 22, c("metal", 3), 1)
        cv.rect(30, 20, 9, 4, c("metal", 4))
        cv.px(35, 25, c("white", 0))
    else:
        cv.line(20, 12, 34, 8, c("metal", 3), 1)
        cv.rect(29, 7, 10, 4, c("metal", 4))
        cv.rect(30, 11, 8, 2, c("warm", 5))
    for _ in range(3):
        rust_patch(cv, 19, random.randint(30, h - 10), 2, random.Random(3))
    cv.outline(c("ink", 0))
    return cv


def menu_car():
    from gen_street import car
    return car(seed=4, kind="sedan")


def ground_strip(w=480, h=40, seed=31):
    """Sidewalk + curb + asphalt band for the menu foreground."""
    rng = random.Random(seed)
    cv = Canvas(w, h)
    n = value_noise(w, h, 8, seed)
    cv.fill_field(0, 0, w, 10, "concrete", n[:10], lo=2, hi=4)
    for x in range(0, w, 24):
        cv.vline(x, 0, 10, c("concrete", 1))
    cv.rect(0, 10, w, 3, c("concrete", 5))
    cv.hline(0, 13, w, c("concrete", 1))
    cv.fill_field(0, 14, w, h - 14, "concrete", n[14:] * 0.6, lo=0, hi=2)
    for x in range(10, w, 60):
        cv.rect(x, 26, 24, 2, c("paper", 2))
    for _ in range(14):
        crack(cv, rng.randint(0, w), rng.randint(14, h - 4), rng.randint(6, 18), c("ink", 1), rng, 0.25, dirx=rng.choice([-1, 1]), diry=0)
    for _ in range(20):
        x = rng.randint(0, w - 4)
        for k in range(rng.randint(2, 5)):
            cv.vline(x + k, 10 - rng.randint(1, 4), 2, c("grass", rng.randint(2, 4)))
    return cv


def main():
    ground_strip().save(f"{OUT}/ground_strip.png")
    sky().save(f"{OUT}/sky.png")
    skyline(960, 150, 5, True).save(f"{OUT}/skyline_far.png")
    fire_glow().save(f"{OUT}/fire_glow.png")
    mid_buildings().save(f"{OUT}/buildings_mid.png")
    store_front().save(f"{OUT}/store_front.png")
    street_lamp(False).save(f"{OUT}/street_lamp.png")
    street_lamp(True).save(f"{OUT}/street_lamp_broken.png")
    print("city ok")


if __name__ == "__main__":
    main()
