"""
Character rig: draws posed pixel characters (48x48 frames, feet at bottom centre)
from a skeleton + per-character style. Used for the brother, zombies and the sister.

Angles are in degrees, 0 = pointing straight down, positive = rotating toward
the facing direction (right). Torso angle: 0 = upright, positive = lean forward.
"""
import math

from pixlib import Canvas, PAL, c, TRANSPARENT

FW, FH = 48, 48


def rad(d):
    return math.radians(d)


def pt_from(x, y, ang_deg, length):
    """Point at `length` from (x,y) along angle (0=down, +=toward right)."""
    a = rad(ang_deg)
    return x + math.sin(a) * length, y + math.cos(a) * length


def capsule(cv, ax, ay, bx, by, r, ramp, base, light_dir=(0.55, -0.83), mask_layer=None, lit_boost=1, dark_drop=1):
    """Shaded capsule between two points."""
    x0 = int(math.floor(min(ax, bx) - r - 1))
    x1 = int(math.ceil(max(ax, bx) + r + 1))
    y0 = int(math.floor(min(ay, by) - r - 1))
    y1 = int(math.ceil(max(ay, by) + r + 1))
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px, py = x + 0.5, y + 0.5
            if L2 == 0:
                t = 0
            else:
                t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L2))
            qx, qy = ax + dx * t, ay + dy * t
            ox, oy = px - qx, py - qy
            d = math.hypot(ox, oy)
            if d <= r:
                # lighting: offset dotted with light direction
                ld = (ox * light_dir[0] + oy * light_dir[1]) / max(r, 0.01)
                i = base
                if ld > 0.35:
                    i += lit_boost
                elif ld < -0.35:
                    i -= dark_drop
                cv.px(x, y, c(ramp, i))


class Pose:
    def __init__(self, **kw):
        # hip centre (relative to frame), torso angle, torso length
        self.hip = kw.get("hip", (23.5, 29.5))
        self.torso = kw.get("torso", 0.0)
        self.neck_len = kw.get("neck_len", 13.0)
        self.head_tilt = kw.get("head_tilt", 0)  # pixel offset nudge (dx,dy)
        self.head_off = kw.get("head_off", (0, 0))
        self.head = kw.get("head", "normal")
        # legs: (thigh angle, shin angle) for back / front leg
        self.leg_b = kw.get("leg_b", (-4, -2))
        self.leg_f = kw.get("leg_f", (4, 2))
        self.foot_b = kw.get("foot_b", 0)   # foot pitch
        self.foot_f = kw.get("foot_f", 0)
        # arms: (upper, fore) angles
        self.arm_b = kw.get("arm_b", (-6, 4))
        self.arm_f = kw.get("arm_f", (6, 12))
        self.front_arm = kw.get("front_arm", True)
        self.back_arm = kw.get("back_arm", True)
        self.extra = kw.get("extra", {})


class Style:
    """Visual description of a character."""

    def __init__(self, **kw):
        self.skin = kw.get("skin", "skin")
        self.skin_base = kw.get("skin_base", 3)
        self.top = kw.get("top", "jacket")
        self.top_base = kw.get("top_base", 3)
        self.legs = kw.get("legs", "denim")
        self.legs_base = kw.get("legs_base", 2)
        self.boots = kw.get("boots", ("concrete", 1))
        self.thigh = kw.get("thigh", 6.5)
        self.shin = kw.get("shin", 7.5)
        self.leg_r = kw.get("leg_r", 1.9)
        self.upper = kw.get("upper", 6.0)
        self.fore = kw.get("fore", 6.0)
        self.arm_r = kw.get("arm_r", 1.6)
        self.torso_w = kw.get("torso_w", 4.2)   # half width at shoulders
        self.hip_w = kw.get("hip_w", 3.4)
        self.head_fn = kw.get("head_fn")
        self.torso_fn = kw.get("torso_fn")      # extra detail on torso
        self.back_fn = kw.get("back_fn")        # backpack etc (drawn behind torso)
        self.hand = kw.get("hand", None)        # (ramp, idx) for gloves
        self.outline_factor = kw.get("outline_factor", 0.3)


def draw_leg(cv, st, hx, hy, thigh_a, shin_a, foot_pitch, dark):
    kx, ky = pt_from(hx, hy, thigh_a, st.thigh)
    ax, ay = pt_from(kx, ky, shin_a, st.shin)
    base = st.legs_base - (1 if dark else 0)
    capsule(cv, hx, hy, kx, ky, st.leg_r + 0.2, st.legs, base)
    capsule(cv, kx, ky, ax, ay, st.leg_r, st.legs, base)
    # knee patch / wear
    cv.px(int(kx + 0.5), int(ky), c(st.legs, base + 1))
    # boot: small wedge pointing along foot direction (right)
    br, bi = st.boots
    bi -= 1 if dark else 0
    fa = rad(90 + foot_pitch - shin_a * 0.0)
    fx = math.cos(rad(foot_pitch)) * 4
    fy = math.sin(rad(foot_pitch)) * 4
    ax_i, ay_i = int(round(ax)), int(round(ay))
    # ankle/boot top
    capsule(cv, ax - 0.5, ay - 1.5, ax - 0.5, ay + 0.2, 1.8, br, bi + 1)
    # sole
    capsule(cv, ax - 1.5, ay + 0.8, ax - 1.5 + fx, ay + 0.8 + fy, 1.2, br, bi)
    cv.px(int(ax - 1.5 + fx), int(ay + 1.8 + fy), c(br, bi - 1))
    return ax, ay


