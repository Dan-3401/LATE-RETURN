"""Zombie sprite sheets (three variants sharing one rig)."""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, c, make_sheet, TRANSPARENT  # noqa: E402
from character import Pose, Style, render, stamp, capsule, rotate_template, FW, FH  # noqa: E402
from godot_res import write_sprite_frames  # noqa: E402

HEAD = [
    "...hhhh...",
    "..hhhsshh.",
    ".hhssssss.",
    ".hsssssssh",
    ".hsssssss.",
    ".hsssdwds.",
    ".hssddddS.",
    ".hsssssSS.",
    "..sdssssd.",
    "..ddsmmd..",
    "...ddddd..",
]
HEAD_ROAR = [
    "...hhhh...",
    "..hhhsshh.",
    ".hhssssss.",
    ".hsssssssh",
    ".hsssssss.",
    ".hsssdwds.",
    ".hssddddS.",
    ".hsssssSS.",
    "..sdssmmmd",
    "..ddsmMMm.",
    "...ddmMm..",
    "....dmm...",
]
HEAD_LONG = [  # long-haired variant
    "..hhhhhh..",
    ".hhhhhhhh.",
    "hhhhsssshh",
    "hhhsssssh.",
    "hhhsssss..",
    "hhhssdwds.",
    "hhhsddddS.",
    "hhhsssssS.",
    "hhhdssssd.",
    "hh.dsmmd..",
    "h...ddd...",
]


def head_cmap(hair):
    return {
        "h": c(hair[0], hair[1]), "s": c("zskin", 4), "S": c("zskin", 5), "d": c("zskin", 2),
        "w": c("paper", 5), "m": c("blood", 1), "M": c("blood", 0),
    }


def make_head_fn(tpl_normal, hair):
    def fn(cv, nx, ny, tor, pose):
        tpl = HEAD_ROAR if pose.head == "roar" else tpl_normal
        rot = pose.extra.get("head_rot", 0)
        if rot:
            tpl = rotate_template(tpl, rot)
        h = len(tpl)
        dx, dy = pose.extra.get("head_shift", (0, 0))
        if rot == 90:
            stamp(cv, tpl, int(round(nx)), int(round(ny - 5)), head_cmap(hair))
        else:
            stamp(cv, tpl, int(round(nx - 5 + dx)), int(round(ny - h + 1 + dy)), head_cmap(hair))
    return fn


def torn_fn(seed, ramp, blood=True):
    def fn(cv, hip, neck, tor, perp, pose):
        rng = random.Random(seed)
        hx, hy = hip
        nx, ny = neck
        a = math.radians(tor)
        ux, uy = math.sin(a), -math.cos(a)
        fx, fy = math.cos(a), math.sin(a)
        # tears showing skin
        for k in range(3):
            t = 3 + k * 3
            x = hx + ux * t + fx * rng.uniform(-2, 3)
            y = hy + uy * t + fy * rng.uniform(-2, 3)
            cv.px(int(round(x)), int(round(y)), c("zskin", 3))
            cv.px(int(round(x + fx)), int(round(y + fy)), c("zskin", 2))
        # dried blood down the front
        if blood:
            for t in range(4, 11):
                x = nx + fx * 3 - ux * t * 0.9
                y = ny + fy * 3 - uy * t * 0.9
                if rng.random() < 0.8:
                    cv.px(int(round(x)), int(round(y)), c("blood", 2))
        # ragged hem
        for s in range(-3, 4):
            if rng.random() < 0.5:
                x = hx + fx * s - ux * 1
                y = hy + fy * s - uy * 1
                cv.px(int(round(x)), int(round(y)), c(ramp, 1))
    return fn


VARIANTS = {
    "a": dict(top="jacket", top_base=2, legs="denim", legs_base=1, boots=("concrete", 1), hair=("hair", 1), head=HEAD, seed=1),
    "b": dict(top="cloth2", top_base=2, legs="concrete", legs_base=1, boots=("ink", 2), hair=("hair", 0), head=HEAD, seed=2),
    "c": dict(top="red", top_base=1, legs="cloth2", legs_base=1, boots=("wood", 1), hair=("hair", 2), head=HEAD_LONG, seed=3),
}


def style_for(v):
    d = VARIANTS[v]
    return Style(top=d["top"], top_base=d["top_base"], legs=d["legs"], legs_base=d["legs_base"], boots=d["boots"],
                 skin="zskin", skin_base=3, hand=("zskin", 3), head_fn=make_head_fn(d["head"], d["hair"]),
                 torso_fn=torn_fn(d["seed"], d["top"]), torso_w=4.6, hip_w=3.7, leg_r=2.0, arm_r=1.7,
                 thigh=6.5, shin=7.5, upper=6.5, fore=6.5)


