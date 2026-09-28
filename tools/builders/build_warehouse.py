"""Builds the store's back warehouse (Demo 2): scenes/maps/warehouse.tscn."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, V2, PV2, SN, NP, Raw, Col, tile_map_data, png_size  # noqa: E402
import layers as Z  # noqa: E402
import lighting as L  # noqa: E402
import foreground as F  # noqa: E402
import props  # noqa: E402
from build_store import build_tileset  # noqa: E402

ART = "art/environment/store/"
FLOOR_Y = 224
W = 512


def build_props():
    props.container_scene("scenes/interactables/warehouse/staff_locker.tscn", ART + "locker.png", "staff_locker",
                          searched_tex=ART + "locker_open.png")
    props.container_scene("scenes/interactables/warehouse/storage_boxes.tscn", ART + "storage_boxes.png", "warehouse_boxes",
                          drop_y=24, searched_tex=ART + "storage_boxes_open.png")
    props.container_scene("scenes/interactables/warehouse/cleaning_shelf.tscn", ART + "cleaning_shelf.png", "cleaning",
                          searched_tex=ART + "cleaning_shelf_searched.png")
    # the hide-able locker: green paint + vine (same visual language as the street)
    sc = Scene()
    w, h = png_size(ART + "locker_hide.png")
    sc.node("HideLocker", "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/interactables/hide_spot.gd"),
        "occupied_texture": sc.ext_res("Texture2D", "res://" + ART + "locker_hide_closed.png"),
    })
    props.add_sprite(sc, ".", ART + "locker_hide.png")
    props.add_interactable(sc, ".", 30, 36, "躲藏", (0, -h - 6), priority=0.2)
    sc.save("scenes/interactables/warehouse/hide_locker.tscn")
    props.decor_scene("scenes/props/warehouse/mop_bucket.tscn", ART + "mop_bucket.png", occluder=False)


def build():
    rng = random.Random(3)
    sc = Scene()
    sc.node("Warehouse", "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/levels/warehouse_level.gd"),
        "ambience": Raw('Array[StringName]([&"amb_store"])'),
        "ambience_volume_db": -8.0,
    })
    sc.node("CanvasModulate", "CanvasModulate", ".", {"color": Col(0.1, 0.1, 0.14)})
    sc.node("Background", "Node2D", ".", {"z_index": Z.BACKGROUND})
    sc.node("Wall", "Sprite2D", "Background", {"light_mask": 2, "texture": sc.ext_res("Texture2D", "res://" + ART + "warehouse_wall.png"), "centered": False})
    # door back into the shop (painted like the storeroom door, standing open)
    dw, dh = png_size(ART + "storeroom_door_open.png")
    sc.node("DoorSprite", "Sprite2D", "Background", {"light_mask": 2, "texture": sc.ext_res("Texture2D", "res://" + ART + "storeroom_door_open.png"),
                                                     "centered": False, "position": V2(30, FLOOR_Y - dh)})
    cells = []
    for cx in range(-1, W // 16 + 2):
        for row in range(3):
            cells.append((cx, FLOOR_Y // 16 + row, 0, rng.randrange(8), row, 0))
    for y in range(-2, FLOOR_Y // 16):
        cells.append((-1, y, 0, rng.randrange(4), 3, 0))
        cells.append((W // 16, y, 0, rng.randrange(4), 3, 0))
    sc.node("Tiles", "TileMapLayer", ".", {"z_index": Z.TILES, "tile_map_data": tile_map_data(cells),
                                           "tile_set": sc.ext_res("TileSet", "res://resources/tilesets/warehouse_tiles.tres")})
    sc.node("Props", "Node2D", ".", {"z_index": Z.PROPS})
    I = "res://scenes/interactables/warehouse/"
    for name, path, x in [
        ("BoxesA", I + "storage_boxes.tscn", 120), ("CleaningShelf", I + "cleaning_shelf.tscn", 176),
        ("StaffLocker", I + "staff_locker.tscn", 300), ("StaffLocker2", I + "staff_locker.tscn", 342),
        ("HideLocker", I + "hide_locker.tscn", 404), ("BoxesB", I + "storage_boxes.tscn", 462),
    ]:
        sc.node(name, None, "Props", {"position": V2(x, FLOOR_Y)}, instance=sc.ext_res("PackedScene", path))
    sc.node("Clutter", "Node2D", ".", {"z_index": Z.DECALS})
    for name, path, x in [
        ("Mop", "res://scenes/props/warehouse/mop_bucket.tscn", 220), ("Fallen", "res://scenes/props/store/fallen_shelf.tscn", 250),
        ("Papers", "res://scenes/props/store/trash_papers.tscn", 150), ("Pile", "res://scenes/props/store/trash_pile.tscn", 372),
    ]:
        sc.node(name, None, "Clutter", {"position": V2(x, FLOOR_Y)}, instance=sc.ext_res("PackedScene", path))
    # light: the shop's weak light through the open door, one dying bulb
    sc.node("Lights", "Node2D", ".", {})
    r = sc.ext_res("Texture2D", "res://art/lights/radial.png")
    sc.node("DoorLight", "PointLight2D", "Lights", {"position": V2(48, FLOOR_Y - 34), "color": Col(0.45, 0.52, 0.7), "energy": 0.55,
                                                    "range_item_cull_mask": 3, "texture": sc.ext_res("Texture2D", "res://art/lights/door_slit.png"), "texture_scale": 1.3})
    sc.node("Bulb", "PointLight2D", "Lights", {"position": V2(330, 40), "color": Col(1, 0.8, 0.5), "energy": 0.3, "range_item_cull_mask": 3,
                                               "shadow_enabled": True, "shadow_item_cull_mask": 1, "texture": sc.ext_res("Texture2D", "res://art/lights/radial_large.png"),
                                               "texture_scale": 0.7, "script": sc.ext_res("Script", "res://scripts/effects/flicker_light.gd"),
                                               "base_energy": 0.3, "min_interval": 1.2, "max_interval": 4.0, "dead_chance": 0.6})
    # layered light (still a dark room): a barely-there fill, the door's cold
    # light spilling on the floor, a red emergency lamp over the lockers
    L.light(sc, "Lights", "Fill", (256, 120), (0.4, 0.45, 0.62), 0.14, "soft_wide.png", 2.6)
    L.light(sc, "Lights", "DoorSpill", (60, FLOOR_Y - 4), (0.45, 0.52, 0.72), 0.45, "floor_spill.png", 0.9)
    L.light(sc, "Lights", "Emergency", (452, 58), (1, 0.32, 0.26), 0.4, "radial.png", 0.7)
    sc.node("EmergencyLamp", "Sprite2D", "Lights", {"position": V2(452, 58), "texture": sc.ext_res("Texture2D", "res://art/fx/pixel.png"),
                                                    "scale": V2(4, 2), "modulate": Col(1, 0.35, 0.3, 1), "z_index": Z.WORLD_FX})
    L.glow(sc, "Lights", "EmergencyGlow", (452, 58), (1, 0.3, 0.25), 0.5, 0.3)
    L.glow(sc, "Lights", "BulbGlow", (330, 40), (1, 0.8, 0.5), 0.6, 0.18)
    L.exposure_zone(sc, ".", "Dark", (300, FLOOR_Y - 20), (360, 40), -0.4)
    sc.node("Dust", "CPUParticles2D", ".", {"position": V2(250, 150), "amount": 16, "lifetime": 10.0, "preprocess": 10.0,
                                            "texture": sc.ext_res("Texture2D", "res://art/fx/pixel.png"), "emission_shape": 3,
                                            "emission_rect_extents": V2(220, 60), "direction": V2(1, 0.2), "spread": 180.0,
                                            "gravity": V2(0, 1), "initial_velocity_min": 1.0, "initial_velocity_max": 3.0,
                                            "color": Col(0.9, 0.9, 0.95, 0.4)})
    itc = sc.ext_res("Script", "res://scripts/interactables/interactable.gd")
    sc.node("ExitDoor", "Area2D", ".", {"position": V2(48, FLOOR_Y - 20), "script": itc, "prompt_text": "回到店里", "prompt_offset": V2(0, -60)})
    sc.node("Shape", "CollisionShape2D", "ExitDoor", {"shape": sc.sub_res("RectangleShape2D", {"size": V2(30, 40)})})
    sc.node("Player", None, ".", {"position": V2(72, FLOOR_Y)}, instance=sc.ext_res("PackedScene", "res://scenes/player/player.tscn"))
    sc.node("GameCamera", "Camera2D", ".", {"position": V2(240, 135), "limit_left": 0, "limit_top": 0, "limit_right": W, "limit_bottom": 270,
                                            "script": sc.ext_res("Script", "res://scripts/systems/game_camera.gd"), "target_path": NP("../Player")})
    # near-camera: a hanging chain, boxes stacked right at the lens
    F.layer(sc, "Foreground", 1.25)
    F.piece(sc, "Foreground", "Chain", "chain.png", F.at(200, 0, 1.25), "top")
    F.piece(sc, "Foreground", "Chain2", "chain.png", F.at(330, 30, 1.25), "top", y=-30)
    F.layer(sc, "ForegroundBlur", 1.6, blur=True)
    F.piece(sc, "ForegroundBlur", "Boxes", "boxes_blur.png", F.at(300, 30, 1.6))
    items = sc.ext_res("Script", "res://scripts/data/item_data.gd")
    sc.node("LootDirector", "Node", ".", {
        "script": sc.ext_res("Script", "res://scripts/systems/loot_director.gd"),
        "world_prefix": "warehouse",
        "required": Raw("{}"), "bonus": Raw("{}"),
        "refill_table": sc.ext_res("Resource", "res://resources/loot_tables/warehouse_refill.tres"),
        "refill_chance": 0.25,
        "guaranteed_in": Raw('{\n"StaffLocker": %s\n}' % sc.ext_res("Resource", "res://resources/items/work_uniform.tres")),
    })
    sc.node("HUD", None, ".", {}, instance=sc.ext_res("PackedScene", "res://scenes/ui/hud.tscn"))
    sc.save("scenes/maps/warehouse.tscn")


if __name__ == "__main__":
    build_tileset("resources/tilesets/warehouse_tiles.tres", "res://art/environment/store/warehouse_tiles.png")
    build_props()
    build()
    print("warehouse ok")
