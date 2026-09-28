class_name RenderLayers
extends RefCounted
## z_index convention for all maps (same table as tools/builders/layers.py,
## explained in docs/rendering_layers.md). Use these names instead of
## ad-hoc numbers when placing nodes from code.

const BACKGROUND := -20
const BACKGROUND_DETAIL := -19
const PROPS := -10
const PROPS_FRONT := -9
const TILES := -5
const DECALS := -4
const CHARACTERS_BACK := -2
const ENEMIES := -1
const PLAYER := 0
const WORLD_FRONT := 2
const PROJECTILES := 3
const WORLD_FX := 5
const FOREGROUND := 20
const FOREGROUND_BLUR := 22