HIP = (23.5, 30.5)


def idle(i, n):
    s = math.sin(i / n * math.tau)
    return Pose(hip=(HIP[0], HIP[1] + 1), torso=26 + s * 3, neck_len=12.5, head_off=(2, 2),
                leg_f=(8, 2), leg_b=(-6, -4), arm_f=(18 + s * 6, 26 + s * 6), arm_b=(10 - s * 4, 20 - s * 4))


def shamble(i, n):
    ph = i / n * math.tau
    s = math.sin(ph)
    c2 = math.cos(ph)
    # front leg steps, back leg drags
    thigh_f = 16 * s
    thigh_b = -10 * s - 4
    return Pose(hip=(HIP[0], HIP[1] + 1 + (1 if abs(s) < 0.5 else 0)), torso=26 + 3 * c2, neck_len=12.5, head_off=(2, 2),
                leg_f=(thigh_f, thigh_f - max(0, 20 * -c2)), leg_b=(thigh_b, thigh_b - 4),
                arm_f=(24 + 8 * s, 34 + 8 * s), arm_b=(18 - 6 * s, 28 - 6 * s), foot_b=10)


def run(i, n):
    ph = i / n * math.tau
    s = math.sin(ph)
    c2 = math.cos(ph)
    return Pose(hip=(HIP[0], HIP[1] + (2 if abs(s) < 0.5 else 0)), torso=32, neck_len=12.5, head_off=(2, 2),
                leg_f=(36 * s + 6, 36 * s + 6 - max(0, 50 * -c2)), leg_b=(-36 * s + 6, -36 * s + 6 - max(0, 50 * c2)),
                arm_f=(80 + 20 * s, 90 + 20 * s), arm_b=(70 - 20 * s, 85 - 20 * s))


def alert(i):
    keys = [
        dict(torso=18, head="normal", arm_f=(18, 26), arm_b=(10, 20)),
        dict(torso=6, head="normal", arm_f=(10, 20), arm_b=(0, 10)),
        dict(torso=-8, head="roar", arm_f=(-10, 10), arm_b=(-20, 0), head_off=(-1, -1)),
        dict(torso=-12, head="roar", arm_f=(-20, 0), arm_b=(-30, -10), head_off=(-1, -2)),
        dict(torso=-10, head="roar", arm_f=(-14, 6), arm_b=(-26, -6), head_off=(-1, -1)),
        dict(torso=24, head="roar", arm_f=(60, 70), arm_b=(50, 60)),
    ]
    k = keys[i]
    return Pose(hip=HIP, torso=k["torso"], neck_len=12.5, head=k["head"], head_off=k.get("head_off", (1, 1)),
                leg_f=(10, 4), leg_b=(-8, -4), arm_f=k["arm_f"], arm_b=k["arm_b"])


def attack(i):
    keys = [
        dict(torso=10, arm_f=(-40, -20), arm_b=(-30, -10), hip=(HIP[0] - 1, HIP[1])),
        dict(torso=4, arm_f=(-70, -60), arm_b=(-50, -40), hip=(HIP[0] - 2, HIP[1])),
        dict(torso=36, arm_f=(80, 70), arm_b=(95, 85), hip=(HIP[0] + 2, HIP[1] + 1), head="roar"),
        dict(torso=40, arm_f=(110, 120), arm_b=(100, 110), hip=(HIP[0] + 3, HIP[1] + 1), head="roar"),
        dict(torso=26, arm_f=(40, 50), arm_b=(30, 40), hip=(HIP[0] + 1, HIP[1])),
    ]
    k = keys[i]
    return Pose(hip=k["hip"], torso=k["torso"], neck_len=12.5, head=k.get("head", "normal"), head_off=(1, 1),
                leg_f=(24, 4), leg_b=(-14, -8), arm_f=k["arm_f"], arm_b=k["arm_b"])


def hit(i):
    return Pose(hip=(HIP[0] - 1 - i, HIP[1]), torso=-10 - i * 6, neck_len=12.5, head_off=(-1, 0),
                leg_f=(14, 6), leg_b=(-8, -2), arm_f=(-30, -10), arm_b=(20, 40))


