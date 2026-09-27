"""
pixlib — tiny pixel-art authoring library used to generate all Late Return art.

Everything is drawn on integer pixel grids with a shared master palette so
that every asset keeps the same pixel density and colour language.
Final images are quantised to PALETTE (see quantize()).
"""
import math
import os
import random

import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "art")


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


# ---------------------------------------------------------------------------
# Master palette (ramps dark -> light). Low saturation, cold, worn.
# ---------------------------------------------------------------------------
RAMPS = {
    "ink":      ["07080a", "0d0e12", "13151a"],
    "concrete": ["191b20", "22252b", "2c3037", "383d44", "464b52", "565c62", "6a6f73", "80858a", "989c9e", "b3b5b2"],
    "tile":     ["1b2421", "232e2a", "2d3a34", "384740", "45554c", "56665a", "6b7a6a", "859178", "a2a98f"],
    "plaster":  ["2a2723", "36322c", "433e36", "524c42", "635c50", "766e60", "8b8372", "a39a86"],
    "rust":     ["241410", "37190f", "4d2412", "663117", "80421f", "9a582a", "b2733c"],
    "wood":     ["1f1611", "2d2018", "3c2b1f", "4d3828", "5f4632", "74573e", "8b6b4d"],
    "metal":    ["16191d", "20252a", "2b3137", "384047", "475058", "58626a", "6d777d", "87908f", "a5aca8"],
    "skin":     ["2e1d1a", "4a2f28", "683f33", "8a5642", "a86f55", "c28c6c", "d6a888"],
    "jacket":   ["111618", "182022", "212c2d", "2c3a39", "3a4a46", "4b5d55", "5f7266"],
    "denim":    ["121420", "1a1d2b", "232839", "2e344a", "3b435c", "4d5670"],
    "hair":     ["0e0b0b", "181313", "241c1b", "312623"],
    "red":      ["2a0e0e", "401412", "5a1b17", "74251e", "8f3427", "a84a33"],
    "yellow":   ["3a3018", "524420", "6d5b2a", "8a7436", "a68e46", "c0a85c", "d8c47c"],
    "blue":     ["141c28", "1c2838", "25364a", "30465e", "3e5874", "506d8a"],
    "paper":    ["3a372f", "524e43", "6d685a", "878172", "a19a88", "bab29f", "d0c8b3"],
    "grass":    ["121810", "1a2416", "23301c", "2e3e22", "3b4d2a", "4b5e32", "5e723c"],
    "zskin":    ["1e231c", "2a3226", "374131", "46523d", "58654b", "6c7a5c", "85916f"],
    "blood":    ["1c0707", "2e0b0b", "450f0e", "5e1512"],
    "warm":     ["3d2410", "5e3816", "86541f", "b0762e", "d49c46", "ecc373", "f7e2a8"],
    "cold":     ["1a2233", "243048", "30405e", "425676", "5a7090", "7a90ac", "a3b6c8"],
    "green":    ["0f2418", "15331f", "1d4a2a", "2a6a38", "3d8f4a", "5fb865"],
    "cloth2":   ["1e1a22", "2a2430", "38303f", "473d50", "5a4e63", "706278"],
    "white":    ["c9c4b4", "e0dccd", "f2efe4"],
}
PAL = {k: [hx(c) for c in v] for k, v in RAMPS.items()}
TRANSPARENT = (0, 0, 0, 0)

_all = []
for v in PAL.values():
    _all.extend(v)
PALETTE = np.array(sorted(set(_all)), dtype=np.int64)[:, :3]


def c(ramp, i):
    r = PAL[ramp]
    i = max(0, min(len(r) - 1, i))
    return r[i]


