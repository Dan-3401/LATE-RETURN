"""Builds scenes/maps/school_camp.tscn."""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, V2, PV2, SN, NP, Raw, Col, tile_map_data, png_size  # noqa: E402
import layers as Z  # noqa: E402
import lighting as L  # noqa: E402
import foreground as F  # noqa: E402
from build_store import build_tileset  # noqa: E402

ART = "art/environment/camp/"
FLOOR_Y = 224
W = 640


def spr(sc, parent, name, tex, x, y=FLOOR_Y, light_mask=1, z=0, flip=False, bottom=True):
    w, h = png_size(tex)
    props = {"texture": sc.ext_res("Texture2D", "res://" + tex), "centered": False,
             "position": V2(x - w // 2, y - h if bottom else y)}
    if light_mask != 1:
        props["light_mask"] = light_mask
    if z:
        props["z_index"] = z
    if flip:
        props["flip_h"] = True
    sc.node(name, "Sprite2D", parent, props)


def build(hub=False):
    rng = random.Random(5)
    sc = Scene()
    if hub:
        sc.node("CampHub", "Node2D", None, {
            "script": sc.ext_res("Script", "res://scripts/levels/camp_hub_level.gd"),
            "ambience": Raw('Array[StringName]([&"amb_camp"])'),
            "ambience_volume_db": -6.0,
            "sister_pool": sc.ext_res("Resource", "res://resources/dialogue/sister_pool.tres"),
        })
    else:
        sc.node("SchoolCamp", "Node2D", None, {
            "script": sc.ext_res("Script", "res://scripts/levels/camp_level.gd"),
            "ambience": Raw('Array[StringName]([&"amb_camp"])'),
            "ambience_volume_db": -6.0,
            "cursor_crosshair": False,
            "dialogue": sc.ext_res("Resource", "res://resources/dialogue/ending.tres"),
        })
    sc.node("CanvasModulate", "CanvasModulate", ".", {"color": Col(0.2, 0.2, 0.28)})
    sc.node("Room", "Node2D", ".", {"z_index": Z.BACKGROUND})
    sc.node("BackWall", "Sprite2D", "Room", {"light_mask": 2, "texture": sc.ext_res("Texture2D", "res://" + ART + "backwall.png"), "centered": False})
    # door frame is painted at x 46..90; door sprite on top
    dw, dh = png_size(ART + "door.png")
    sc.node("Door", "Sprite2D", "Room", {"texture": sc.ext_res("Texture2D", "res://" + ART + "door.png"), "centered": False, "position": V2(46, 112), "light_mask": 2})
    # furniture
    sc.node("Furniture", "Node2D", ".", {"z_index": Z.PROPS})
    spr(sc, "Furniture", "Chairs", ART + "stacked_chairs.png", 136)
    spr(sc, "Furniture", "Supplies", ART + "supplies.png", 214)
    spr(sc, "Furniture", "Table", ART + "desk_table.png", 290)
    spr(sc, "Furniture", "Lamp", ART + "lamp.png", 278, FLOOR_Y - 34)
    spr(sc, "Furniture", "Bedroll", ART + "bedroll.png", 440)
    if hub:
        # the camp's shared storage: its look follows the real stock
        sc.node("Storage", "Node2D", "Furniture", {"position": V2(0, 0),
                                                  "script": sc.ext_res("Script", "res://scripts/levels/camp_storage.gd")})
        wtex = [sc.ext_res("Texture2D", f"res://{ART}water_storage_{i}.png") for i in range(4)]
        ftex = [sc.ext_res("Texture2D", f"res://{ART}food_storage_{i}.png") for i in range(4)]
        sw, sh = png_size(ART + "water_storage_0.png")
        fw, fh = png_size(ART + "food_storage_0.png")
        sc.node("Water", "Sprite2D", "Furniture/Storage", {"texture": wtex[0], "centered": False, "position": V2(530 - sw // 2, FLOOR_Y - sh)})
        sc.node("Food", "Sprite2D", "Furniture/Storage", {"texture": ftex[0], "centered": False, "position": V2(586 - fw // 2, FLOOR_Y - fh)})
        sc.nodes[-3] = (sc.nodes[-3][0], dict(sc.nodes[-3][1], **{
            "water_textures": Raw("Array[Texture2D]([" + ", ".join(wtex) + "])"),
            "food_textures": Raw("Array[Texture2D]([" + ", ".join(ftex) + "])")}))
    # candle (animated)
    atlas = sc.ext_res("Texture2D", "res://" + ART + "candle.png")
    subs = [sc.sub_res("AtlasTexture", {"atlas": atlas, "region": Raw(f"Rect2({f * 6}, 0, 6, 14)")}) for f in range(3)]
    fl = ", ".join("{\n\"duration\": 1.0,\n\"texture\": %s\n}" % s for s in subs)
    sf = sc.sub_res("SpriteFrames", {"animations": Raw('[{\n"frames": [' + fl + '],\n"loop": true,\n"name": &"default",\n"speed": 6.0\n}]')})
    sc.node("Candle", "AnimatedSprite2D", "Furniture", {"position": V2(312, FLOOR_Y - 41), "sprite_frames": sf, "autoplay": "default"})
    # tiles (wood floor)
    cells = []
    for cx in range(-1, W // 16 + 2):
        for row in range(3):
            cells.append((cx, FLOOR_Y // 16 + row, 0, rng.randrange(8), row, 0))
    for y in range(-2, FLOOR_Y // 16):
        cells.append((-1, y, 0, rng.randrange(4), 3, 0))
        cells.append((W // 16, y, 0, rng.randrange(4), 3, 0))
    sc.node("Tiles", "TileMapLayer", ".", {"z_index": Z.TILES, "tile_map_data": tile_map_data(cells),
                                           "tile_set": sc.ext_res("TileSet", "res://resources/tilesets/camp_tiles.tres")})
    # the sister (facing left, toward the door)
    sc.node("Sister", "Node2D", ".", {"position": V2(426, FLOOR_Y - 6), "z_index": Z.CHARACTERS_BACK,
                                      "script": sc.ext_res("Script", "res://scripts/actors/sister.gd")})
    sc.node("Sprite", "AnimatedSprite2D", "Sister", {
        "position": V2(0, -24), "flip_h": True,
        "sprite_frames": sc.ext_res("SpriteFrames", "res://art/characters/sister/sister_frames.tres"),
        "animation": SN("sit_down"), "autoplay": "sit_down",
    })
    bw, bh = png_size(ART + "blanket.png")
    sc.node("Blanket", "Sprite2D", "Sister", {"texture": sc.ext_res("Texture2D", "res://" + ART + "blanket.png"), "centered": False,
                                              "position": V2(-bw + 4, -bh + 2), "flip_h": True})
    # lights: warm lantern (the heart of the room), candle, cold window
    sc.node("Lights", "Node2D", ".", {})
    rl = sc.ext_res("Texture2D", "res://art/lights/radial_large.png")
    r = sc.ext_res("Texture2D", "res://art/lights/radial.png")
    sc.node("Lamp", "PointLight2D", "Lights", {"position": V2(278, FLOOR_Y - 42), "color": Col(1, 0.72, 0.42), "energy": 1.25,
                                               "range_item_cull_mask": 3, "shadow_enabled": True, "shadow_item_cull_mask": 1,
                                               "texture": rl, "texture_scale": 1.1})
    sc.node("Candle", "PointLight2D", "Lights", {"position": V2(312, FLOOR_Y - 48), "color": Col(1, 0.6, 0.3), "energy": 0.6,
                                                 "range_item_cull_mask": 3, "texture": r, "texture_scale": 0.6,
                                                 "script": sc.ext_res("Script", "res://scripts/effects/flicker_light.gd"),
                                                 "base_energy": 0.6, "min_interval": 0.2, "max_interval": 0.8, "dead_chance": 0.0})
    sc.node("Nightlight", "PointLight2D", "Lights", {"position": V2(452, FLOOR_Y - 20), "color": Col(1, 0.7, 0.45), "energy": 0.45,
                                                     "range_item_cull_mask": 3, "texture": r, "texture_scale": 0.7})
    sc.node("Window", "PointLight2D", "Lights", {"position": V2(470, 110), "color": Col(0.5, 0.6, 0.9), "energy": 0.5,
                                                 "range_item_cull_mask": 3, "texture": sc.ext_res("Texture2D", "res://art/lights/window_beam.png"),
                                                 "texture_scale": 0.8})
    # layered light: a weak cold fill for the whole room, the window light
    # pooling on the floor, cold air-light through the door crack, and soft
    # warm glows around the lamp, the candle and the nightlight
    L.light(sc, "Lights", "RoomFill", (320, 120), (0.45, 0.5, 0.72), 0.2, "soft_wide.png", 3.0)
    L.light(sc, "Lights", "WindowFloor", (500, FLOOR_Y - 4), (0.5, 0.6, 0.92), 0.4, "floor_spill.png", 1.3)
    L.light(sc, "Lights", "DoorCrack", (68, FLOOR_Y - 52), (0.45, 0.55, 0.86), 0.32, "door_slit.png", 1.2)
    L.glow(sc, "Lights", "LampGlow", (278, FLOOR_Y - 44), (1, 0.72, 0.42), 1.5, 0.3)
    L.glow(sc, "Lights", "CandleGlow", (312, FLOOR_Y - 48), (1, 0.6, 0.3), 0.6, 0.32)
    L.glow(sc, "Lights", "NightGlow", (452, FLOOR_Y - 20), (1, 0.7, 0.45), 0.7, 0.2)
    # dust
    sc.node("Dust", "CPUParticles2D", ".", {"position": V2(300, 150), "amount": 18, "lifetime": 10.0, "preprocess": 10.0,
                                            "texture": sc.ext_res("Texture2D", "res://art/fx/pixel.png"), "emission_shape": 3,
                                            "emission_rect_extents": V2(120, 60), "direction": V2(1, 0.2), "spread": 180.0,
                                            "gravity": V2(0, 1), "initial_velocity_min": 1.0, "initial_velocity_max": 3.0,
                                            "color": Col(1, 0.9, 0.75, 0.45)})
    if hub:
        # interactions: the classroom door (go out) and the sister (talk / end the day)
        itc = sc.ext_res("Script", "res://scripts/interactables/interactable.gd")
        sc.node("DoorInteract", "Area2D", ".", {"position": V2(68, FLOOR_Y - 20), "script": itc, "prompt_text": "外出", "prompt_offset": V2(0, -94)})
        sc.node("Shape", "CollisionShape2D", "DoorInteract", {"shape": sc.sub_res("RectangleShape2D", {"size": V2(40, 40)})})
        sc.node("SisterInteract", "Area2D", ".", {"position": V2(420, FLOOR_Y - 20), "script": itc, "prompt_text": "与妹妹交谈", "prompt_offset": V2(0, -44)})
        sc.node("Shape", "CollisionShape2D", "SisterInteract", {"shape": sc.sub_res("RectangleShape2D", {"size": V2(44, 40)})})
    # player (enters from the door)
    sc.node("Player", None, ".", {"position": V2(60 if not hub else 250, FLOOR_Y)}, instance=sc.ext_res("PackedScene", "res://scenes/player/player.tscn"))
    sc.node("GameCamera", "Camera2D", ".", {"position": V2(330, 135), "limit_left": 0, "limit_top": 0, "limit_right": W, "limit_bottom": 270,
                                            "script": sc.ext_res("Script", "res://scripts/systems/game_camera.gd"), "target_path": NP("../Player")})
    # near-camera layers: the door frame edge, the window curtain, washing on a line; a chair right at the lens
    F.layer(sc, "Foreground", 1.25)
    F.piece(sc, "Foreground", "DoorFrame", "door_frame.png", F.at(-6, 0, 1.25))
    F.piece(sc, "Foreground", "Curtain", "camp_curtain.png", F.at(448, 160, 1.25), "top")
    F.piece(sc, "Foreground", "Laundry", "camp_laundry.png", F.at(150, 60, 1.25), "top")
    F.layer(sc, "ForegroundBlur", 1.6, blur=True)
    F.piece(sc, "ForegroundBlur", "Chair", "camp_chair_blur.png", F.at(330, 120, 1.6))
    sc.node("DialoguePlayer", "Node", ".", {"script": sc.ext_res("Script", "res://scripts/systems/dialogue_player.gd")})
    sc.node("HUD", None, ".", {}, instance=sc.ext_res("PackedScene", "res://scenes/ui/hud.tscn"))
    if hub:
        sc.node("RegionMap", None, ".", {}, instance=sc.ext_res("PackedScene", "res://scenes/ui/region_map.tscn"))
        sc.node("ConfirmDialog", None, ".", {}, instance=sc.ext_res("PackedScene", "res://scenes/ui/confirm_dialog.tscn"))
        sc.save("scenes/maps/camp_hub.tscn")
        return
    sc.node("Letterbox", "CanvasLayer", ".", {"layer": 8})
    sc.node("Top", "ColorRect", "Letterbox", {"offset_right": 480.0, "offset_bottom": 22.0, "color": Col(0, 0, 0, 1), "mouse_filter": 2})
    sc.node("Bottom", "ColorRect", "Letterbox", {"offset_top": 248.0, "offset_right": 480.0, "offset_bottom": 270.0, "color": Col(0, 0, 0, 1), "mouse_filter": 2})
    sc.save("scenes/maps/school_camp.tscn")


if __name__ == "__main__":
    build_tileset("resources/tilesets/camp_tiles.tres", "res://art/environment/camp/tiles.png")
    build()
    build(hub=True)
    print("camp ok")
