"""Generates reusable prop / container scenes.

Conventions:
  * Prop origin = bottom-centre (the point that touches the floor).
  * Sprites use light_mask 1 (lit by the "front" lights).
  * Furniture occluders use occluder_light_mask 2: they only cast shadows for
    the lights that illuminate the back wall (light_mask 2), so furniture
    throws silhouettes onto the wall while the player plane stays lit.
  * Solid room walls use occluder mask 3 (block everything).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, V2, PV2, SN, NP, Raw, Col, png_size  # noqa: E402

# Only edges facing the light cast shadows: the prop itself stays lit and a
# light inside the polygon (player standing in front) casts nothing.
FURNITURE_CULL = 2
FURNITURE_MASK = 2


def rect_poly(w, h, inset=0, top=None):
    x0 = -(w // 2) + inset
    x1 = x0 + w - inset * 2
    y0 = -h + inset if top is None else -top
    return [(x0, y0), (x1, y0), (x1, 0), (x0, 0)]


def add_sprite(sc, parent, tex_rel, name="Sprite", light_mask=1, pos=(0, 0), z=0):
    w, h = png_size(tex_rel)
    props = {
        "texture": sc.ext_res("Texture2D", "res://" + tex_rel),
        "centered": False,
        "offset": V2(-(w // 2), -h),
    }
    if light_mask != 1:
        props["light_mask"] = light_mask
    if pos != (0, 0):
        props["position"] = V2(*pos)
    if z:
        props["z_index"] = z
    sc.node(name, "Sprite2D", parent, props)
    return w, h


def add_occluder(sc, parent, poly, mask=FURNITURE_MASK, cull=FURNITURE_CULL, name="Occluder"):
    occ = sc.sub_res("OccluderPolygon2D", {"cull_mode": cull, "polygon": PV2(poly)})
    sc.node(name, "LightOccluder2D", parent, {"occluder": occ, "occluder_light_mask": mask})


def add_interactable(sc, parent, w, h, prompt, offset, priority=0.0, pos=(0, 0)):
    """offset: prompt position relative to the prop origin."""
    shape = sc.sub_res("RectangleShape2D", {"size": V2(w, h)})
    ipos = (pos[0], pos[1] - h / 2)
    props = {
        "position": V2(*ipos),
        "script": sc.ext_res("Script", "res://scripts/interactables/interactable.gd"),
        "prompt_text": prompt,
        "prompt_offset": V2(offset[0] - ipos[0], offset[1] - ipos[1]),
    }
    if priority:
        props["focus_priority"] = priority
    sc.node("Interactable", "Area2D", parent, props)
    sc.node("CollisionShape2D", "CollisionShape2D", "Interactable" if parent == "." else f"{parent}/Interactable", {"shape": shape})


def add_static(sc, parent, poly, name="Solid", layer=1):
    shape = sc.sub_res("ConvexPolygonShape2D", {"points": PV2(poly)})
    sc.node(name, "StaticBody2D", parent, {"collision_layer": layer, "collision_mask": 0})
    sc.node("CollisionShape2D", "CollisionShape2D", name if parent == "." else f"{parent}/{name}", {"shape": shape})


def container_scene(out, tex, data, occ_poly=None, occ_top=None, drop_y=None, prompt_y=None, extra=None, searched_tex=None):
    sc = Scene()
    w, h = png_size(tex)
    props = {
        "script": sc.ext_res("Script", "res://scripts/interactables/loot_container.gd"),
        "data": sc.ext_res("Resource", f"res://resources/containers/{data}.tres"),
        "drop_origin": V2(0, -(drop_y if drop_y is not None else min(h - 6, 30))),
        "meter_offset": V2(0, -h - 6),
    }
    if searched_tex:
        props["searched_texture"] = sc.ext_res("Texture2D", "res://" + searched_tex)
    sc.node(os.path.splitext(os.path.basename(out))[0].title().replace("_", ""), "Node2D", None, props)
    add_sprite(sc, ".", tex)
    add_occluder(sc, ".", occ_poly or rect_poly(w, h, 1, occ_top))
    add_interactable(sc, ".", max(16, w - 12), 40, "搜刮", (0, -(prompt_y if prompt_y else min(h, 56) + 6)))
    if extra:
        extra(sc)
    sc.save(out)


def decor_scene(out, tex, occluder=True, occ_poly=None, solid=None, light_mask=1, cull=FURNITURE_CULL):
    sc = Scene()
    w, h = png_size(tex)
    sc.node(os.path.splitext(os.path.basename(out))[0].title().replace("_", ""), "Node2D", None, {})
    add_sprite(sc, ".", tex, light_mask=light_mask)
    if occluder:
        add_occluder(sc, ".", occ_poly or rect_poly(w, h, 1), cull=cull)
    if solid:
        add_static(sc, ".", solid)
    sc.save(out)


def build_store_props():
    base = "art/environment/store/"
    container_scene("scenes/interactables/store/shelf_a.tscn", base + "shelf_a.png", "shelf")
    container_scene("scenes/interactables/store/shelf_b.tscn", base + "shelf_b.png", "shelf")
    container_scene("scenes/interactables/store/shelf_c.tscn", base + "shelf_c.png", "shelf")
    container_scene("scenes/interactables/store/shelf_low.tscn", base + "shelf_low.png", "shelf")
    container_scene("scenes/interactables/store/cooler.tscn", base + "cooler.png", "cooler")
    container_scene("scenes/interactables/store/boxes.tscn", base + "boxes.png", "boxes", drop_y=20)

    # cash register: counter + register sprite on top; searching opens the drawer
    sc = Scene()
    cw, ch = png_size(base + "counter.png")
    rw, rh = png_size(base + "register.png")
    sc.node("Counter", "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/interactables/loot_container.gd"),
        "data": sc.ext_res("Resource", "res://resources/containers/register.tres"),
        "drop_origin": V2(-18, -ch - 4),
        "meter_offset": V2(-18, -ch - rh - 8),
        "searched_texture": sc.ext_res("Texture2D", "res://" + base + "register_open.png"),
        "sprite_path": NP("Register"),
    })
    add_sprite(sc, ".", base + "counter.png", name="CounterSprite")
    sc.node("Register", "Sprite2D", ".", {
        "texture": sc.ext_res("Texture2D", "res://" + base + "register.png"),
        "centered": False,
        "offset": V2(-(rw // 2), -rh),
        "position": V2(-18, -ch + 2),
    })
    add_occluder(sc, ".", rect_poly(cw, ch, 1))
    add_interactable(sc, ".", 40, 40, "搜刮", (-18, -ch - rh - 6), pos=(-18, 0))
    sc.save("scenes/interactables/store/counter_register.tscn")

    # decor
    decor_scene("scenes/props/store/magazine_rack.tscn", base + "magazine_rack.png")
    fw, fh = png_size(base + "fallen_shelf.png")
    ox, oy = -(fw // 2), -fh
    walk = [(ox + 0, 0), (ox + 10, oy + 19), (ox + 84, oy + 9), (ox + 86, 0)]
    decor_scene("scenes/props/store/fallen_shelf.tscn", base + "fallen_shelf.png", occluder=False, solid=walk)
    for k in ["pile", "bag", "papers", "bottles", "basket", "wet_sign"]:
        decor_scene(f"scenes/props/store/trash_{k}.tscn", base + f"trash_{k}.png", occluder=False)


if __name__ == "__main__":
    build_store_props()
    print("props ok")