def death(i):
    ground = 45.5
    keys = [
        dict(hip=(HIP[0] - 1, HIP[1]), torso=-14, leg_f=(12, 4), leg_b=(-8, -2), arm_f=(-40, -20), arm_b=(10, 30)),
        dict(hip=(HIP[0] - 2, HIP[1] + 5), torso=-30, leg_f=(40, -10), leg_b=(20, -30), arm_f=(-60, -40), arm_b=(-20, 0)),
        dict(hip=(HIP[0] + 2, HIP[1] + 10), torso=-50, leg_f=(70, 20), leg_b=(50, -20), arm_f=(-80, -70), arm_b=(-60, -50)),
        dict(hip=(HIP[0] + 5, ground - 3), torso=-75, leg_f=(85, 80), leg_b=(80, 60), arm_f=(-100, -95), arm_b=(-80, -90)),
        dict(hip=(HIP[0] + 7, ground - 1.5), torso=-86, leg_f=(88, 90), leg_b=(92, 88), arm_f=(-92, -90), arm_b=(-80, -85)),
    ]
    k = keys[i]
    return Pose(hip=k["hip"], torso=k["torso"], neck_len=12.5, head_off=(0, 0), leg_f=k["leg_f"], leg_b=k["leg_b"],
                arm_f=k["arm_f"], arm_b=k["arm_b"], extra={"head_rot": 270} if i >= 3 else {})


def eat(i, n):
    s = math.sin(i / n * math.tau)
    return Pose(hip=(HIP[0] - 3, HIP[1] + 11), torso=58 + s * 4, neck_len=12.0, head_off=(1, 2 + int(s)),
                leg_f=(80, -20), leg_b=(40, -70), arm_f=(70 + s * 20, 90 + s * 10), arm_b=(80 - s * 20, 100 - s * 10))


def bang(i, n):
    """Clawing at a hiding spot."""
    s = math.sin(i / n * math.tau)
    return Pose(hip=HIP, torso=14, neck_len=12.5, head_off=(1, 1), leg_f=(10, 4), leg_b=(-8, -4),
                arm_f=(60 + 40 * s, 70 + 40 * s), arm_b=(70 - 40 * s, 80 - 40 * s))


def build_variant(v):
    st = style_for(v)
    anims = {
        "idle": ([idle(i, 6) for i in range(6)], 4, True),
        "walk": ([shamble(i, 8) for i in range(8)], 6, True),
        "run": ([run(i, 8) for i in range(8)], 13, True),
        "alert": ([alert(i) for i in range(6)], 7, False),
        "attack": ([attack(i) for i in range(5)], 10, False),
        "hit": ([hit(i) for i in range(2)], 10, False),
        "death": ([death(i) for i in range(5)], 8, False),
        "eat": ([eat(i, 4) for i in range(4)], 6, True),
        "bang": ([bang(i, 4) for i in range(4)], 7, True),
    }
    outdir = f"characters/zombie_{v}"
    meta = {}
    frames_by_anim = {}
    for name, (poses, fps, loop) in anims.items():
        frames = [render(st, p) for p in poses]
        frames_by_anim[name] = frames
        make_sheet(frames).save(f"{outdir}/{name}.png")
        meta[name] = {"png": f"{outdir}/{name}.png", "count": len(frames), "fps": fps, "loop": loop}
    write_sprite_frames(f"{outdir}/zombie_{v}_frames.tres", meta, FW, FH)
    return frames_by_anim


if __name__ == "__main__":
    all_frames = {v: build_variant(v) for v in VARIANTS}
    pdir = os.environ.get("LR_PREVIEW")
    if pdir:
        from PIL import Image
        order = ["idle", "walk", "run", "alert", "attack", "death", "eat"]
        sheet = Canvas(FW * 8, FH * len(order) * 1, fill=(40, 44, 50, 255))
        for r, o in enumerate(order):
            for i, f in enumerate(all_frames["a"][o]):
                sheet.blit(f, i * FW, r * FH)
        im = Image.fromarray(sheet.a, "RGBA")
        im.resize((im.width * 4, im.height * 4), Image.NEAREST).save(os.path.join(pdir, "zombie_contact.png"))
        row = Canvas(FW * 3, FH, fill=(40, 44, 50, 255))
        for i, v in enumerate(VARIANTS):
            row.blit(all_frames[v]["walk"][0], i * FW, 0)
        im = Image.fromarray(row.a, "RGBA")
        im.resize((im.width * 5, im.height * 5), Image.NEAREST).save(os.path.join(pdir, "zombie_variants.png"))
    print("zombies ok")
