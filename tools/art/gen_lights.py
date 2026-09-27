"""Light textures with stepped (pixel-friendly) falloff."""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import ART, BAYER4  # noqa: E402

OUT = os.path.join(ART, "lights")
os.makedirs(OUT, exist_ok=True)


def stepped(v, steps, dither_amt=0.5, x=0, y=0):
    return np.floor(np.clip(v, 0, 1) * steps + BAYER4[y % 4, x % 4] * dither_amt) / steps


def save_gray(arr, name):
    arr = np.clip(arr, 0, 1)
    im = np.zeros(arr.shape + (4,), dtype=np.uint8)
    im[:, :, 0] = im[:, :, 1] = im[:, :, 2] = (arr * 255).astype(np.uint8)
    im[:, :, 3] = 255
    Image.fromarray(im, "RGBA").save(os.path.join(OUT, name))


def cone(w=320, h=200, half_angle=24, steps=6, name="flashlight_cone.png"):
    arr = np.zeros((h, w))
    cy = h / 2.0
    for y in range(h):
        for x in range(w):
            dx = x + 0.5
            dy = y + 0.5 - cy
            d = math.hypot(dx, dy)
            ang = abs(math.degrees(math.atan2(dy, dx)))
            if ang > half_angle + 6:
                continue
            a = 1.0 if ang < half_angle - 8 else max(0.0, 1.0 - (ang - (half_angle - 8)) / 14.0)
            fall = max(0.0, 1.0 - d / w) ** 1.3
            hot = 0.35 * max(0.0, 1.0 - ang / (half_angle * 0.5)) * max(0.0, 1.0 - d / (w * 0.8))
            v = a * fall + hot * a
            if d < 6:
                v *= d / 6.0
            arr[y, x] = stepped(v, steps, 0.6, x, y)
    save_gray(arr, name)


def radial(size=128, steps=5, name="radial.png", power=1.6):
    arr = np.zeros((size, size))
    c = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            v = max(0.0, 1.0 - d) ** power
            arr[y, x] = stepped(v, steps, 0.6, x, y)
    save_gray(arr, name)


def beam(w=96, h=220, name="window_beam.png", slant=0.35, steps=4):
    """Slanted shaft of light falling down-right from a window (top edge)."""
    arr = np.zeros((h, w))
    for y in range(h):
        off = y * slant
        for x in range(w):
            u = (x - off) / (w * (1 - slant * h / w * 0.0)) if w else 0
            lx = x - off
            if 0 <= lx < w * 0.55:
                edge = min(lx, w * 0.55 - lx) / 8.0
                v = min(1.0, edge) * (1.0 - y / h) ** 1.2
                # plank gaps -> stripes
                stripe = 1.0 if int((lx + y * 0.1) / 7) % 3 != 1 else 0.35
                arr[y, x] = stepped(v * stripe, steps, 0.6, x, y)
    save_gray(arr, name)


def slit(w=24, h=96, name="door_slit.png"):
    arr = np.zeros((h, w))
    for y in range(h):
        for x in range(w):
            d = abs(x + 0.5 - w / 2) / (w / 2)
            v = max(0, 1 - d) ** 1.5 * (0.6 + 0.4 * (1 - abs(y - h / 2) / (h / 2)))
            arr[y, x] = stepped(v, 4, 0.6, x, y)
    save_gray(arr, name)


if __name__ == "__main__":
    cone()
    radial()
    radial(64, 4, "radial_small.png", 1.2)
    radial(256, 6, "radial_large.png", 1.8)
    beam()
    slit()
    print("lights ok")
