class_name HearingComponent
extends Node
## Listens to NoiseSystem. A heard noise only reveals where it happened.
## Solid walls between the noise and the listener halve its reach.

signal heard(event: Dictionary, intensity: float)

@export var wall_mask: int = 1

var listener: Node2D
var multiplier := 1.0
var enabled := true


func setup(l: Node2D, mult: float) -> void:
	listener = l
	multiplier = mult
	NoiseSystem.noise_emitted.connect(_on_noise)


func _on_noise(ev: Dictionary) -> void:
	if not enabled or listener == null or ev.source == listener:
		return
	var ear := listener.global_position + Vector2(0, -36)
	var d := ear.distance_to(ev.position)
	var r: float = ev.radius * multiplier
	if d > r:
		return
	var q := PhysicsRayQueryParameters2D.create(ev.position + Vector2(0, -12), ear, wall_mask)
	q.exclude = [listener.get_rid()]
	if not listener.get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		r *= 0.5
		if d > r:
			return
	heard.emit(ev, 1.0 - d / r)
