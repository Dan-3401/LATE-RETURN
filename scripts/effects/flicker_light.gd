class_name FlickerLight
extends PointLight2D
## An unreliable light: mostly steady, occasionally stutters or dies briefly.

@export var base_energy := 0.6
@export var min_interval := 2.5
@export var max_interval := 9.0
@export var buzz_sound: StringName = &""
@export var dead_chance := 0.25

var _timer := 1.0
var _burst := 0.0


func _ready() -> void:
	energy = base_energy
	_timer = randf_range(min_interval, max_interval)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(min_interval, max_interval)
		_burst = randf_range(0.15, 0.6)
		if buzz_sound != &"":
			AudioManager.play_at(buzz_sound, global_position, -16.0, 500.0)
	if _burst > 0.0:
		_burst -= delta
		var r := randf()
		energy = base_energy * (0.0 if r < dead_chance else (0.3 if r < 0.6 else 1.1))
		if _burst <= 0.0:
			energy = base_energy
	else:
		energy = base_energy * (0.97 + 0.03 * sin(Time.get_ticks_msec() * 0.02))
