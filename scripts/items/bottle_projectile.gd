extends Node2D
## A thrown glass bottle: flies on a real arc, spins, and shatters on the
## first thing it hits. The noise event is emitted where it breaks.

const BREAK_NOISE := 260.0

var velocity := Vector2.ZERO
var gravity := 620.0
var _thrower: Node2D
var _life := 4.0
var _broken := false

@onready var sprite: Sprite2D = $Sprite


func launch(from: Vector2, v: Vector2, g: float, thrower: Node2D) -> void:
	global_position = from
	velocity = v
	gravity = g
	_thrower = thrower


func _physics_process(delta: float) -> void:
	if _broken:
		return
	_life -= delta
	var nv := velocity + Vector2(0, gravity) * delta
	var np := global_position + nv * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, np, 1)
	if is_instance_valid(_thrower):
		q.exclude = [_thrower.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() or _life <= 0.0:
		global_position = hit.position if not hit.is_empty() else global_position
		_break()
		return
	velocity = nv
	global_position = np
	sprite.rotation += velocity.x * delta * 0.09


func _break() -> void:
	_broken = true
	sprite.visible = false
	AudioManager.play_at(&"bottle_break", global_position, 2.0, 1200.0)
	NoiseSystem.emit_noise(global_position + Vector2(0, -6), BREAK_NOISE, self, &"bottle")
	var shards := $Shards as CPUParticles2D
	shards.emitting = true
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_callback(queue_free)
