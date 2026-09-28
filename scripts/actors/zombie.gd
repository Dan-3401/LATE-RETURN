class_name Zombie
extends CharacterBody2D
## Zombie actor: owns components and the state machine, provides small
## helpers the states use. Behaviour lives in scripts/ai/states/.

signal died(zombie: Zombie)

const ICON_SUSPICIOUS := preload("res://art/fx/icon_suspicious.png")
const ICON_ALERT := preload("res://art/fx/icon_alert.png")
const CALM_STATES := [&"Idle", &"Wander", &"Patrol", &"PatrolResume", &"Return"]

@export var data: ZombieData
@export var frames: SpriteFrames
@export var start_facing := 1
@export var groan_min := 7.0
@export var groan_max := 16.0

@onready var visual: Node2D = $Visual
@onready var body_sprite: AnimatedSprite2D = $Visual/Body
@onready var status_icon: Sprite2D = $StatusIcon
@onready var vision: VisionComponent = $Vision
@onready var hearing: HearingComponent = $HearingComponent
@onready var nav: GroundNavComponent = $GroundNavComponent
@onready var patrol: PatrolComponent = $PatrolComponent
@onready var attack: AttackComponent = $AttackComponent
@onready var machine: StateMachine = $StateMachine
@onready var voice: AudioStreamPlayer2D = $Voice
@onready var collision: CollisionShape2D = $CollisionShape2D

var facing := 1:
	set(v):
		facing = 1 if v >= 0 else -1
var hp := 100.0
var dead := false
var last_seen_pos := Vector2.ZERO
var last_heard_pos := Vector2.ZERO
var roar_cooldown := 0.0
var _player: Player
var _groan := 0.0
var _step_acc := 0.0


func _ready() -> void:
	add_to_group(&"zombie")
	if data == null:
		data = ZombieData.new()
	if frames:
		body_sprite.sprite_frames = frames
	hp = data.max_hp
	facing = start_facing
	vision.setup(self, data)
	vision.saw_player_hide.connect(_on_saw_hide)
	hearing.setup(self, data.hearing_multiplier)
	hearing.heard.connect(func(ev, i): machine.on_noise(ev, i))
	nav.setup(self)
	patrol.setup(global_position.x, facing)
	attack.setup(self, data)
	status_icon.visible = false
	_groan = randf_range(2.0, groan_max)
	# desync animations between zombies
	body_sprite.frame = randi() % 4
	machine.setup(self)


func get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


func _physics_process(delta: float) -> void:
	roar_cooldown = maxf(roar_cooldown - delta, 0.0)
	if not dead:
		vision.update(delta, get_player())
		machine.physics_update(delta)
		_update_groan(delta)
	nav.physics_step(delta)
	_update_steps(delta)
	visual.scale.x = facing
	vision.position.x = 4.0 * facing
	_update_icon()
	if GameState.debug_enabled or _debug_drawn:
		queue_redraw()


func _update_icon() -> void:
	var s := machine.state_name()
	if dead or s == &"Feed":
		status_icon.visible = false
	elif s in [&"Alert", &"Chase", &"Attack"]:
		status_icon.visible = true
		status_icon.texture = ICON_ALERT
	elif s in [&"Suspicious", &"Investigate", &"Search"]:
		status_icon.visible = true
		status_icon.texture = ICON_SUSPICIOUS
	else:
		status_icon.visible = false


## Dragging footsteps, positional so the player can hear where danger is.
func _update_steps(delta: float) -> void:
	if dead or not is_on_floor() or absf(velocity.x) < 5.0:
		return
	_step_acc += absf(velocity.x) * delta
	var fast := absf(velocity.x) > data.investigate_speed * 1.2
	if _step_acc >= (24.0 if fast else 13.0):
		_step_acc = 0.0
		AudioManager.play_at(&"zombie_step", global_position, -6.0 if fast else -14.0, 460.0, 0.12)


func _update_groan(delta: float) -> void:
	_groan -= delta
	if _groan <= 0.0:
		_groan = randf_range(groan_min, groan_max)
		if machine.state_name() in CALM_STATES or machine.state_name() == &"Search":
			vocal(&"zombie_groan", -8.0)


# --- helpers for states --------------------------------------------------------
func play(anim: StringName) -> void:
	if body_sprite.animation != anim or not body_sprite.is_playing():
		body_sprite.play(anim)


func face_x(x: float) -> void:
	if absf(x - global_position.x) > 1.0:
		facing = 1 if x > global_position.x else -1


