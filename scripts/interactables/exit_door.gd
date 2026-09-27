class_name ExitDoor
extends Node2D
## Level exit. Locked until `is_unlocked()`; approaching while locked makes
## the player mutter `locked_line`.

signal exit_requested(actor: Node2D)

@export var locked_line := "还没有搜集到足够的物资呢。"
@export var prompt := "离开"
@export var open_texture: Texture2D
@export var locked_line_cooldown := 6.0

var unlocked := false
var _line_cd := 0.0

@onready var interactable: Interactable = $Interactable
@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	interactable.prompt_text = prompt
	interactable.condition = func(_a): return unlocked
	interactable.actor_near.connect(_on_actor_near)
	interactable.interacted.connect(_on_interacted)


func _process(delta: float) -> void:
	_line_cd = maxf(_line_cd - delta, 0.0)


func set_unlocked(v: bool) -> void:
	unlocked = v


func _on_actor_near(actor: Node2D, near: bool) -> void:
	if near and not unlocked and _line_cd <= 0.0 and actor.has_method(&"say"):
		if actor.has_method(&"is_dead") and actor.call(&"is_dead"):
			return
		if "state" in actor and actor.state != Player.State.NORMAL:
			return
		_line_cd = locked_line_cooldown
		actor.call(&"say", locked_line)


func _on_interacted(actor: Node2D) -> void:
	if not unlocked:
		return
	interactable.enabled = false
	if open_texture:
		sprite.texture = open_texture
	AudioManager.play_at(&"door_open", global_position + Vector2(0, -40), -2.0)
	exit_requested.emit(actor)
