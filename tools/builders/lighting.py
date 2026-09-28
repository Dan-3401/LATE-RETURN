"""Layered-lighting helpers for the scene builders.

Pixel-art sprites stay Nearest. Lights and glows are atmosphere and may be
smooth: Light2D textures come from tools/art/gen_lights.py (soft falloff),
glow halos are unshaded additive sprites drawn with LINEAR filtering, shade
patches are unshaded dark sprites that deepen shadows (alleys, awnings).
Gameplay exposure is placed separately with exposure_zone() — visuals and
the stealth rule stay decoupled on purpose.
"""
from tscn import V2, Col
import layers as Z

LIGHTS = "res://art/lights/"
TEXTURE_FILTER_LINEAR = 2


def _tex(sc, name):
    return sc.ext_res("Texture2D", LIGHTS + name)


def light(sc, parent, name, pos, color, energy, tex="soft_wide.png", scale=1.0,
          mask=3, shadow=False, extra=None):
    """PointLight2D. mask 3 = lights the play plane and the back wall."""
    props = {
        "position": V2(*pos), "color": Col(*color), "energy": energy,
        "range_item_cull_mask": mask, "texture": _tex(sc, tex), "texture_scale": scale,
    }
    if shadow:
        props.update({"shadow_enabled": True, "shadow_item_cull_mask": 1,
                      "shadow_filter": 1, "shadow_filter_smooth": 1.5})
    if extra:
        props.update(extra)
    return sc.node(name, "PointLight2D", parent, props)


def _material(sc, kind):
    # one shared material per scene (cached on the scene object itself)
    cache = sc.__dict__.setdefault("_light_materials", {})
    if kind not in cache:
        # blend_mode 1 = add, light_mode 1 = unshaded
        blend = 1 if kind == "add" else 0
        cache[kind] = sc.sub_res("CanvasItemMaterial", {"blend_mode": blend, "light_mode": 1})
    return cache[kind]


def glow(sc, parent, name, pos, color, size=1.0, alpha=0.35, z=Z.WORLD_FX):
    """Soft additive halo around a light source (lamp, candle, sign)."""
    return sc.node(name, "Sprite2D", parent, {
        "position": V2(*pos), "z_index": z, "texture": _tex(sc, "halo.png"),
        "texture_filter": TEXTURE_FILTER_LINEAR, "material": _material(sc, "add"),
        "modulate": Col(color[0], color[1], color[2], alpha), "scale": V2(size, size),
    })


def shade(sc, parent, name, pos, size, alpha=0.45, z=-15):
    """Unshaded dark patch that deepens a shadow (alley mouth, under an
    awning). Sits right in front of the background, behind props and
    characters. size = (sx, sy) scale of the 128px halo texture."""
    return sc.node(name, "Sprite2D", parent, {
        "position": V2(*pos), "z_index": z, "texture": _tex(sc, "halo.png"),
        "texture_filter": TEXTURE_FILTER_LINEAR, "material": _material(sc, "mix"),
        "modulate": Col(0.0, 0.0, 0.02, alpha), "scale": V2(*size),
    })


def exposure_zone(sc, parent, name, pos, size, exposure):
    """Gameplay Exposure area (LightZone): >0 lit, <0 shadow."""
    n = sc.node(name, "Area2D", parent, {
        "position": V2(*pos),
        "script": sc.ext_res("Script", "res://scripts/interactables/light_zone.gd"),
        "exposure": float(exposure),
    })
    sc.node("Shape", "CollisionShape2D", n,
            {"shape": sc.sub_res("RectangleShape2D", {"size": V2(*size)})})
    return n
