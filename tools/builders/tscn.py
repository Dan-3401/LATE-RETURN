"""Minimal writer for Godot 4 text scenes (.tscn) and resources.

Used to bootstrap level/prop scenes from Python layout descriptions. The
generated scenes are ordinary Godot scenes and can be edited in the editor
afterwards (re-running a builder overwrites them).
"""
import os
import struct

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


class Raw(str):
    """A value written verbatim (e.g. ExtResource("x"), Vector2(1, 2))."""


def fmt(v):
    if isinstance(v, Raw):
        return str(v)
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        s = repr(round(v, 4))
        return s if "." in s or "e" in s else s + ".0"
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        return "[" + ", ".join(fmt(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{\n" + ",\n".join(f"{fmt(k)}: {fmt(x)}" for k, x in v.items()) + "\n}"
    if v is None:
        return "null"
    raise TypeError(type(v))


def V2(x, y):
    return Raw(f"Vector2({fmt(float(x))}, {fmt(float(y))})")


def V2i(x, y):
    return Raw(f"Vector2i({int(x)}, {int(y)})")


def Col(r, g, b, a=1.0):
    return Raw(f"Color({r}, {g}, {b}, {a})")


def PV2(points):
    return Raw("PackedVector2Array(" + ", ".join(f"{fmt(float(x))}, {fmt(float(y))}" for x, y in points) + ")")


def SN(s):
    return Raw(f'&"{s}"')


def NP(s):
    return Raw(f'NodePath("{s}")')


class Scene:
    def __init__(self):
        self.ext = []       # (type, path, id)
        self._ext_ids = {}
        self.subs = []      # (type, id, props)
        self.nodes = []     # (name, type, parent, props, extra_header)
        self.conns = []
        self._n = 0

    def ext_res(self, typ, path):
        key = (typ, path)
        if key in self._ext_ids:
            return Raw(f'ExtResource("{self._ext_ids[key]}")')
        self._n += 1
        rid = f"{self._n}_{os.path.splitext(os.path.basename(path))[0][:12]}"
        self.ext.append((typ, path, rid))
        self._ext_ids[key] = rid
        return Raw(f'ExtResource("{rid}")')

    def sub_res(self, typ, props):
        self._n += 1
        sid = f"{typ}_{self._n}"
        self.subs.append((typ, sid, props))
        return Raw(f'SubResource("{sid}")')

    def node(self, name, typ=None, parent=None, props=None, instance=None, groups=None):
        header = f'[node name="{name}"'
        if typ:
            header += f' type="{typ}"'
        if parent is not None:
            header += f' parent="{parent}"'
        if instance is not None:
            header += f" instance={instance}"
        if groups:
            header += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        header += "]"
        self.nodes.append((header, props or {}))
        if parent is None:
            return "."
        return name if parent == "." else f"{parent}/{name}"

    def connect(self, signal, from_, to, method):
        self.conns.append(f'[connection signal="{signal}" from="{from_}" to="{to}" method="{method}"]')

    def text(self):
        out = [f"[gd_scene load_steps={len(self.ext) + len(self.subs) + 1} format=3]", ""]
        for typ, path, rid in self.ext:
            out.append(f'[ext_resource type="{typ}" path="{path}" id="{rid}"]')
        if self.ext:
            out.append("")
        for typ, sid, props in self.subs:
            out.append(f'[sub_resource type="{typ}" id="{sid}"]')
            for k, v in props.items():
                out.append(f"{k} = {fmt(v)}")
            out.append("")
        for header, props in self.nodes:
            out.append(header)
            for k, v in props.items():
                out.append(f"{k} = {fmt(v)}")
            out.append("")
        out.extend(self.conns)
        return "\n".join(out) + "\n"

    def save(self, rel):
        path = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(self.text())
        return path


def tile_map_data(cells):
    """cells: iterable of (x, y, source_id, atlas_x, atlas_y, alt) -> PackedByteArray literal."""
    b = bytearray(struct.pack("<H", 0))
    for (x, y, sid, ax, ay, alt) in cells:
        b += struct.pack("<hhHHHH", x, y, sid, ax, ay, alt)
    return Raw("PackedByteArray(" + ", ".join(str(v) for v in b) + ")")


def png_size(rel_art):
    from PIL import Image
    with Image.open(os.path.join(ROOT, rel_art)) as im:
        return im.size
