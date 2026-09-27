extends Node2D
## The camp's shared storage. Its look follows GameState.camp.

@export var water_textures: Array[Texture2D] = []
@export var food_textures: Array[Texture2D] = []

@onready var water: Sprite2D = $Water
@onready var food: Sprite2D = $Food


func _ready() -> void:
	GameState.camp_changed.connect(_refresh)
	_refresh()


static func level_for(n: int) -> int:
	if n <= 0:
		return 0
	if n <= 3:
		return 1
	if n <= 7:
		return 2
	return 3


func _refresh() -> void:
	if water_textures.size() == 4:
		water.texture = water_textures[level_for(int(GameState.camp.water))]
	if food_textures.size() == 4:
		food.texture = food_textures[level_for(int(GameState.camp.food))]
