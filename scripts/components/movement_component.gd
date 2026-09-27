class_name MovementComponent
extends Node
## Side-view platformer movement for a CharacterBody2D (the parent).

signal jumped
signal landed(impact_speed: float)
signal stepped(mode: int)

enum Mode { WALK, SNEAK, RUN }

@export var walk_speed := 70.0
@export var sneak_speed := 34.0
@export var run_speed := 124.0
@export var acceleration := 760.0
@export var friction := 1000.0
@export var air_control := 0.55
@export var jump_velocity := -262.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
@export var step_distance_walk := 17.0
@export var step_distance_sneak := 15.0
@export var step_distance_run := 21.0

var body: CharacterBody2D
var mode: Mode = Mode.WALK
var sneak_toggled := false
var input_x := 0.0
var enabled := true

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true
var _step_accum := 0.0
var _last_fall_speed := 0.0


func _ready() -> void:
	body = get_parent() as CharacterBody2D


func physics_step(delta: float, move_x: float, jump_pressed: bool, jump_held: bool, sprint_held: bool) -> void:
	if not enabled:
		move_x = 0.0
		jump_pressed = false
		sprint_held = false
	input_x = move_x
	var on_floor := body.is_on_floor()
	if sprint_held and absf(move_x) > 0.1:
		mode = Mode.RUN
	elif sneak_toggled:
		mode = Mode.SNEAK
	else:
		mode = Mode.WALK

	# gravity
	if not on_floor:
		body.velocity.y += _gravity * delta * (1.0 if jump_held and body.velocity.y < 0 else 1.6)
		body.velocity.y = minf(body.velocity.y, 520.0)
		_last_fall_speed = maxf(_last_fall_speed, body.velocity.y)

	# jump buffering & coyote time
	_coyote = coyote_time if on_floor else maxf(_coyote - delta, 0.0)
	_buffer = jump_buffer_time if jump_pressed else maxf(_buffer - delta, 0.0)
	if _buffer > 0.0 and _coyote > 0.0:
		body.velocity.y = jump_velocity * (0.85 if mode == Mode.SNEAK else 1.0)
		_buffer = 0.0
		_coyote = 0.0
		jumped.emit()

	# horizontal
	var target := move_x * current_speed()
	var accel := acceleration if absf(move_x) > 0.01 else friction
	if not on_floor:
		accel *= air_control
	body.velocity.x = move_toward(body.velocity.x, target, accel * delta)

	var prev_x := body.global_position.x
	body.move_and_slide()
	var moved := absf(body.global_position.x - prev_x)

	on_floor = body.is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(_last_fall_speed)
		_last_fall_speed = 0.0
		_step_accum = 0.0
	_was_on_floor = on_floor

	if on_floor and moved > 0.05 and absf(move_x) > 0.01:
		_step_accum += moved
		var sd := step_distance_walk
		if mode == Mode.SNEAK:
			sd = step_distance_sneak
		elif mode == Mode.RUN:
			sd = step_distance_run
		if _step_accum >= sd:
			_step_accum -= sd
			stepped.emit(mode)


func current_speed() -> float:
	match mode:
		Mode.SNEAK:
			return sneak_speed
		Mode.RUN:
			return run_speed
	return walk_speed


func is_moving() -> bool:
	return absf(body.velocity.x) > 6.0


func stop() -> void:
	body.velocity.x = 0.0
