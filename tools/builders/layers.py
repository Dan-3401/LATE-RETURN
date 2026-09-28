"""Rendering layer / z_index convention for every map (keep in sync with
scripts/systems/render_layers.gd and docs/rendering_layers.md).

Back to front:
  Far background     Backdrop CanvasLayer (layer -10) + Parallax2D (sky, skyline)
  Background         BACKGROUND, BACKGROUND_DETAIL
  World / gameplay   PROPS, PROPS_FRONT, TILES, DECALS
  Characters         CHARACTERS_BACK, ENEMIES, PLAYER
  World front        WORLD_FRONT (grass the player walks "into"), PROJECTILES
  World effects      WORLD_FX (dust, glow halos, sparks)
  Foreground         FOREGROUND (sharp near-camera silhouettes, Parallax2D > 1)
  Foreground blur    FOREGROUND_BLUR (very near, blurred, faster parallax)
  Lighting / screen  CanvasModulate + Light2D (no z), screen-space CanvasLayers
  UI                 CanvasLayers >= 10 (HUD 10+, menus 20+, fades 100)
"""

BACKGROUND = -20
BACKGROUND_DETAIL = -19
PROPS = -10
PROPS_FRONT = -9
TILES = -5
DECALS = -4
CHARACTERS_BACK = -2
ENEMIES = -1
PLAYER = 0
WORLD_FRONT = 2
PROJECTILES = 3
WORLD_FX = 5
FOREGROUND = 20
FOREGROUND_BLUR = 22
