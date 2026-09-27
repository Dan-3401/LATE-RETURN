"""Builds the street props and scenes/maps/street.tscn."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, V2, PV2, SN, NP, Raw, Col, tile_map_data, png_size  # noqa: E402
import props  # noqa: E402
from build_store import build_tileset  # noqa: E402

ART = "art/environment/street/"
CITY = "art/environment/city/"
FLOOR_Y = 224
WIDTH = 2650


def solid_prop(out, tex, poly, occluder=True, extra=None):
    sc = Scene()
    w, h = png_size(tex)
    sc.node(os.path.splitext(os.path.basename(out))[0].title().replace("_", ""), "Node2D", None, {})
    props.add_sprite(sc, ".", tex)
    if occluder:
        props.add_occluder(sc, ".", poly, mask=1, cull=0)
    sc.node("Body", "StaticBody2D", ".", {"collision_layer": 1, "collision_mask": 0})
    sc.node("Shape", "CollisionPolygon2D", "Body", {"polygon": PV2(poly)})
    if extra:
        extra(sc)
    sc.save(out)


def hide_spot_scene(out, tex, occupied_tex, poly=None, hide_offset=(0, 0), solid=False):
    sc = Scene()
    w, h = png_size(tex)
    sc.node(os.path.splitext(os.path.basename(out))[0].title().replace("_", ""), "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/interactables/hide_spot.gd"),
        "hide_offset": V2(*hide_offset),
        "occupied_texture": sc.ext_res("Texture2D", "res://" + occupied_tex),
    })
    props.add_sprite(sc, ".", tex)
    props.add_interactable(sc, ".", min(w - 8, 40), 36, "躲藏", (0, -h - 6), priority=0.2)
    if poly:
        props.add_occluder(sc, ".", poly, mask=1, cull=0)
        if solid:
            sc.node("Body", "StaticBody2D", ".", {"collision_layer": 1, "collision_mask": 0})
            sc.node("Shape", "CollisionPolygon2D", "Body", {"polygon": PV2(poly)})
    sc.save(out)


def grass_scene(out, tex, frames=4, width=None, count=1):
    sc = Scene()
    fw, fh = png_size(tex)
    fw //= frames
    total = width or fw * count
    sc.node(os.path.splitext(os.path.basename(out))[0].title().replace("_", ""), "Area2D", None, {
        "z_index": 2,
        "script": sc.ext_res("Script", "res://scripts/interactables/grass_area.gd"),
    })
    # sprite frames resource inline
    atlas = sc.ext_res("Texture2D", "res://" + tex)
    subs = []
    for f in range(frames):
        subs.append(sc.sub_res("AtlasTexture", {"atlas": atlas, "region": Raw(f"Rect2({f * fw}, 0, {fw}, {fh})")}))
    frames_list = ", ".join("{\n\"duration\": 1.0,\n\"texture\": %s\n}" % s for s in subs)
    sf = sc.sub_res("SpriteFrames", {"animations": Raw('[{\n"frames": [' + frames_list + '],\n"loop": true,\n"name": &"default",\n"speed": 3.0\n}]')})
    n = max(1, round(total / (fw * 0.75)))
    step = total / n
    for i in range(n):
        x = -total / 2 + step * i + step / 2
        sc.node(f"Tuft{i}", "AnimatedSprite2D", ".", {
            "position": V2(round(x), -fh // 2), "sprite_frames": sf, "autoplay": "default",
            "frame": i % frames, "flip_h": i % 2 == 1,
        })
    shape = sc.sub_res("RectangleShape2D", {"size": V2(total, 30)})
    sc.node("Shape", "CollisionShape2D", ".", {"position": V2(0, -15), "shape": shape})
    sc.save(out)


def build_props():
    # cars (solid, climbable, block light and zombie sight)
    solid_prop("scenes/props/street/car_sedan_blue.tscn", ART + "car_sedan_blue.png",
               [(-50, 0), (-49, -10), (-36, -20), (-22, -34), (18, -36), (32, -22), (48, -19), (51, 0)])
    solid_prop("scenes/props/street/car_van.tscn", ART + "car_van.png",
               [(-58, 0), (-57, -46), (-52, -52), (26, -53), (42, -36), (58, -30), (59, 0)])
    solid_prop("scenes/props/street/barrier.tscn", ART + "barrier.png", [(-25, 0), (-21, -26), (21, -26), (25, 0)])
    # hide spots
    hide_spot_scene("scenes/interactables/street/dumpster.tscn", ART + "dumpster_open.png", ART + "dumpster.png")
    hide_spot_scene("scenes/interactables/street/car_hide.tscn", ART + "car_sedan_blue_open.png", ART + "car_sedan_blue.png",
                    poly=[(-50, 0), (-49, -10), (-36, -20), (-22, -34), (18, -36), (32, -22), (48, -19), (51, 0)], hide_offset=(-6, 0), solid=False)
    # grass
    grass_scene("scenes/interactables/street/grass_patch.tscn", ART + "grass_b.png", width=110)
    grass_scene("scenes/interactables/street/grass_small.tscn", ART + "grass_a.png", width=64)
    # decor
    for n in ["bus_stop", "dead_tree", "road_sign", "cone", "trash_bags", "bush"]:
        props.decor_scene(f"scenes/props/street/{n}.tscn", ART + f"{n}.png", occluder=False)
    # fire barrel: animated, warm light, light zone
    sc = Scene()
    sc.node("FireBarrel", "Node2D", None, {})
    atlas = sc.ext_res("Texture2D", "res://" + ART + "fire_barrel.png")
    subs = [sc.sub_res("AtlasTexture", {"atlas": atlas, "region": Raw(f"Rect2({f * 22}, 0, 22, 40)")}) for f in range(4)]
    fl = ", ".join("{\n\"duration\": 1.0,\n\"texture\": %s\n}" % s for s in subs)
    sf = sc.sub_res("SpriteFrames", {"animations": Raw('[{\n"frames": [' + fl + '],\n"loop": true,\n"name": &"default",\n"speed": 8.0\n}]')})
    sc.node("Sprite", "AnimatedSprite2D", ".", {"position": V2(0, -20), "sprite_frames": sf, "autoplay": "default"})
    sc.node("Light", "PointLight2D", ".", {
        "position": V2(0, -26), "color": Col(1, 0.62, 0.3), "energy": 1.0, "range_item_cull_mask": 3,
        "shadow_enabled": True, "shadow_item_cull_mask": 1,
        "texture": sc.ext_res("Texture2D", "res://art/lights/radial_large.png"), "texture_scale": 0.7,
        "script": sc.ext_res("Script", "res://scripts/effects/flicker_light.gd"),
        "base_energy": 1.0, "min_interval": 0.3, "max_interval": 1.2, "dead_chance": 0.0,
    })
    sc.node("LightZone", "Area2D", ".", {"script": sc.ext_res("Script", "res://scripts/interactables/light_zone.gd")})
    sc.node("Shape", "CollisionShape2D", "LightZone", {"position": V2(0, -20), "shape": sc.sub_res("RectangleShape2D", {"size": V2(110, 40)})})
    sc.node("Embers", "CPUParticles2D", ".", {
        "position": V2(0, -38), "amount": 6, "lifetime": 1.6, "texture": sc.ext_res("Texture2D", "res://art/fx/pixel.png"),
        "direction": V2(0, -1), "spread": 25.0, "gravity": V2(0, -10), "initial_velocity_min": 8.0, "initial_velocity_max": 20.0,
        "color": Col(1, 0.6, 0.25, 1),
    })
    sc.save("scenes/props/street/fire_barrel.tscn")
    # street lamp: working (flickering) with a light zone underneath
    sc = Scene()
    sc.node("StreetLamp", "Node2D", None, {})
    props.add_sprite(sc, ".", CITY + "street_lamp.png")
    sc.node("Light", "PointLight2D", ".", {
        "position": V2(14, -110), "color": Col(1, 0.85, 0.6), "energy": 1.1, "range_item_cull_mask": 3,
        "shadow_enabled": True, "shadow_item_cull_mask": 1,
        "texture": sc.ext_res("Texture2D", "res://art/lights/radial_large.png"), "texture_scale": 0.9,
        "script": sc.ext_res("Script", "res://scripts/effects/flicker_light.gd"),
        "base_energy": 1.1, "min_interval": 3.0, "max_interval": 8.0, "dead_chance": 0.35, "buzz_sound": SN("tube_buzz"),
    })
    sc.node("Pool", "PointLight2D", ".", {
        "position": V2(14, -20), "color": Col(1, 0.85, 0.6), "energy": 0.5, "range_item_cull_mask": 3,
        "texture": sc.ext_res("Texture2D", "res://art/lights/radial.png"), "texture_scale": 1.1,
    })
    sc.node("LightZone", "Area2D", ".", {"script": sc.ext_res("Script", "res://scripts/interactables/light_zone.gd")})
    sc.node("Shape", "CollisionShape2D", "LightZone", {"position": V2(14, -20), "shape": sc.sub_res("RectangleShape2D", {"size": V2(96, 40)})})
    sc.save("scenes/props/street/street_lamp.tscn")


def build_street():
    rng = random.Random(11)
    sc = Scene()
    sc.node("Street", "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/levels/street_level.gd"),
        "ambience": Raw('Array[StringName]([&"amb_street"])'),
        "ambience_volume_db": -3.0,
    })
    sc.node("CanvasModulate", "CanvasModulate", ".", {"color": Col(0.22, 0.25, 0.36)})

    # --- far background in its own canvas layer (not darkened by the level modulate)
    sc.node("Backdrop", "CanvasLayer", ".", {"layer": -1})
    sc.node("BackdropModulate", "CanvasModulate", "Backdrop", {"color": Col(0.62, 0.64, 0.75)})
    sc.node("Sky", "Parallax2D", "Backdrop", {"scroll_scale": V2(0.02, 0.0), "repeat_size": V2(480, 0), "repeat_times": 3})
    sc.node("Sprite", "Sprite2D", "Backdrop/Sky", {"texture": sc.ext_res("Texture2D", "res://" + CITY + "sky.png"), "centered": False})
    sc.node("Far", "Parallax2D", "Backdrop", {"scroll_scale": V2(0.12, 0.0), "repeat_size": V2(960, 0), "repeat_times": 2})
    sc.node("Glow", "Sprite2D", "Backdrop/Far", {"position": V2(0, 118), "texture": sc.ext_res("Texture2D", "res://" + CITY + "fire_glow.png"), "centered": False})
    sc.node("Skyline", "Sprite2D", "Backdrop/Far", {"position": V2(0, 104), "texture": sc.ext_res("Texture2D", "res://" + CITY + "skyline_far.png"), "centered": False})
    sc.node("Mid", "Parallax2D", "Backdrop", {"scroll_scale": V2(0.35, 0.0), "repeat_size": V2(960, 0), "repeat_times": 2})
    sc.node("Buildings", "Sprite2D", "Backdrop/Mid", {"position": V2(0, 62), "texture": sc.ext_res("Texture2D", "res://" + CITY + "buildings_mid.png"), "centered": False, "modulate": Col(0.75, 0.78, 0.9, 1)})

    # --- facades (main back plane)
    sc.node("Facades", "Node2D", ".", {"z_index": -20})
    segs = [("seg_store", False), ("seg_shops", False), ("seg_alley", False), ("seg_apartment", False), ("seg_burnt", False),
            ("seg_lot", False), ("seg_shops", True), ("seg_alley", True), ("seg_school", False)]
    x = 0
    seg_x = {}
    for i, (s, flip) in enumerate(segs):
        w, h = png_size(ART + s + ".png")
        sc.node(f"{s}_{i}", "Sprite2D", "Facades", {
            "light_mask": 2, "position": V2(x, FLOOR_Y - h), "texture": sc.ext_res("Texture2D", f"res://{ART}{s}.png"),
            "centered": False, "flip_h": flip,
        })
        seg_x.setdefault(s, x)
        x += w
    assert x >= WIDTH - 5, x

    # --- ground tiles
    cells = []
    cols = WIDTH // 16 + 1
    for cx in range(-1, cols + 1):
        cells.append((cx, FLOOR_Y // 16, 0, rng.choice([0, 0, 0, 1, 2, 2, 3, 5, 6, 7, 4 if rng.random() < 0.1 else 0]), 0, 0))
        cells.append((cx, FLOOR_Y // 16 + 1, 0, rng.choice([0, 1, 2, 3, 4, 5, 6, 7]), 1, 0))
        cells.append((cx, FLOOR_Y // 16 + 2, 0, rng.choice([0, 1, 2, 3, 4, 0, 4, 5, 6, 7]), 2, 0))
    for y in range(-2, FLOOR_Y // 16):
        cells.append((-1, y, 0, rng.randrange(4), 3, 0))
        cells.append((cols, y, 0, rng.randrange(4), 3, 0))
    sc.node("Tiles", "TileMapLayer", ".", {
        "z_index": -5, "tile_map_data": tile_map_data(cells),
        "tile_set": sc.ext_res("TileSet", "res://resources/tilesets/street_tiles.tres"),
    })
    # ground decals
    sc.node("Decals", "Node2D", ".", {"z_index": -4})
    for i, dx in enumerate([540, 1240, 1790, 2210]):
        sc.node(f"Blood{i}", "Sprite2D", "Decals", {"position": V2(dx, 236 + (i % 2) * 8), "texture": sc.ext_res("Texture2D", "res://" + ART + "blood_decal.png"), "flip_h": i % 2 == 1})

    # --- props
    sc.node("Props", "Node2D", ".", {"z_index": -10})
    P = "res://scenes/props/street/"
    I = "res://scenes/interactables/street/"
    placements = [
        ("Barrier1", P + "barrier.tscn", 262),
        ("Grass1", I + "grass_patch.tscn", 372),
        ("Car1", P + "car_sedan_blue.tscn", 486),
        ("TrashBags1", P + "trash_bags.tscn", 612),
        ("Dumpster1", I + "dumpster.tscn", 716),
        ("FireBarrel", P + "fire_barrel.tscn", 870),
        ("Grass2", I + "grass_small.tscn", 1024),
        ("Barrier2", P + "barrier.tscn", 1070),
        ("Van", P + "car_van.tscn", 1156),
        ("BusStop", P + "bus_stop.tscn", 1296),
        ("Grass3", I + "grass_patch.tscn", 1380),
        ("Lamp", P + "street_lamp.tscn", 1480),
        ("RoadSign", P + "road_sign.tscn", 1552),
        ("CarHide", I + "car_hide.tscn", 1620),
        ("Cone1", P + "cone.tscn", 1690),
        ("DeadTree", P + "dead_tree.tscn", 1770),
        ("Bush", P + "bush.tscn", 1840),
        ("Grass4", I + "grass_patch.tscn", 1920),
        ("Barrier3", P + "barrier.tscn", 2046),
        ("TrashBags2", P + "trash_bags.tscn", 2120),
        ("Dumpster2", I + "dumpster.tscn", 2172),
        ("Grass5", I + "grass_small.tscn", 2400),
    ]
    for name, path, px in placements:
        sc.node(name, None, "Props", {"position": V2(px, FLOOR_Y)}, instance=sc.ext_res("PackedScene", path))

    # --- zombies
    sc.node("Zombies", "Node2D", ".", {"z_index": -1})
    Z = sc.ext_res("PackedScene", "res://scenes/enemies/zombie.tscn")
    fr = {v: sc.ext_res("SpriteFrames", f"res://art/characters/zombie_{v}/zombie_{v}_frames.tres") for v in "abc"}
    zombies = [
        # name, x, variant, behavior(0 patrol,1 wander,2 linger), left, right, facing
        ("Walker", 660, "a", 0, -80, 110, -1),
        ("Doorman", 960, "b", 2, -20, 20, -1),
        ("Drifter", 1300, "c", 1, -90, 110, 1),
        ("Pacer", 1820, "a", 0, -100, 110, -1),
        ("GateGuard", 2330, "b", 2, -30, 40, -1),
    ]
    for name, zx, v, beh, l, r, f in zombies:
        n = sc.node(name, None, "Zombies", {"position": V2(zx, FLOOR_Y), "frames": fr[v], "start_facing": f}, instance=Z)
        sc.node("PatrolComponent", None, f"Zombies/{name}", {"behavior": beh, "left": float(l), "right": float(r)})

    # --- triggers
    sc.node("Triggers", "Node2D", ".", {})
    tz = sc.ext_res("Script", "res://scripts/interactables/trigger_zone.gd")
    for name, tx, w in [("FirstSight", 300, 30), ("BreathHint", 560, 20), ("HideHint", 690, 20)]:
        sc.node(name, "Area2D", "Triggers", {"position": V2(tx, 200), "script": tz})
        sc.node("Shape", "CollisionShape2D", f"Triggers/{name}", {"shape": sc.sub_res("RectangleShape2D", {"size": V2(w, 80)})})
    sc.node("ExitZone", "Area2D", ".", {"position": V2(2540, 200), "script": tz})
    sc.node("Shape", "CollisionShape2D", "ExitZone", {"shape": sc.sub_res("RectangleShape2D", {"size": V2(40, 100)})})

    # --- ambient light (moon)
    sc.node("Lights", "Node2D", ".", {})
    sc.node("Moon", "DirectionalLight2D", "Lights", {
        "color": Col(0.55, 0.64, 0.9), "energy": 0.35, "shadow_enabled": True, "shadow_item_cull_mask": 1,
        "rotation": 0.35, "max_distance": 600.0,
    })
    radial_l = sc.ext_res("Texture2D", "res://art/lights/radial_large.png")
    for i, (lx, ly, col, e) in enumerate([(1016, 90, (1, 0.72, 0.4), 0.35), (2400, 80, (1, 0.72, 0.4), 0.3), (1170, 200, (0.4, 0.5, 0.8), 0.2)]):
        sc.node(f"Ambient{i}", "PointLight2D", "Lights", {"position": V2(lx, ly), "color": Col(*col), "energy": e, "range_item_cull_mask": 3, "texture": radial_l, "texture_scale": 0.5})

    # --- player & camera
    sc.node("Player", None, ".", {"position": V2(146, FLOOR_Y)}, instance=sc.ext_res("PackedScene", "res://scenes/player/player.tscn"))
    sc.node("GameCamera", "Camera2D", ".", {
        "position": V2(240, 135), "limit_left": 0, "limit_top": 0, "limit_right": WIDTH, "limit_bottom": 270,
        "script": sc.ext_res("Script", "res://scripts/systems/game_camera.gd"), "target_path": NP("../Player"),
        "look_ahead": 56.0,
    })
    # --- foreground
    sc.node("Foreground", "Parallax2D", ".", {"scroll_scale": V2(1.3, 1.0), "z_index": 20})
    for i, fx in enumerate([420, 1150, 1900, 2700, 3300]):
        sc.node(f"Pole{i}", "Sprite2D", "Foreground", {"position": V2(fx, 0), "texture": sc.ext_res("Texture2D", "res://" + ART + "fg_pole.png"), "centered": False})
    for i, fx in enumerate([80, 760, 1480, 2240, 3000]):
        sc.node(f"FgGrass{i}", "Sprite2D", "Foreground", {"position": V2(fx, 270), "texture": sc.ext_res("Texture2D", "res://" + ART + "fg_grass.png"), "centered": False, "offset": V2(0, -40)})

    sc.node("HUD", None, ".", {}, instance=sc.ext_res("PackedScene", "res://scenes/ui/hud.tscn"))
    sc.save("scenes/maps/street.tscn")


if __name__ == "__main__":
    build_tileset("resources/tilesets/street_tiles.tres", "res://art/environment/street/tiles.png")
    build_props()
    build_street()
    print("street ok")
