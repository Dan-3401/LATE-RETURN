# Rendering layers, lighting and foreground

The z_index table lives in two places that must stay identical:
`tools/builders/layers.py` (used by the scene builders) and
`scripts/systems/render_layers.gd` (`RenderLayers.*`, used from code).
Do not fix a draw-order problem with an ad-hoc z_index — pick the layer.

| Order (back → front) | How | z_index / layer |
|---|---|---|
| Far background (sky, skyline, far buildings) | `Backdrop` CanvasLayer + Parallax2D (< 1) | CanvasLayer `-1` |
| Background (back wall, facades, room) | `BACKGROUND` | -20 |
| Things painted on the back wall (warehouse door) | `BACKGROUND_DETAIL` | -19 |
| Shade patches (alley / awning darkness) | `lighting.shade()` | -15 |
| Furniture, cars, containers | `PROPS` | -10 |
| Doors in front of props | `PROPS_FRONT` | -9 |
| Floor tiles | `TILES` | -5 |
| Floor clutter / decals | `DECALS` | -4 |
| Characters behind the player (the sister) | `CHARACTERS_BACK` | -2 |
| Zombies | `ENEMIES` | -1 |
| Player | `PLAYER` | 0 |
| Grass the player walks "into" | `WORLD_FRONT` | 2 |
| Thrown bottles | `PROJECTILES` | 3 |
| World effects: dust, glow halos | `WORLD_FX` | 5 |
| Foreground (sharp, near the camera) | `Foreground` Parallax2D ~1.25-1.3 | 20 |
| Foreground blur (almost at the lens) | `ForegroundBlur` Parallax2D ~1.6 | 22 |
| Lighting & screen effects | CanvasModulate, Light2D, vignettes | — |
| UI | CanvasLayers: WorldUI/HUD 10+, backpack 20, map 25, pause 30, save note 90, fades 100 | — |

## Pixel art + atmospheric lighting

* Every sprite, tile and UI texture uses the project default **Nearest**
  filter at the 480×270 integer-scaled viewport. Nothing is scaled up
  smoothly.
* Light is atmosphere and may be smooth: `tools/art/gen_lights.py` makes
  soft light textures (flashlight cone, radial, `soft_wide`, `sky_wash`,
  `floor_spill`, window beam, door slit). Flashlight and moon shadows use
  PCF filtering for softer edges.
* Only two kinds of node may use LINEAR filtering: glow halos / shade
  patches (`halo.png`, built by `tools/builders/lighting.py`) and the
  pieces of a `ForegroundBlur` layer. `tools/tests/test_visual_layers.gd`
  enforces this.
* Each map layers its lights instead of darkening everything:
  * store — cold CanvasModulate base, cold window/door ambient, moon beam
    and its floor pool, a warm lantern, sign / tube glows, flashlight;
  * street & region — sky/moon wash over the open stretches, dark alleys
    with shade patches, broken street lamps and fire barrels with halos,
    moon DirectionalLight with occluder shadows, flashlight;
  * camp — weak cold room fill, warm lamp and candle with glows, a
    nightlight, cold window light pooling on the floor, door-crack light;
  * warehouse — nearly dark: faint fill, cold door spill, a red emergency
    lamp, a dying bulb, flashlight.

## Gameplay exposure

Visual light and the stealth rule are deliberately decoupled.
`LightZone.exposure` (-1..1) is placed by hand: lamp pools and fire barrels
are positive (presence up to +0.35), alleys / under the bus stop / the
storeroom corner are negative (presence up to -0.12). The brightest zone
wins; shadow only counts where no light overlaps.

## Foreground

* `tools/art/gen_foreground.py` draws the pieces (`art/environment/foreground/`):
  sharp silhouettes and `*_blur.png` pieces (upscaled ×2, Gaussian-blurred,
  lower contrast). No green — green belongs to hide spots.
* `tools/builders/foreground.py` places them; `at(screen_x, cam_left, scroll)`
  computes the position that shows a piece at `screen_x` when the camera's
  left edge is at `cam_left`.
* Foreground is pure visuals: Sprite2D only, never a collision shape or an
  occluder (tested).
* `ForegroundFader` fades any piece to ~35% (blur: ~22%) while it covers the
  player, a zombie, an interactable, a container, a hide spot or a pickup,
  and brings it back afterwards.