def draw_arm(cv, st, sx, sy, up_a, fore_a, dark, hand_col=None):
    ex, ey = pt_from(sx, sy, up_a, st.upper)
    hx, hy = pt_from(ex, ey, fore_a, st.fore)
    base = st.top_base - (1 if dark else 0)
    capsule(cv, sx, sy, ex, ey, st.arm_r + 0.3, st.top, base)
    capsule(cv, ex, ey, hx, hy, st.arm_r, st.top, base)
    # hand
    if st.hand:
        hr, hi = st.hand
    else:
        hr, hi = st.skin, st.skin_base
    hi -= 1 if dark else 0
    capsule(cv, hx, hy, hx + math.sin(rad(fore_a)) * 1.2, hy + math.cos(rad(fore_a)) * 1.2, 1.3, hr, hi)
    return hx, hy


def draw_torso(cv, st, hip, neck, ang):
    """Torso as a tapered quad from hips to shoulders, shaded left(back)/right(front)."""
    hx, hy = hip
    nx, ny = neck
    # perpendicular
    dx, dy = nx - hx, ny - hy
    L = math.hypot(dx, dy) or 1
    px, py = -dy / L, dx / L  # perpendicular (points right when upright)
    sw, hw = st.torso_w, st.hip_w
    pts = [
        (hx - px * hw, hy - py * hw),
        (hx + px * hw, hy + py * hw),
        (nx + px * sw, ny + py * sw),
        (nx - px * sw, ny - py * sw),
    ]
    tmp = Canvas(cv.w, cv.h)
    tmp.poly(pts, (255, 255, 255, 255))
    # round shoulders
    tmp.disc(nx + px * (sw - 1.5), ny + py * (sw - 1.5) + 0.5, 1.8, (255, 255, 255, 255))
    tmp.disc(nx - px * (sw - 1.5), ny - py * (sw - 1.5) + 0.5, 1.8, (255, 255, 255, 255))
    for y in range(tmp.h):
        for x in range(tmp.w):
            if tmp.a[y, x, 3] == 0:
                continue
            # relative position across torso: -1 back .. +1 front
            rx = ((x + 0.5 - hx) * px + (y + 0.5 - hy) * py) / sw
            ry = ((x + 0.5 - hx) * dx + (y + 0.5 - hy) * dy) / (L * L)  # 0 hip .. 1 neck
            i = st.top_base
            if rx > 0.55:
                i += 1
            elif rx < -0.45:
                i -= 1
            if ry < 0.12:
                i -= 1
            cv.px(x, y, c(st.top, i))
    return px, py


def render(style, pose, flip=False):
    cv = Canvas(FW, FH)
    st = style
    hx, hy = pose.hip
    tor = pose.torso
    nx, ny = pt_from(hx, hy, 180 - tor, pose.neck_len)  # upward
    # shoulder location slightly below neck
    sx, sy = pt_from(hx, hy, 180 - tor, pose.neck_len - 1.5)

    # --- back arm
    if pose.back_arm:
        draw_arm(cv, st, sx - 1, sy + 0.5, pose.arm_b[0] + tor * 0.5, pose.arm_b[1] + tor * 0.5, True)
    # --- back leg
    draw_leg(cv, st, hx - 1, hy, pose.leg_b[0], pose.leg_b[1], pose.foot_b, True)
    # --- back item (backpack)
    if st.back_fn:
        st.back_fn(cv, (hx, hy), (nx, ny), tor, pose)
    # --- front leg
    draw_leg(cv, st, hx + 1, hy, pose.leg_f[0], pose.leg_f[1], pose.foot_f, False)
    # --- torso
    perp = draw_torso(cv, st, (hx, hy), (nx, ny), tor)
    if st.torso_fn:
        st.torso_fn(cv, (hx, hy), (nx, ny), tor, perp, pose)
    # --- head
    if st.head_fn:
        hox, hoy = pose.head_off
        st.head_fn(cv, nx + hox, ny + hoy, tor, pose)
    # --- front arm
    hand = None
    if pose.front_arm:
        hand = draw_arm(cv, st, sx + 0.5, sy + 0.5, pose.arm_f[0] + tor * 0.5, pose.arm_f[1] + tor * 0.5, False)
        if "hand_fn" in pose.extra:
            pose.extra["hand_fn"](cv, hand, pose)
    cv.outline(factor=st.outline_factor)
    # attachment points relative to feet (frame bottom-centre = (24, 48))
    cv.meta = {
        "shoulder": (sx + 0.5 - FW / 2, sy + 0.5 - FH),
        "chest": (sx + 1.5 - FW / 2, sy + 2.5 - FH),
        "head": (nx - FW / 2, ny - 10 - FH),
    }
    if flip:
        cv.a = cv.a[:, ::-1].copy()
    return cv


# ---------------------------------------------------------------------------
# Head templates
# ---------------------------------------------------------------------------
def stamp(cv, tpl, x, y, cmap):
    for j, row in enumerate(tpl):
        for i, ch in enumerate(row):
            if ch in cmap and cmap[ch] is not None:
                cv.px(x + i, y + j, cmap[ch])


def rotate_template(tpl, deg):
    """Rotate a template by 90-degree steps only (for lying heads)."""
    rows = [list(r) for r in tpl]
    h = len(rows)
    w = max(len(r) for r in rows)
    rows = [r + ["."] * (w - len(r)) for r in rows]
    steps = (deg // 90) % 4
    for _ in range(steps):
        rows = [list(r) for r in zip(*rows[::-1])]
    return ["".join(r) for r in rows]
