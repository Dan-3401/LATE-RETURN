"""Writers for Godot text resources (SpriteFrames, RigData)."""
import os

from pixlib import ROOT


def res_path(rel_art):
    return "res://art/" + rel_art


def write_sprite_frames(out_rel, anims, frame_w, frame_h):
    """anims: dict name -> {"png": rel path under art/, "count", "fps", "loop"}"""
    lines = []
    ext = []
    subs = []
    anim_blocks = []
    sub_id = 0
    for i, (name, a) in enumerate(anims.items()):
        eid = f"{i + 1}_{name}"
        ext.append(f'[ext_resource type="Texture2D" path="{res_path(a["png"])}" id="{eid}"]')
        frames = []
        for f in range(a["count"]):
            sub_id += 1
            sid = f"at_{sub_id}"
            cols = a.get("cols", a["count"])
            fx = (f % cols) * frame_w
            fy = (f // cols) * frame_h
            subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{eid}")\nregion = Rect2({fx}, {fy}, {frame_w}, {frame_h})\n')
            dur = a.get("durations", [1.0] * a["count"])[f]
            frames.append(f'{{\n"duration": {dur},\n"texture": SubResource("{sid}")\n}}')
        anim_blocks.append('{\n"frames": [' + ", ".join(frames) + '],\n"loop": ' + ("true" if a["loop"] else "false") +
                           f',\n"name": &"{name}",\n"speed": {float(a["fps"])}\n}}')
    load_steps = len(ext) + len(subs) + 1
    lines.append(f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]\n')
    lines.extend(ext)
    lines.append("")
    lines.extend(subs)
    lines.append("[resource]")
    lines.append("animations = [" + ", ".join(anim_blocks) + "]")
    path = os.path.join(ROOT, "art", out_rel)
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def v2(p):
    return f"Vector2({p[0]:.1f}, {p[1]:.1f})"


def write_rig(out_rel, points):
    """points: anim -> list of dict(key -> (x,y)) relative to feet."""
    items = []
    for anim, frames in points.items():
        fr = []
        for d in frames:
            fr.append("{" + ", ".join(f'"{k}": {v2(v)}' for k, v in d.items()) + "}")
        items.append(f'"{anim}": [' + ", ".join(fr) + "]")
    txt = ('[gd_resource type="Resource" script_class="RigData" load_steps=2 format=3]\n\n'
           '[ext_resource type="Script" path="res://scripts/data/rig_data.gd" id="1_rig"]\n\n'
           '[resource]\nscript = ExtResource("1_rig")\npoints = {\n' + ",\n".join(items) + "\n}\n")
    with open(os.path.join(ROOT, "art", out_rel), "w") as f:
        f.write(txt)
