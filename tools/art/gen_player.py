"""Generate the brother (player) sprite sheets."""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, c, make_sheet, preview, ART  # noqa: E402
from godot_res import write_sprite_frames, write_rig  # noqa: E402
from character import Pose, Style, render, stamp, pt_from, capsule, rotate_template, FW, FH  # noqa: E402

HEAD = [
    "...hhhh...",
    ".hhhhhhhh.",
    "hhHhhhhHhh",
    "hhhhhhhhhhh",
    "hhhhhhhHhh.",
    "hhhhhsssss.",
    "hhhhdsseSs.",
    "hhhhdsssSSs",
    ".hhhdssssd.",
    "..hddssmd..",
    "...dddd....",
]
HEAD_CLOSED = [r.replace("e", "d") for r in HEAD]
HEAD_PAIN = [r.replace("m", "e") for r in HEAD_CLOSED]


def head_cmap(dark=False):
    o = 1 if dark else 0
    return {
        "h": c("hair", 1 - o), "H": c("hair", 3 - o),
        "s": c("skin", 4 - o), "S": c("skin", 5 - o), "d": c("skin", 3 - o),
        "e": c("ink", 1), "m": c("skin", 2),
    }


def draw_head(cv, nx, ny, tor, pose):
    tpl = {"normal": HEAD, "closed": HEAD_CLOSED, "pain": HEAD_PAIN}.get(pose.head, HEAD)
    rot = pose.extra.get("head_rot", 0)
    if rot:
        tpl = rotate_template(tpl, rot)
    h = len(tpl)
    w = max(len(r) for r in tpl)
    # neck gaiter/scarf
    capsule(cv, nx - 0.5, ny + 0.5, nx + 0.8, ny - 0.5, 2.2, "concrete", 4)
    if rot == 0:
        stamp(cv, tpl, int(round(nx - 5)), int(round(ny - h + 1)), head_cmap())
    elif rot == 90:   # face up, head to the right of neck
        stamp(cv, tpl, int(round(nx)), int(round(ny - w / 2)), head_cmap())
    elif rot == 270:  # face down, head to the left
        stamp(cv, tpl, int(round(nx - h)), int(round(ny - w / 2)), head_cmap())
    else:
        stamp(cv, tpl, int(round(nx - 5)), int(round(ny - 1)), head_cmap())
    # scarf front fold
    cv.px(int(nx + 1), int(ny + 1), c("concrete", 5))


def draw_backpack(cv, hip, neck, tor, pose):
    hx, hy = hip
    nx, ny = neck
    # backpack sits on the back side (left) between shoulders and lower back
    a = math.radians(tor)
    ux, uy = math.sin(a), -math.cos(a)        # up along torso
    bx, by = -math.cos(a), -math.sin(a)       # toward back
    tmp = []
    for t in range(0, 11):
        for s in range(0, 6):
            x = hx + ux * (3 + t) + bx * (3 + s)
            y = hy + uy * (3 + t) + by * (3 + s)
            tmp.append((x, y, t, s))
    for x, y, t, s in tmp:
        i = 3
        if t >= 9:
            i = 4
        if s >= 5:
            i = 1
        elif s <= 0:
            i = 2
        if t <= 1:
            i = 1
        cv.px(int(round(x)), int(round(y)), c("wood", i))
    # pocket + strap buckle
    for t in range(3, 7):
        x = hx + ux * (3 + t) + bx * 7.5
        y = hy + uy * (3 + t) + by * 7.5
        cv.px(int(round(x)), int(round(y)), c("wood", 2))
    x = hx + ux * 8 + bx * 3
    y = hy + uy * 8 + by * 3
    cv.px(int(round(x)), int(round(y)), c("metal", 6))
    # bedroll on top
    x = hx + ux * 14 + bx * 5
    y = hy + uy * 14 + by * 5
    capsule(cv, x - 1, y, x + 1, y, 1.6, "concrete", 3)


