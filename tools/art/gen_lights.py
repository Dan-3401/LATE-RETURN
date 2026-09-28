"""Light textures with smooth falloff.

The game is pixel art, but light is atmosphere: Light2D textures get soft,
continuous gradients (the 480x270 viewport still quantises them to game
pixels, so they never smear the sprites). Sprites themselves stay Nearest.

A faint seeded noise (< 1/255) is added to every texture so the 8-bit
gradients do not band in the dark ranges.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import ART  # noqa: E402

OUT = os.path.join(ART, "lights")
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def save_gray(arr, name, alpha=False):
    arr = np.clip(arr + RNG.uniform(-0.5, 0.5, arr.shape) / 255.0, 0, 1)
    im = np.zeros(arr.shape + (4,), dtype=np.uint8)
    v = (arr * 255).round().astype(np.uint8)
    if alpha:
        # white with the gradient in alpha (additive / blended glow sprites)
        im[:, :, 0:3] = 255
        im[:, :, 3] = v
    else:
        im[:, :, 0] = im[:, :, 1] = im[:, :, 2] = v
        im[:, :, 3] = 255
    Image.fromarray(im, "RGBA").save(os.path.join(OUT, name))


def grid(w, h):
    y, x = np.mgrid[0:h, 0:w]
    return x + 0.5, y + 0.5


def cone(w=320, h=200, half_angle=24, name="flashlight_cone.png"):
    """Flashlight: a soft-edged cone, bright core, long smooth fall-off."""
    x, y = grid(w, h)
    dy = y - h / 2.0
    d = np.hypot(x, dy)
    ang = np.abs(np.degrees(np.arctan2(dy, x)))
    edge = 1.0 - smoothstep(half_angle - 10, half_angle + 5, ang)
    fall = np.clip(1.0 - d / w, 0, 1) ** 1.5
    hot = 0.4 * (1.0 - smoothstep(0, half_angle * 0.55, ang)) * np.clip(1.0 - d / (w * 0.75), 0, 1) ** 2
    near = smoothstep(0, 10, d)
    save_gray((fall + hot) * edge * near, name)


def radial(size=128, name="radial.png", power=1.6, core=0.0):
    x, y = grid(size, size)
    c = size / 2.0
    d = np.hypot(x - c, y - c) / c
    v = np.clip(1.0 - d, 0, 1) ** power
    if core > 0:
        v = v + core * np.exp(-(d / 0.18) ** 2)
    save_gray(v * smoothstep(1.0, 0.92, d), name)


def gaussian(size=256, name="soft_wide.png", sigma=0.42, alpha=False):
    """Very soft, wide blob: ambient fills and glow halos."""
    x, y = grid(size, size)
    c = size / 2.0
    d = np.hypot(x - c, y - c) / c
    v = np.exp(-(d / sigma) ** 2 / 2.0)
    v = v * smoothstep(1.0, 0.8, d)
    save_gray(v / v.max(), name, alpha)


def sky_wash(w=512, h=256, name="sky_wash.png"):
    """Moonlight / overcast sky falling from above: bright at the top edge,
    fading downward, soft on the sides."""
    x, y = grid(w, h)
    sides = smoothstep(0, w * 0.22, x) * smoothstep(0, w * 0.22, w - x)
    down = np.clip(1.0 - y / h, 0, 1) ** 1.4
    save_gray(sides * down, name)


def beam(w=96, h=220, name="window_beam.png", slant=0.35):
    """Slanted shaft of light falling down-right from a window (top edge),
    broken by the boards nailed over it."""
    x, y = grid(w, h)
    lx = x - y * slant
    width = w * 0.55
    inside = smoothstep(0, 9, lx) * smoothstep(0, 9, width - lx)
    fall = np.clip(1.0 - y / h, 0, 1) ** 1.2
    stripe = 0.45 + 0.55 * smoothstep(0.2, 0.5, np.abs(np.sin((lx + y * 0.1) * math.pi / 21.0)))
    save_gray(inside * fall * stripe, name)


def slit(w=24, h=96, name="door_slit.png"):
    x, y = grid(w, h)
    d = np.abs(x - w / 2) / (w / 2)
    v = np.clip(1 - d, 0, 1) ** 1.5 * (0.6 + 0.4 * (1 - np.abs(y - h / 2) / (h / 2)))
    save_gray(v, name)


def floor_spill(w=160, h=48, name="floor_spill.png"):
    """Light pooling on the floor under a lamp / through a door gap."""
    x, y = grid(w, h)
    dx = (x - w / 2) / (w / 2)
    dy = (y - h / 2) / (h / 2)
    v = np.exp(-(dx ** 2 / 0.25 + dy ** 2 / 0.35))
    save_gray(v / v.max(), name)


if __name__ == "__main__":
    cone()
    radial()
    radial(64, "radial_small.png", 1.2)
    radial(256, "radial_large.png", 1.8, core=0.15)
    gaussian(256, "soft_wide.png", 0.42)
    gaussian(128, "halo.png", 0.3, alpha=True)
    sky_wash()
    beam()
    slit()
    floor_spill()
    print("lights ok")
