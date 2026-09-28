class_name HideSpot
extends Node2D
## A formal hiding place (dumpster, car...). Inside, Presence = 0.
## Zombies that saw the player get in will still come and search.

@export var hide_offset := Vector2.ZERO
@export var exit_offset := Vector2(0, 0)
@export var occupied_texture: Texture2D
@export var prompt_exit := "离开"

var occupant: Player = null
var _normal_texture: Texture2D
var _shake: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"hide_spot")
	_normal_texture = sprite.texture
	interactable.prompt_text = "躲藏"
	interactable.interacted.connect(_on_interacted)
	interactable.condition = func(a): return occupant == null and a is Player and a.state == Player.State.NORMAL


func _on_interacted(actor: Node2D) -> void:
	if occupant != null or not actor is Player:
		return
	occupant = actor
	actor.enter_hide(self, global_position + hide_offset)
	if occupied_texture:
		sprite.texture = occupied_texture
	interactable.enabled = false
	AudioManager.play_at(&"hide_enter", global_position, -4.0)
	NoiseSystem.emit_noise(global_position, 34.0, actor, &"hide")
	_wiggle(1.0)
	var ui := WorldUI.get_instance(self)
	if ui:
		ui.show_prompt(self, "[F] %s" % prompt_exit, global_position + Vector2(0, -sprite.texture.get_height() - 8))


func release(actor: Node2D) -> void:
	if occupant != actor:
		return
	occupant = null
	actor.call(&"exit_hide", global_position + exit_offset)
	sprite.texture = _normal_texture
	interactable.enabled = true
	AudioManager.play_at(&"hide_exit", global_position, -4.0)
	NoiseSystem.emit_noise(global_position, 34.0, actor, &"hide")
	_wiggle(0.6)
	var ui := WorldUI.get_instance(self)
	if ui:
		ui.hide_prompt(self)


## Space while hiding: knock on the hiding place to lure the dead over.
## The sound comes from the spot itself (HIDE_LURE_NOISE).
const LURE_RADIUS := 190.0


func lure(actor: Node2D) -> void:
	if occupant != actor:
		return
	_wiggle(1.4)
	AudioManager.play_at(&"hide_enter", global_position, -1.0, 700.0, 0.15)
	AudioManager.play_at(&"knife_hit", global_position, -14.0, 700.0, 0.2)
	NoiseSystem.emit_noise(global_position + Vector2(0, -16), LURE_RADIUS, actor, &"hide_lure")


## A zombie is clawing at it.
func set_disturbed(on: bool) -> void:
	if on and (_shake == null or not _shake.is_running()):
		_wiggle(1.0)
		AudioManager.play_at(&"hide_enter", global_position, -8.0, 500.0, 0.2)


func _wiggle(strength: float) -> void:
	if _shake:
		_shake.kill()
	_shake = create_tween()
	for i in 3:
		_shake.tween_property(sprite, "position:x", strength, 0.05)
		_shake.tween_property(sprite, "position:x", -strength, 0.05)
	_shake.tween_property(sprite, "position:x", 0.0, 0.05)