def draw_jacket_detail(cv, hip, neck, tor, perp, pose):
    hx, hy = hip
    nx, ny = neck
    a = math.radians(tor)
    ux, uy = math.sin(a), -math.cos(a)
    fx, fy = math.cos(a), math.sin(a)
    # strap across chest (from front shoulder to hip back)
    for t in range(0, 12):
        x = nx + fx * 2.5 - ux * t + (-fx) * (t * 0.35)
        y = ny + fy * 2.5 - uy * t + (-fy) * (t * 0.35)
        cv.px(int(round(x)), int(round(y)), c("wood", 1))
    # small flashlight clipped on the strap (upper chest)
    x = nx + fx * 3.3 - ux * 3
    y = ny + fy * 3.3 - uy * 3
    cv.px(int(round(x)), int(round(y)), c("metal", 4))
    cv.px(int(round(x + fx)), int(round(y + fy)), c("metal", 6))
    # belt line
    for s in range(-3, 4):
        x = hx + fx * s + ux * 1.5
        y = hy + fy * s + uy * 1.5
        cv.px(int(round(x)), int(round(y)), c("jacket", 1))
    # pocket flap
    x = hx + fx * 2 + ux * 4
    y = hy + fy * 2 + uy * 4
    cv.px(int(round(x)), int(round(y)), c("jacket", 2))
    cv.px(int(round(x + fx)), int(round(y + fy)), c("jacket", 2))


STYLE = Style(
    top="jacket", top_base=3, legs="denim", legs_base=2, boots=("wood", 2),
    head_fn=draw_head, back_fn=draw_backpack, torso_fn=draw_jacket_detail,
    hand=("skin", 3), torso_w=4.8, hip_w=3.9, leg_r=2.1, arm_r=1.8,
)

# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------
BASE_HIP = (23.5, 29.5)


def lerp(a, b, t):
    return a + (b - a) * t


def walk_pose(i, n, stride=24, bob=1, lean=4, arm_sw=22, crouch=0, knee=18, armed=False):
    ph = 2 * math.pi * i / n
    s = math.sin(ph)
    c2 = math.cos(ph)
    thigh_f = stride * s
    thigh_b = -stride * s
    # knee bends when leg is swinging forward (moving through)
    shin_f = thigh_f - max(0, knee * (-c2)) - crouch * 1.4
    shin_b = thigh_b - max(0, knee * (c2)) - crouch * 1.4
    hy = BASE_HIP[1] + (bob if abs(s) < 0.5 else 0) + crouch
    arm_f = (-arm_sw * s * 0.9, -arm_sw * s * 0.9 + 14)
    arm_b = (arm_sw * s * 0.9, arm_sw * s * 0.9 + 14)
    return Pose(hip=(BASE_HIP[0], hy), torso=lean + crouch * 2.5,
                leg_f=(thigh_f + crouch * 3, shin_f), leg_b=(thigh_b + crouch * 3, shin_b),
                arm_f=arm_f, arm_b=arm_b, front_arm=not armed)


def idle_pose(i, n, armed=False):
    b = 1 if i in (1, 2) else 0
    return Pose(hip=(BASE_HIP[0], BASE_HIP[1]), torso=1, neck_len=13 - b * 0.6,
                leg_f=(6, 3), leg_b=(-5, -3),
                arm_f=(4 + b, 10), arm_b=(-4 - b, 6), front_arm=not armed)


def sneak_pose(i, n, armed=False):
    return walk_pose(i, n, stride=18, bob=1, lean=14, arm_sw=10, crouch=4, knee=22, armed=armed)


def run_pose(i, n, armed=False):
    p = walk_pose(i, n, stride=38, bob=2, lean=14, arm_sw=40, knee=46, armed=armed)
    s = math.sin(2 * math.pi * i / n)
    p.arm_f = (-40 * s, -40 * s + 70)
    p.arm_b = (40 * s, 40 * s + 70)
    return p


def jump_pose(kind, armed=False):
    if kind == "up":
        return Pose(hip=(BASE_HIP[0], BASE_HIP[1] - 2), torso=6, leg_f=(40, -20), leg_b=(-10, -30),
                    arm_f=(-40, -20), arm_b=(40, 60), front_arm=not armed)
    return Pose(hip=(BASE_HIP[0], BASE_HIP[1] - 1), torso=2, leg_f=(20, 10), leg_b=(-12, 4),
                arm_f=(-70, -60), arm_b=(60, 80), front_arm=not armed)


def land_pose(i, armed=False):
    cr = [5, 2][i]
    return Pose(hip=(BASE_HIP[0], BASE_HIP[1] + cr), torso=8 + cr, leg_f=(30 + cr * 3, -10), leg_b=(10, -25),
                arm_f=(10, 30), arm_b=(-10, 20), front_arm=not armed)


