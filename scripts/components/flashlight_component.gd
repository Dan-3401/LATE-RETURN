class_name FlashlightComponent
extends Node
## Chest-mounted flashlight, independent from weapons.
## The beam follows the aim direction (mouse) or the facing direction.

signal toggled(on: bool)

## Beam lights share one transform. Two lights are used: one lights the
## player plane (light_mask 1, shadows from walls only) and one lights the
## back wall (light_mask 2, shadows from walls and furniture).
@export var beam_paths: Array[NodePath] = []
@export var spill_path: NodePath
@export var beam_energy := 1.15
@export var spill_energy := 0.45
@export var max_unarmed_pitch_deg := 38.0
@export var turn_speed := 14.0

var is_on := false
var angle := 0.0
var _beams: Array[PointLight2D] = []
var _spill: PointLight2D
var _flicker_timer := 6.0
var _flicker_left := 0.0


func _ready() -> void:
	for p in beam_paths:
		var l := get_node_or_null(p) as PointLight2D
		if l:
			_beams.append(l)
	_spill = get_node_or_null(spill_path)
	_apply()


func toggle() -> void:
	set_on(not is_on)


func set_on(value: bool, silent: bool = false) -> void:
	if value == is_on:
		return
	is_on = value
	if not silent:
		AudioManager.play(&"flashlight_click", -6.0)
	_apply()
	toggled.emit(is_on)


func _apply() -> void:
	for b in _beams:
		b.enabled = is_on
		b.energy = beam_energy
	if _spill:
		_spill.enabled = is_on
		_spill.energy = spill_energy


## facing: +1 / -1. aim_point: global mouse position. armed: follow mouse exactly.
func update(delta: float, origin: Vector2, facing: int, aim_point: Vector2, armed: bool) -> void:
	if _beams.is_empty():
		return
	var to := aim_point - origin
	var target: float
	if armed:
		target = to.angle()
	else:
		# pitch toward the mouse, but stay on the facing side
		var pitch := atan2(to.y, maxf(absf(to.x), 1.0))
		pitch = clampf(pitch, -deg_to_rad(max_unarmed_pitch_deg), deg_to_rad(max_unarmed_pitch_deg))
		target = pitch if facing > 0 else PI - pitch
	angle = lerp_angle(angle, target, clampf(turn_speed * delta, 0.0, 1.0))
	for b in _beams:
		b.global_position = origin
		b.global_rotation = angle
	if _spill:
		_spill.global_position = origin + Vector2.from_angle(angle) * 6.0
	_update_flicker(delta)


func _update_flicker(delta: float) -> void:
	if not is_on:
		return
	# rare, subtle stutter of an old flashlight
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = randf_range(9.0, 22.0)
		_flicker_left = randf_range(0.12, 0.3)
	if _flicker_left > 0.0:
		_flicker_left -= delta
		var e := beam_energy * (0.35 if randf() < 0.5 else 0.9)
		if _flicker_left <= 0.0:
			e = beam_energy
		for b in _beams:
			b.energy = e
