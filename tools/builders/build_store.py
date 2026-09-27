"""Builds scenes/maps/convenience_store.tscn (+ its TileSet and exit door)."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, V2, V2i, PV2, SN, NP, Raw, Col, tile_map_data, png_size, fmt  # noqa: E402
import props  # noqa: E402

ART = "art/environment/store/"
FLOOR_Y = 224
ROOM_W = 1024


def build_tileset(out="resources/tilesets/store_tiles.tres", tex="res://art/environment/store/tiles.png"):
    lines = ['[gd_resource type="TileSet" load_steps=4 format=3]', "",
             f'[ext_resource type="Texture2D" path="{tex}" id="1_tiles"]', "",
             '[sub_resource type="OccluderPolygon2D" id="occ_full"]',
             "polygon = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)", "",
             '[sub_resource type="TileSetAtlasSource" id="src_0"]',
             'texture = ExtResource("1_tiles")',
             "texture_region_size = Vector2i(16, 16)"]
    full = "PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)"
    for row, count in [(0, 8), (1, 8), (2, 8), (3, 4)]:
        for col in range(count):
            lines.append(f"{col}:{row}/0 = 0")
            lines.append(f"{col}:{row}/0/physics_layer_0/polygon_0/points = {full}")
            if row == 3:
                lines.append(f'{col}:{row}/0/occlusion_layer_0/polygon = SubResource("occ_full")')
    lines += ["", "[resource]",
              "occlusion_layer_0/light_mask = 3",
              "physics_layer_0/collision_layer = 1",
              "physics_layer_0/collision_mask = 0",
              'sources/0 = SubResource("src_0")', ""]
    path = os.path.join(os.path.dirname(__file__), "..", "..", out)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(lines))


def build_exit_door():
    sc = Scene()
    w, h = png_size(ART + "exit_door.png")
    sc.node("ExitDoor", "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/interactables/exit_door.gd"),
        "open_texture": sc.ext_res("Texture2D", "res://" + ART + "exit_door_open.png"),
    })
    props.add_sprite(sc, ".", ART + "exit_door.png")
    props.add_interactable(sc, ".", 44, 40, "离开", (0, -h + 18))
    # cold night light seeping through the glass
    sc.node("Glow", "PointLight2D", ".", {
        "position": V2(0, -48), "color": Col(0.55, 0.66, 0.9), "energy": 0.55,
        "range_item_cull_mask": 3, "shadow_enabled": True, "shadow_item_cull_mask": 1,
        "texture": sc.ext_res("Texture2D", "res://art/lights/radial_large.png"), "texture_scale": 0.55,
    })
    sc.node("Slit", "PointLight2D", ".", {
        "position": V2(0, -40), "color": Col(0.6, 0.7, 0.95), "energy": 0.5,
        "range_item_cull_mask": 3,
        "texture": sc.ext_res("Texture2D", "res://art/lights/door_slit.png"), "texture_scale": 1.0,
    })
    sc.save("scenes/interactables/store/exit_door.tscn")


def build_warehouse_door():
    sc = Scene()
    dw, dh = png_size(ART + "storeroom_door_open.png")
    sc.node("WarehouseDoor", "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/interactables/warehouse_door.gd"),
        "key_item": sc.ext_res("Resource", "res://resources/items/warehouse_key.tres"),
    })
    sc.node("OpenSprite", "Sprite2D", ".", {"visible": False, "light_mask": 2,
                                            "texture": sc.ext_res("Texture2D", "res://" + ART + "storeroom_door_open.png"),
                                            "centered": False, "offset": V2(-(dw // 2), -dh)})
    props.add_interactable(sc, ".", 30, 40, "互动", (0, -dh - 8))
    sc.save("scenes/interactables/store/warehouse_door.tscn")


def build_store():
    rng = random.Random(7)
    sc = Scene()
    sc.node("ConvenienceStore", "Node2D", None, {
        "script": sc.ext_res("Script", "res://scripts/levels/store_level.gd"),
        "ambience": Raw('Array[StringName]([&"amb_store", &"amb_wind_inside"])'),
        "ambience_volume_db": -4.0,
    })
    sc.node("CanvasModulate", "CanvasModulate", ".", {"color": Col(0.17, 0.19, 0.25)})

    # --- back wall (light_mask 2: receives furniture shadows)
    sc.node("Background", "Node2D", ".", {"z_index": -20})
    sc.node("BackWall", "Sprite2D", "Background", {
        "light_mask": 2,
        "texture": sc.ext_res("Texture2D", "res://" + ART + "backwall.png"),
        "centered": False,
    })
    lw, lh = png_size(ART + "ceiling_lamp_broken.png")
    sc.node("LampA", "Sprite2D", "Background", {"light_mask": 2, "position": V2(292, 22), "texture": sc.ext_res("Texture2D", "res://" + ART + "ceiling_lamp_broken.png"), "centered": False})
    sc.node("LampB", "Sprite2D", "Background", {"light_mask": 2, "position": V2(820, 22), "texture": sc.ext_res("Texture2D", "res://" + ART + "ceiling_lamp_broken.png"), "centered": False, "flip_h": True})
    sw, sh = png_size(ART + "exit_sign.png")
    sc.node("ExitSign", "Sprite2D", "Background", {"light_mask": 2, "position": V2(966 - sw // 2, 44), "texture": sc.ext_res("Texture2D", "res://" + ART + "exit_sign.png"), "centered": False})

    # --- tiles
    cells = []
    cols = ROOM_W // 16
    for x in range(-1, cols + 1):
        for row in range(3):
            v = rng.choice([0, 0, 0, 0, 1, 2, 3, 5, 5, 6, 7 if 3 < x < 9 else 0, 4 if 24 < x < 32 else 0])
            cells.append((x, FLOOR_Y // 16 + row, 0, v, row, 0))
    for y in range(0, FLOOR_Y // 16):
        cells.append((-1, y, 0, rng.randrange(4), 3, 0))
        cells.append((cols, y, 0, rng.randrange(4), 3, 0))
    sc.node("Tiles", "TileMapLayer", ".", {
        "z_index": -5,
        "tile_map_data": tile_map_data(cells),
        "tile_set": sc.ext_res("TileSet", "res://resources/tilesets/store_tiles.tres"),
    })

    # --- props (z -10: behind player)
    sc.node("Props", "Node2D", ".", {"z_index": -10, "y_sort_enabled": False})
    placements = [
        ("Cooler1", "res://scenes/interactables/store/cooler.tscn", 130),
        ("Cooler2", "res://scenes/interactables/store/cooler.tscn", 192),
        ("ShelfA", "res://scenes/interactables/store/shelf_a.tscn", 282),
        ("ShelfB", "res://scenes/interactables/store/shelf_b.tscn", 360),
        ("ShelfLow", "res://scenes/interactables/store/shelf_low.tscn", 494),
        ("ShelfC", "res://scenes/interactables/store/shelf_c.tscn", 652),
        ("MagazineRack", "res://scenes/props/store/magazine_rack.tscn", 717),
        ("Boxes", "res://scenes/interactables/store/boxes.tscn", 758),
        ("Counter", "res://scenes/interactables/store/counter_register.tscn", 846),
    ]
    for name, path, x in placements:
        sc.node(name, None, "Props", {"position": V2(x, FLOOR_Y)}, instance=sc.ext_res("PackedScene", path))

    # floor clutter in front of the furniture but behind the player
    sc.node("Clutter", "Node2D", ".", {"z_index": -4})
    clutter = [
        ("WetSign", "trash_wet_sign", 232), ("TrashPile", "trash_pile", 250), ("Basket", "trash_basket", 438),
        ("FallenShelf", "fallen_shelf", 568), ("Papers", "trash_papers", 614), ("Bottles", "trash_bottles", 700),
        ("TrashBag", "trash_bag", 906), ("Papers2", "trash_papers", 330),
    ]
    for name, scene, x in clutter:
        sc.node(name, None, "Clutter", {"position": V2(x, FLOOR_Y)}, instance=sc.ext_res("PackedScene", f"res://scenes/props/store/{scene}.tscn"))

    # --- back warehouse door (painted on the wall at x 40..76)
    sc.node("WarehouseDoor", None, ".", {"position": V2(58, FLOOR_Y), "z_index": -19},
            instance=sc.ext_res("PackedScene", "res://scenes/interactables/store/warehouse_door.tscn"))
    # --- exit
    sc.node("ExitDoor", None, ".", {"position": V2(966, FLOOR_Y), "z_index": -9}, instance=sc.ext_res("PackedScene", "res://scenes/interactables/store/exit_door.tscn"))

    # --- ambient lights
    sc.node("Lights", "Node2D", ".", {})
    radial = sc.ext_res("Texture2D", "res://art/lights/radial.png")
    radial_l = sc.ext_res("Texture2D", "res://art/lights/radial_large.png")
    beam = sc.ext_res("Texture2D", "res://art/lights/window_beam.png")
    sc.node("MoonBeam", "PointLight2D", "Lights", {
        "position": V2(452, 182), "color": Col(0.5, 0.62, 0.9), "energy": 0.55,
        "range_item_cull_mask": 3, "texture": beam,
    })
    sc.node("WindowGlow", "PointLight2D", "Lights", {
        "position": V2(430, 74), "color": Col(0.5, 0.6, 0.85), "energy": 0.45,
        "range_item_cull_mask": 3, "texture": radial, "texture_scale": 1.1,
    })
    sc.node("ExitSignGlow", "PointLight2D", "Lights", {
        "position": V2(966, 51), "color": Col(0.35, 0.9, 0.5), "energy": 0.55,
        "range_item_cull_mask": 3, "texture": radial, "texture_scale": 0.9,
    })
    sc.node("CounterTube", "PointLight2D", "Lights", {
        "position": V2(832, 44), "color": Col(0.75, 0.85, 0.95), "energy": 0.35,
        "range_item_cull_mask": 3, "shadow_enabled": True, "shadow_item_cull_mask": 1,
        "texture": radial_l, "texture_scale": 1.0,
        "script": sc.ext_res("Script", "res://scripts/effects/flicker_light.gd"),
        "base_energy": 0.35, "buzz_sound": SN("tube_buzz"),
    })
    sc.node("StoreroomDark", "PointLight2D", "Lights", {
        "position": V2(46, 190), "color": Col(0.4, 0.45, 0.6), "energy": 0.25,
        "range_item_cull_mask": 3, "texture": radial, "texture_scale": 0.6,
    })

    # --- dust motes drifting in the moon beam
    sc.node("Dust", "CPUParticles2D", ".", {
        "position": V2(460, 150), "z_index": 5, "amount": 26, "lifetime": 9.0, "preprocess": 9.0,
        "texture": sc.ext_res("Texture2D", "res://art/fx/pixel.png"),
        "emission_shape": 3, "emission_rect_extents": V2(80, 70),
        "direction": V2(1, 0.3), "spread": 180.0, "gravity": V2(0, 1.5),
        "initial_velocity_min": 1.0, "initial_velocity_max": 4.0,
        "color": Col(0.9, 0.9, 0.95, 0.55),
    })

    # --- player & camera
    sc.node("Player", None, ".", {"position": V2(98, FLOOR_Y)}, instance=sc.ext_res("PackedScene", "res://scenes/player/player.tscn"))
    sc.node("GameCamera", "Camera2D", ".", {
        "position": V2(240, 135),
        "limit_left": 0, "limit_top": 0, "limit_right": ROOM_W, "limit_bottom": 270,
        "script": sc.ext_res("Script", "res://scripts/systems/game_camera.gd"),
        "target_path": NP("../Player"),
    })

    # --- foreground silhouettes (parallax, in front of everything)
    sc.node("Foreground", "Parallax2D", ".", {"scroll_scale": V2(1.25, 1.0), "z_index": 20})
    sc.node("FgDebris", "Sprite2D", "Foreground", {"position": V2(260, 270), "texture": sc.ext_res("Texture2D", "res://" + ART + "fg_debris.png"), "centered": False, "offset": V2(0, -44)})
    sc.node("FgShelf", "Sprite2D", "Foreground", {"position": V2(1180, 150), "texture": sc.ext_res("Texture2D", "res://" + ART + "fg_shelf.png"), "centered": False})
    sc.node("FgCables", "Sprite2D", "Foreground", {"position": V2(560, 0), "texture": sc.ext_res("Texture2D", "res://" + ART + "fg_cables.png"), "centered": False})
    sc.node("FgDebris2", "Sprite2D", "Foreground", {"position": V2(1100, 270), "texture": sc.ext_res("Texture2D", "res://" + ART + "fg_debris.png"), "centered": False, "offset": V2(0, -44), "flip_h": True})

    # --- systems
    items = ["water", "canned_food", "biscuits", "noodles"]
    sc.node("LootDirector", "Node", ".", {
        "script": sc.ext_res("Script", "res://scripts/systems/loot_director.gd"),
        "fill_items": Raw(f"Array[{sc.ext_res('Script', 'res://scripts/data/item_data.gd')}]([" + ", ".join(str(sc.ext_res("Resource", f"res://resources/items/{i}.tres")) for i in items) + "])"),
        "refill_table": sc.ext_res("Resource", "res://resources/loot_tables/store_refill.tres"),
        "key_item": sc.ext_res("Resource", "res://resources/items/warehouse_key.tres"),
    })
    sc.node("HUD", None, ".", {}, instance=sc.ext_res("PackedScene", "res://scenes/ui/hud.tscn"))
    sc.save("scenes/maps/convenience_store.tscn")


if __name__ == "__main__":
    props.build_store_props()
    build_tileset()
    build_exit_door()
    build_warehouse_door()
    build_store()
    print("store ok")