def search_pose(i, n):
    # crouched, reaching forward, rummaging alternately
    s = math.sin(2 * math.pi * i / n)
    return Pose(hip=(BASE_HIP[0] - 1, BASE_HIP[1] + 6), torso=32, neck_len=12.5,
                leg_f=(70, -10), leg_b=(30, -40),
                arm_f=(60 + 12 * s, 40 + 18 * s), arm_b=(70 - 12 * s, 50 - 18 * s))


def hurt_pose(i):
    return Pose(hip=(BASE_HIP[0] - 1, BASE_HIP[1] + 1), torso=-12 + i * 4, head="pain",
                leg_f=(14, 6), leg_b=(-12, -6), arm_f=(-30, 10), arm_b=(30, 50))


# Wake-up / get-up keyframes: lying on the back (head left) -> stand
def getup_poses():
    frames = []
    ground = 45.5
    keys = [
        # hip, torso, legs f, legs b, arm f, arm b, head
        dict(hip=(29, ground - 1.5), torso=-86, leg_f=(88, 88), leg_b=(92, 92), arm_f=(-80, -95), arm_b=(-95, -90), head="closed", extra={"head_rot": 270}),
        dict(hip=(29, ground - 1.5), torso=-86, leg_f=(88, 88), leg_b=(92, 92), arm_f=(-80, -95), arm_b=(-95, -90), head="normal", extra={"head_rot": 270}),
        dict(hip=(28, ground - 1.5), torso=-55, leg_f=(88, 88), leg_b=(92, 92), arm_f=(-30, 10), arm_b=(-70, -60), head="normal"),
        dict(hip=(27, ground - 2), torso=-25, leg_f=(80, 40), leg_b=(90, 88), arm_f=(40, 60), arm_b=(-40, -20), head="normal"),
        dict(hip=(25, ground - 5), torso=10, leg_f=(80, -10), leg_b=(60, -60), arm_f=(40, 20), arm_b=(-10, 20), head="normal"),
        dict(hip=(24.5, ground - 10), torso=20, leg_f=(60, -10), leg_b=(20, -30), arm_f=(30, 10), arm_b=(0, 10), head="normal"),
        dict(hip=(24, ground - 14), torso=10, leg_f=(20, 0), leg_b=(-4, -8), arm_f=(10, 12), arm_b=(-6, 6), head="normal"),
        dict(hip=(23.5, BASE_HIP[1]), torso=2, leg_f=(6, 3), leg_b=(-5, -3), arm_f=(4, 10), arm_b=(-4, 6), head="normal"),
    ]
    for k in keys:
        frames.append(Pose(**k))
    return frames


def death_poses():
    ground = 45.5
    keys = [
        dict(hip=(23.5, BASE_HIP[1] + 1), torso=-8, leg_f=(10, 4), leg_b=(-10, -4), arm_f=(-20, 10), arm_b=(20, 40), head="pain"),
        dict(hip=(23.5, BASE_HIP[1] + 6), torso=10, leg_f=(50, -20), leg_b=(30, -40), arm_f=(20, 40), arm_b=(10, 30), head="pain"),
        dict(hip=(23, BASE_HIP[1] + 11), torso=30, leg_f=(80, -10), leg_b=(70, -50), arm_f=(50, 60), arm_b=(40, 50), head="pain"),
        dict(hip=(22, ground - 5), torso=55, leg_f=(90, 30), leg_b=(80, -20), arm_f=(80, 90), arm_b=(60, 90), head="closed"),
        dict(hip=(20, ground - 2), torso=80, leg_f=(-88, -88), leg_b=(-80, -95), arm_f=(100, 110), arm_b=(80, 100), head="closed", extra={"head_rot": 90}),
        dict(hip=(20, ground - 1.5), torso=86, leg_f=(-88, -90), leg_b=(-84, -92), arm_f=(95, 95), arm_b=(85, 90), head="closed", extra={"head_rot": 90}),
    ]
    return [Pose(**k) for k in keys]


