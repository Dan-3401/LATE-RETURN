class_name InteractionComponent
extends Area2D
## Finds the best Interactable in range, shows its prompt, triggers it.

signal focus_changed(target: Interactable)

var actor: Node2D
var focused: Interactable = null
var enabled := true
var _candidates: Array[Interactable] = []


func _ready() -> void:
	actor = get_parent() as Node2D
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(a: Area2D) -> void:
	if a is Interactable and not _candidates.has(a):
		_candidates.append(a)
		a.on_actor_near(actor, true)


func _on_area_exited(a: Area2D) -> void:
	if a is Interactable:
		_candidates.erase(a)
		a.on_actor_near(actor, false)


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	if enabled:
		var best_score := INF
		for c in _candidates:
			if not is_instance_valid(c) or not c.can_interact(actor):
				continue
			var d := c.global_position.distance_to(actor.global_position) - c.focus_priority * 100.0
			if d < best_score:
				best_score = d
				best = c
	if best != focused:
		if is_instance_valid(focused):
			focused.set_focused(false)
		focused = best
		if focused:
			focused.set_focused(true)
		focus_changed.emit(focused)


func try_interact() -> bool:
	if enabled and is_instance_valid(focused) and focused.can_interact(actor):
		focused.interact(actor)
		return true
	return false


func clear() -> void:
	if is_instance_valid(focused):
		focused.set_focused(false)
	focused = null
