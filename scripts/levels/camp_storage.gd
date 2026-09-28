extends Node2D
## The camp's storage corner. Its look follows the real items in
## GameState.storage (a few visual stages, not one sprite per bottle).
## The shelf in the middle opens the storage screen ([F] 互动).

@export var water_textures: Array[Texture2D] = []
@export var food_textures: Array[Texture2D] = []

@onready var water: Sprite2D = $Water
@onready var food: Sprite2D = $Food


func _ready() -> void:
	GameState.camp_changed.connect(_refresh)
	_refresh()


## Water: 0 -> nearly none, 1-4 -> a few bottles, 5-9 -> a small pile,
## 10+ -> an obvious stock. Food uses the same stages (few / some / plenty).
static func level_for(n: int) -> int:
	if n <= 0:
		return 0
	if n <= 4:
		return 1
	if n <= 9:
		return 2
	return 3


func _refresh() -> void:
	if water_textures.size() == 4:
		water.texture = water_textures[level_for(GameState.camp_water())]
	if food_textures.size() == 4:
		food.texture = food_textures[level_for(GameState.camp_food())]
