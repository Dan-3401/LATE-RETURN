class_name Interactable
extends Area2D
## Reusable interaction component. Owners connect to `interacted`
## and may set `condition` to gate availability.

signal interacted(actor: Node2D)
signal actor_near(actor: Node2D, near: bool)

@export var prompt_text := "互动"
## Optional line shown above "[F] prompt_text" (e.g. "机械零件 ×35").
@export var prompt_title := ""
@export var prompt_key := "F"
@export var prompt_offset := Vector2(0, -40)
@export var focus_priority := 0.0
@export var enabled := true:
	set(v):
		enabled = v
		if not v:
			set_focused(false)

## Optional Callable(actor) -> bool
var condition: Callable
var _focused := false


func _ready() -> void:
	add_to_group(&"interactable")
	collision_layer = 1 << 3
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_interact(actor: Node2D) -> bool:
	if not enabled:
		return false
	if condition.is_valid():
		return condition.call(actor)
	return true


func interact(actor: Node2D) -> void:
	interacted.emit(actor)


func on_actor_near(actor: Node2D, near: bool) -> void:
	actor_near.emit(actor, near)


func set_focused(value: bool) -> void:
	if value == _focused:
		return
	_focused = value
	var ui := WorldUI.get_instance(self)
	if ui == null:
		return
	if value:
		ui.show_prompt(self, _prompt_string(), global_position + prompt_offset)
	else:
		ui.hide_prompt(self)


func refresh_prompt() -> void:
	if _focused:
		var ui := WorldUI.get_instance(self)
		if ui:
			ui.show_prompt(self, _prompt_string(), global_position + prompt_offset)


func _prompt_string() -> String:
	var line := "[%s] %s" % [prompt_key, prompt_text]
	return line if prompt_title == "" else prompt_title + "\n" + line