func vocal(sound: StringName, volume_db := 0.0) -> void:
	var streams := AudioManager.get_streams(sound)
	if streams.is_empty():
		return
	voice.stream = streams[randi() % streams.size()]
	voice.volume_db = volume_db
	voice.pitch_scale = randf_range(0.85, 1.1)
	voice.play()


## The roar is itself a big noise: nearby zombies come to investigate.
func roar() -> void:
	roar_cooldown = 6.0
	vocal(&"zombie_roar", 3.0)
	NoiseSystem.emit_noise(global_position + Vector2(0, -36), data.roar_radius, self, &"roar")
	var cam := get_tree().get_first_node_in_group(&"game_camera")
	if cam:
		cam.call(&"shake", 1.5, 0.4)


func _on_saw_hide(spot: Node2D) -> void:
	var s := machine.state_name()
	if dead or s in [&"Feed", &"Dead", &"Alert"]:
		return
	machine.transition_to(&"Investigate", {"pos": spot.global_position, "hide_spot": spot, "fast": s in [&"Chase", &"Attack"], "from_chase": true})


# --- damage ------------------------------------------------------------------------
func take_damage(amount: float, source: Node = null, dir := Vector2.ZERO) -> void:
	if dead:
		return
	hp -= amount
	_spawn_blood(dir)
	if hp <= 0.0:
		die()
		return
	vocal(&"zombie_hit", 0.0)
	velocity.x = dir.x * 60.0
	var t := create_tween()
	t.tween_property(body_sprite, "modulate", Color(1.6, 1.2, 1.2), 0.05)
	t.tween_property(body_sprite, "modulate", Color.WHITE, 0.1)
	machine.on_damaged(source)


## Unaware and attacked from behind -> the knife can finish it quietly.
func is_vulnerable_to_sneak_attack(attacker: Node2D) -> bool:
	if dead:
		return false
	var s := machine.state_name()
	if not (s in CALM_STATES or s == &"Suspicious" or s == &"Search"):
		return false
	var side := signf(attacker.global_position.x - global_position.x)
	return side != float(facing)


func die() -> void:
	dead = true
	hp = 0.0
	# stop at once, and stay stopped (nav.halt keeps velocity.x at 0 every
	# frame, the Dead state cannot be left, the attack hitbox is off)
	velocity = Vector2(0.0, maxf(velocity.y, 0.0))
	nav.halt()
	attack.enabled = false
	collision_layer = 0
	collision_mask = 1   # only rests on the ground; never pushes or is pushed
	hearing.enabled = false
	vocal(&"zombie_death", -2.0)
	machine.transition_to(&"Dead")
	died.emit(self)


func _spawn_blood(dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = preload("res://art/fx/pixel.png")
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(dir.x if dir != Vector2.ZERO else float(-facing), -0.5)
	p.spread = 40.0
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.color = Color(0.3, 0.05, 0.05)
	p.position = Vector2(0, -28)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


# --- debug -----------------------------------------------------------------------
var _debug_drawn := false


func debug_state() -> String:
	return "%s %s sus=%.2f see=%s" % [name, machine.state_name(), vision.suspicion, vision.can_see]


func _draw() -> void:
	_debug_drawn = GameState.debug_enabled
	if not GameState.debug_enabled or dead:
		return
	var eye := vision.position
	var col := Color(0.4, 1, 0.4, 0.5)
	if vision.can_see:
		col = Color(1, 0.3, 0.2, 0.8)
	var ha := deg_to_rad(data.vision_half_angle)
	var fwd := Vector2(facing, 0)
	draw_line(eye, eye + fwd.rotated(ha) * data.vision_range, col)
	draw_line(eye, eye + fwd.rotated(-ha) * data.vision_range, col)
	draw_arc(eye, data.near_sense_range, 0, TAU, 16, Color(1, 1, 0.3, 0.4))
	draw_line(Vector2(patrol.home_x + patrol.left - global_position.x, 2), Vector2(patrol.home_x + patrol.right - global_position.x, 2), Color(0.3, 0.6, 1, 0.6))
	draw_circle(to_local(last_seen_pos), 2.0, Color(1, 0.2, 0.2))
	draw_circle(to_local(last_heard_pos), 2.0, Color(0.3, 0.6, 1))
	draw_string(ThemeDB.fallback_font, Vector2(-20, -58), "%s %.1f" % [machine.state_name(), vision.suspicion], HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