def build():
    anims = {}
    def add(name, poses, fps, loop=True):
        anims[name] = {"frames": [render(STYLE, p) for p in poses], "fps": fps, "loop": loop}

    add("idle", [idle_pose(i, 4) for i in range(4)], 3)
    add("walk", [walk_pose(i, 8) for i in range(8)], 10)
    add("sneak", [sneak_pose(i, 8) for i in range(8)], 7)
    add("run", [run_pose(i, 8) for i in range(8)], 14)
    add("jump", [jump_pose("up")], 1, False)
    add("fall", [jump_pose("fall")], 1, False)
    add("land", [land_pose(0), land_pose(1)], 12, False)
    add("search", [search_pose(i, 4) for i in range(4)], 6)
    add("hurt", [hurt_pose(0), hurt_pose(1)], 10, False)
    add("getup", getup_poses(), 5, False)
    add("lying", [getup_poses()[0]], 1, False)
    add("death", death_poses(), 7, False)
    # armed variants (front arm drawn separately by the weapon rig)
    add("armed_idle", [idle_pose(i, 4, True) for i in range(4)], 3)
    add("armed_walk", [walk_pose(i, 8, armed=True) for i in range(8)], 10)
    add("armed_sneak", [sneak_pose(i, 8, True) for i in range(8)], 7)
    add("armed_run", [run_pose(i, 8, True) for i in range(8)], 14)
    add("armed_jump", [jump_pose("up", True)], 1, False)
    add("armed_fall", [jump_pose("fall", True)], 1, False)
    add("armed_land", [land_pose(0, True), land_pose(1, True)], 12, False)

    outdir = "characters/player"
    meta = {}
    for name, a in anims.items():
        sheet = make_sheet(a["frames"])
        sheet.save(f"{outdir}/{name}.png")
        meta[name] = {"count": len(a["frames"]), "fps": a["fps"], "loop": a["loop"], "w": FW, "h": FH}
    write_sprite_frames(f"{outdir}/player_frames.tres",
                        {n: {"png": f"{outdir}/{n}.png", "count": m["count"], "fps": m["fps"], "loop": m["loop"]} for n, m in meta.items()},
                        FW, FH)
    write_rig(f"{outdir}/player_rig.tres", {n: [f.meta for f in a["frames"]] for n, a in anims.items()})

    build_arms(outdir)
    return anims


def build_arms(outdir):
    """Front arm sprites for weapons. Drawn pointing right, pivot = shoulder at (4, 4)."""
    # pistol arm: 24x9, shoulder pivot at (3,4)
    cv = Canvas(24, 10)
    capsule(cv, 3, 4, 9, 4.5, 1.9, "jacket", 3)
    capsule(cv, 9, 4.5, 14, 4.5, 1.6, "jacket", 3)
    capsule(cv, 14.5, 4.5, 15.5, 4.5, 1.3, "skin", 3)
    # pistol: slide + grip
    cv.rect(15, 2, 7, 2, c("metal", 3))
    cv.hline(15, 2, 7, c("metal", 5))
    cv.px(21, 2, c("metal", 6))
    cv.rect(15, 4, 3, 1, c("metal", 2))
    cv.rect(15, 5, 2, 2, c("metal", 1))
    cv.px(18, 4, c("metal", 2))
    cv.outline(factor=0.3)
    cv.save(f"{outdir}/arm_pistol.png")
    # knife arm: 22x10 pivot (3,4) ; blade pointing forward
    cv = Canvas(22, 10)
    capsule(cv, 3, 4, 9, 5, 1.9, "jacket", 3)
    capsule(cv, 9, 5, 13, 4.5, 1.6, "jacket", 3)
    capsule(cv, 13.5, 4.5, 14.5, 4.5, 1.4, "skin", 3)
    cv.rect(14, 3, 2, 3, c("wood", 2))  # handle
    cv.hline(16, 4, 4, c("metal", 7))
    cv.hline(16, 3, 3, c("metal", 5))
    cv.px(20, 4, c("metal", 8))
    cv.outline(factor=0.3)
    cv.save(f"{outdir}/arm_knife.png")
    # relaxed arm (used when a weapon is holstered mid-animation) not needed.


if __name__ == "__main__":
    anims = build()
    # contact sheet preview
    rows = []
    order = ["idle", "walk", "sneak", "run", "getup", "death", "search", "armed_walk"]
    maxn = max(len(anims[o]["frames"]) for o in order)
    sheet = Canvas(FW * maxn, FH * len(order), fill=(40, 44, 50, 255))
    for r, o in enumerate(order):
        for i, f in enumerate(anims[o]["frames"]):
            sheet.blit(f, i * FW, r * FH)
    pdir = os.environ.get("LR_PREVIEW")
    if pdir:
        from PIL import Image
        os.makedirs(pdir, exist_ok=True)
        im = Image.fromarray(sheet.a, "RGBA")
        im.resize((sheet.w * 4, sheet.h * 4), Image.NEAREST).save(os.path.join(pdir, "player_contact.png"))
