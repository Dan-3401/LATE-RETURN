class_name GameCamera
extends Camera2D
## Follows a target with look-ahead, clamps to level bounds, supports shake.
## Always lands on whole pixels to keep the pixel art crisp.

@export var target_path: NodePath
@export var look_ahead := 36.0
@export var follow_speed := 5.0
@export var vertical_offset := -30.0
@export var lock_y := true

var target: Node2D
var _shake := 0.0
var _shake_time := 0.0
var _look := 0.0
var _pos := Vector2.ZERO
var _override := false


func _ready() -> void:
	add_to_group(&"game_camera")
	target = get_node_or_null(target_path)
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	if target:
		_pos = _desired()
		global_position = _pos.round()
	make_current()


func _desired() -> Vector2:
	var facing := 1
	if target and "facing" in target:
		facing = target.facing
	var moving := target and "velocity" in target and absf(target.velocity.x) > 10.0
	_look = move_toward(_look, facing * look_ahead * (1.0 if moving else 0.5), 60.0 * get_physics_process_delta_time())
	var p := target.global_position + Vector2(_look, vertical_offset)
	return p


func _physics_process(delta: float) -> void:
	if target and not _override:
		var d := _desired()
		_pos = _pos.lerp(d, clampf(follow_speed * delta, 0.0, 1.0))
		if lock_y:
			_pos.y = d.y
	var off := Vector2.ZERO
	if _shake_time > 0.0:
		_shake_time -= delta
		off = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		if _shake_time <= 0.0:
			_shake = 0.0
	global_position = (_pos + off).round()


func shake(amount: float, duration: float) -> void:
	_shake = maxf(_shake, amount)
	_shake_time = maxf(_shake_time, duration)


## Quick zoom for short dramatic moments (hide takedown). Awaitable.
func zoom_to(z: float, time: float) -> void:
	var t := create_tween()
	t.tween_property(self, "zoom", Vector2(z, z), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await t.finished


func snap_to_target() -> void:
	if target:
		_pos = _desired()
		global_position = _pos.round()


## Take manual control (cutscenes). Tween `manual_position` to move.
func set_override(on: bool) -> void:
	_override = on
	if on:
		_pos = global_position


var manual_position: Vector2:
	get:
		return _pos
	set(v):
		_pos = v


func set_bounds(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