# ---------------------------------------------------------------------------
# Noise
# ---------------------------------------------------------------------------
def value_noise(w, h, scale, seed, octaves=3, persistence=0.5):
    rng = np.random.RandomState(seed)
    out = np.zeros((h, w), dtype=np.float64)
    amp = 1.0
    total = 0.0
    sc = scale
    for _ in range(octaves):
        gw = int(math.ceil(w / sc)) + 2
        gh = int(math.ceil(h / sc)) + 2
        grid = rng.rand(gh, gw)
        ys = np.arange(h) / sc
        xs = np.arange(w) / sc
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        fy = ys - y0
        fx = xs - x0
        fy = fy * fy * (3 - 2 * fy)
        fx = fx * fx * (3 - 2 * fx)
        a = grid[y0][:, x0]
        b = grid[y0][:, x0 + 1]
        cc = grid[y0 + 1][:, x0]
        d = grid[y0 + 1][:, x0 + 1]
        top = a + (b - a) * fx[None, :]
        bot = cc + (d - cc) * fx[None, :]
        out += amp * (top + (bot - top) * fy[:, None])
        total += amp
        amp *= persistence
        sc = max(1.0, sc / 2.0)
    return out / total


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


# ---------------------------------------------------------------------------
# Canvas
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h, fill=TRANSPARENT):
        self.w = w
        self.h = h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)
        if fill != TRANSPARENT:
            self.a[:, :] = fill

    # -- basic ------------------------------------------------------------
    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def px(self, x, y, col):
        x = int(x)
        y = int(y)
        if self.inb(x, y) and col is not None:
            if len(col) == 4 and col[3] == 0:
                self.a[y, x] = (0, 0, 0, 0)
            else:
                self.a[y, x] = col
        return self

    def get(self, x, y):
        if self.inb(x, y):
            return tuple(int(v) for v in self.a[y, x])
        return TRANSPARENT

    def filled(self, x, y):
        return self.inb(x, y) and self.a[y, x, 3] > 0

    def rect(self, x, y, w, h, col):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1] = col
        return self

    def hline(self, x, y, w, col):
        return self.rect(x, y, w, 1, col)

    def vline(self, x, y, h, col):
        return self.rect(x, y, 1, h, col)

    def line(self, x0, y0, x1, y1, col, width=1):
        x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            if width == 1:
                self.px(x0, y0, col)
            else:
                self.disc(x0, y0, width / 2.0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
        return self

    def disc(self, cx, cy, r, col):
        ri = int(math.ceil(r))
        for yy in range(-ri, ri + 1):
            for xx in range(-ri, ri + 1):
                if xx * xx + yy * yy <= r * r + 0.3:
                    self.px(cx + xx, cy + yy, col)
        return self

    def ellipse(self, cx, cy, rx, ry, col):
        for yy in range(int(-ry) - 1, int(ry) + 2):
            for xx in range(int(-rx) - 1, int(rx) + 2):
                if rx > 0 and ry > 0 and (xx / rx) ** 2 + (yy / ry) ** 2 <= 1.0:
                    self.px(cx + xx, cy + yy, col)
        return self

    def poly(self, pts, col):
        """Scanline polygon fill."""
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(pts)
            for i in range(n):
                x0, y0 = pts[i]
                x1, y1 = pts[(i + 1) % n]
                if (y0 <= y + 0.5 < y1) or (y1 <= y + 0.5 < y0):
                    xs.append(x0 + (y + 0.5 - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1]))):
                    self.px(x, y, col)
        return self

    def blit(self, other, x, y, flip=False):
        src = other.a[:, ::-1] if flip else other.a
        h, w = src.shape[:2]
        for yy in range(h):
            ty = y + yy
            if not 0 <= ty < self.h:
                continue
            for xx in range(w):
                tx = x + xx
                if 0 <= tx < self.w and src[yy, xx, 3] > 0:
                    self.a[ty, tx] = src[yy, xx]
        return self

    def copy(self):
        cc = Canvas(self.w, self.h)
        cc.a = self.a.copy()
        return cc

    # -- material fills ---------------------------------------------------
    def fill_field(self, x, y, w, h, ramp, field, lo=0, hi=None, dither=0.9, mask=None):
        """Map a float field (0..1, shape h,w) onto ramp indices [lo..hi] with ordered dithering."""
        r = PAL[ramp] if isinstance(ramp, str) else ramp
        if hi is None:
            hi = len(r) - 1
        n = hi - lo + 1
        for yy in range(h):
            for xx in range(w):
                if mask is not None and not mask[yy, xx]:
                    continue
                v = field[yy, xx] * n + BAYER4[(y + yy) % 4, (x + xx) % 4] * dither
                i = int(max(0, min(n - 1, math.floor(v))))
                self.px(x + xx, y + yy, r[lo + i])
        return self

    def shade_mul(self, x, y, col_fn):
        pass

    def darken(self, x, y, amount):
        """Shift an existing pixel darker (keeps alpha)."""
        if not self.filled(x, y):
            return
        p = self.a[y, x].astype(np.int16)
        p[:3] = np.clip(p[:3] * (1.0 - amount), 0, 255)
        self.a[y, x] = p

    def tint(self, x, y, col, t):
        if not self.filled(x, y):
            return
        p = self.a[y, x].astype(np.float64)
        p[:3] = p[:3] * (1 - t) + np.array(col[:3]) * t
        self.a[y, x] = p.astype(np.uint8)

    # -- outline ----------------------------------------------------------
    def outline(self, col=None, factor=0.35, diagonal=False):
        """Add a 1px outline outside the silhouette. If col is None uses a darkened
        version of the neighbour (selective outline)."""
        a = self.a
        filled = a[:, :, 3] > 0
        out = a.copy()
        dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            dirs += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
        for y in range(self.h):
            for x in range(self.w):
                if filled[y, x]:
                    continue
                for dx, dy in dirs:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and filled[ny, nx]:
                        if col is not None:
                            out[y, x] = col
                        else:
                            p = a[ny, nx].astype(np.float64)
                            p[:3] *= factor
                            out[y, x] = p.astype(np.uint8)
                            out[y, x, 3] = 255
                        break
        self.a = out
        return self

    def inner_edge(self, top_col=None, bottom_col=None):
        """Light the top edge and darken the bottom edge of each opaque region."""
        a = self.a
        filled = a[:, :, 3] > 0
        out = a.copy()
        for y in range(self.h):
            for x in range(self.w):
                if not filled[y, x]:
                    continue
                if top_col is not None and (y == 0 or not filled[y - 1, x]):
                    out[y, x] = top_col
                elif bottom_col is not None and (y == self.h - 1 or not filled[y + 1, x]):
                    out[y, x] = bottom_col
        self.a = out
        return self

    # -- export -----------------------------------------------------------
    def quantize(self, ramps=None):
        pal = PALETTE
        if ramps:
            cols = []
            for r in ramps:
                cols.extend(PAL[r])
            pal = np.array(sorted(set(cols)), dtype=np.int64)[:, :3]
        rgb = self.a[:, :, :3].astype(np.int64)
        alpha = self.a[:, :, 3]
        flat = rgb.reshape(-1, 3)
        # weighted distance (perceptual-ish)
        wts = np.array([2, 4, 3])
        best = np.zeros(flat.shape[0], dtype=np.int32)
        bestd = np.full(flat.shape[0], 1 << 30, dtype=np.int64)
        for i, pc in enumerate(pal):
            d = (((flat - pc) ** 2) * wts).sum(axis=1)
            m = d < bestd
            bestd[m] = d[m]
            best[m] = i
        q = pal[best].reshape(self.h, self.w, 3).astype(np.uint8)
        self.a[:, :, :3] = np.where(alpha[:, :, None] > 0, q, 0)
        self.a[:, :, 3] = np.where(alpha > 0, 255, 0)
        return self

    def save(self, rel, quantize=True, scale=1, ramps=None):
        if quantize:
            self.quantize(ramps)
        path = os.path.join(ART, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        im = Image.fromarray(self.a, "RGBA")
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        im.save(path)
        return path


# ---------------------------------------------------------------------------
# Wear & tear helpers
# ---------------------------------------------------------------------------
def crack(cv, x, y, length, col, rng, branch=0.12, dirx=None, diry=1, light=None):
    """Random-walk crack. Optional light pixel under each crack pixel for depth."""
    cx, cy = x, y
    for i in range(length):
        cv.px(cx, cy, col)
        if light is not None and cv.filled(cx + 1, cy) and rng.random() < 0.5:
            cv.px(cx + 1, cy, light)
        if dirx is None:
            cx += rng.choice([-1, 0, 0, 1])
        else:
            cx += dirx if rng.random() < 0.6 else rng.choice([-1, 0, 1])
        cy += diry if rng.random() < 0.8 else 0
        if rng.random() < branch and length - i > 4:
            crack(cv, cx, cy, (length - i) // 2, col, rng, branch * 0.5, rng.choice([-1, 1]), diry, light)
    return cv


def stain(cv, cx, cy, rx, ry, amount, rng, noise_seed=1, x0=0, y0=0, w=None, h=None):
    w = w or cv.w
    h = h or cv.h
    n = value_noise(int(rx * 2 + 3), int(ry * 2 + 3), max(2, rx / 2), noise_seed, 2)
    for yy in range(-int(ry) - 1, int(ry) + 2):
        for xx in range(-int(rx) - 1, int(rx) + 2):
            d = (xx / max(rx, 0.1)) ** 2 + (yy / max(ry, 0.1)) ** 2
            nv = n[yy + int(ry) + 1, xx + int(rx) + 1]
            if d < 0.55 + nv * 0.6:
                px, py = cx + xx, cy + yy
                if x0 <= px < x0 + w and y0 <= py < y0 + h:
                    t = amount * (1.0 - d * 0.6)
                    if t > 0:
                        cv.darken(px, py, t)
    return cv


def drips(cv, x, y, count, max_len, amount, rng):
    for _ in range(count):
        dx = x + rng.randint(-3, 3)
        ln = rng.randint(max_len // 3, max_len)
        for i in range(ln):
            cv.darken(dx, y + i, amount * (1 - i / ln))
    return cv


def speckle(cv, x, y, w, h, cols, density, rng):
    for _ in range(int(w * h * density)):
        cv.px(x + rng.randrange(w), y + rng.randrange(h), rng.choice(cols))
    return cv


def rust_patch(cv, cx, cy, r, rng):
    for yy in range(-r, r + 1):
        for xx in range(-r, r + 1):
            if xx * xx + yy * yy <= r * r and rng.random() < 0.75 - (xx * xx + yy * yy) / (r * r + 1) * 0.5:
                if cv.filled(cx + xx, cy + yy):
                    cv.px(cx + xx, cy + yy, c("rust", rng.randint(1, 4)))
    return cv


def make_sheet(frames, cols=None):
    """Pack same-size canvases into a horizontal strip (or grid with cols)."""
    fw, fh = frames[0].w, frames[0].h
    cols = cols or len(frames)
    rows = int(math.ceil(len(frames) / cols))
    sheet = Canvas(fw * cols, fh * rows)
    for i, f in enumerate(frames):
        sheet.blit(f, (i % cols) * fw, (i // cols) * fh)
    return sheet


def preview(rel, scale=4, bg=(20, 22, 26)):
    """Save an upscaled preview with a background for inspection (not used in game)."""
    path = os.path.join(ART, rel)
    im = Image.open(path).convert("RGBA")
    bgim = Image.new("RGBA", im.size, bg + (255,))
    bgim.alpha_composite(im)
    pdir = os.environ.get("LR_PREVIEW", "/tmp/lr_preview")
    os.makedirs(pdir, exist_ok=True)
    out = os.path.join(pdir, "prev_" + rel.replace("/", "_"))
    bgim.resize((im.width * scale, im.height * scale), Image.NEAREST).save(out)
    return out


FONT_PATH = os.path.join(ROOT, "fonts", "fusion-pixel.ttf")


def text(cv, x, y, s, col, size=12, jitter=None, rng=None):
    """Draw crisp pixel text with the project font (threshold, no AA)."""
    from PIL import ImageDraw, ImageFont
    f = ImageFont.truetype(FONT_PATH, size)
    bbox = f.getbbox(s)
    w, h = bbox[2] + 2, bbox[3] + 2
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).text((0, 0), s, font=f, fill=255)
    m = np.array(im)
    for yy in range(h):
        for xx in range(w):
            if m[yy, xx] > 127:
                ox = oy = 0
                if jitter and rng and rng.random() < jitter:
                    oy = rng.choice([-1, 1])
                cv.px(x + xx + ox, y + yy + oy - bbox[1], col)
    return w, h - bbox[1]
