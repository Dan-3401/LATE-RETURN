"""Near-camera foreground layers for the scene builders.

Two Parallax2D layers per map, both with ForegroundFader (pieces fade while
they cover the player, zombies or interactables) and never any collision:
  Foreground       z FOREGROUND,       scroll ~1.25-1.3, sharp pixel art
  ForegroundBlur   z FOREGROUND_BLUR,  scroll ~1.6, pre-blurred, LINEAR
A piece placed at x shows up on screen at  x - camera_left * scroll,  so
to see it at screen x `sx` when the camera's left edge is at `cam`:
  x = sx + cam * scroll   (see at()).
"""
from tscn import V2, png_size
import layers as Z

FG = "art/environment/foreground/"
FADER = "res://scripts/effects/foreground_fader.gd"
TEXTURE_FILTER_LINEAR = 2


def at(screen_x, cam_left, scroll):
    return screen_x + cam_left * scroll


def layer(sc, name, scroll, blur=False, existing=False):
    props = {"scroll_scale": V2(scroll, 1.0), "z_index": Z.FOREGROUND_BLUR if blur else Z.FOREGROUND,
             "script": sc.ext_res("Script", FADER)}
    if blur:
        props.update({"texture_filter": TEXTURE_FILTER_LINEAR, "visible_alpha": 0.9, "faded_alpha": 0.22})
    sc.node(name, "Parallax2D", ".", props)
    return name


def piece(sc, layer_name, name, tex, x, anchor="bottom", flip=False, y=None):
    """anchor: 'top' hangs from the top edge, 'bottom' stands on the bottom edge."""
    w, h = png_size(FG + tex)
    if y is None:
        y = 0 if anchor == "top" else 270 - h
    return sc.node(name, "Sprite2D", layer_name, {
        "position": V2(x, y), "texture": sc.ext_res("Texture2D", "res://" + FG + tex),
        "centered": False, "flip_h": flip,
    })
