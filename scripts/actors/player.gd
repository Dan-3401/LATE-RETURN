class_name Player
extends CharacterBody2D
## The brother. Thin coordinator: reads input, forwards intents to its
## components and picks animations. Gameplay rules live in the components.

signal state_changed(state: State)
signal died
signal said(text: String)

enum State { NORMAL, SEARCHING, HIDDEN, CUTSCENE, DEAD }

const RIG := preload("res://art/characters/player/player_rig.tres")
const HAND_ACTIONS := [&"hand_1", &"hand_2", &"hand_3"]
const FOOTSTEP_NOISE := {
	MovementComponent.Mode.SNEAK: 14.0,
	MovementComponent.Mode.WALK: 72.0,
	MovementComponent.Mode.RUN: 150.0,
}

@onready var visual: Node2D = $Visual
@onready var body_sprite: AnimatedSprite2D = $Visual/Body
@onready var arm_pivot: Node2D = $Visual/ArmPivot
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var breath: BreathComponent = $BreathComponent
@onready var stealth: StealthComponent = $StealthComponent
@onready var flashlight: FlashlightComponent = $FlashlightComponent
@onready var weapons: WeaponComponent = $WeaponComponent
@onready var interaction: InteractionComponent = $InteractionComponent
@onready var throw: ThrowComponent = $ThrowComponent
## The one active hand item (quick slots 1 / 2 / 3).
@onready var hands: HandEquipmentComponent = $HandEquipmentComponent
@onready var takedown: HideTakedownComponent = $HideTakedownComponent
@onready var throw_pivot: Node2D = $Visual/ThrowPivot
@onready var collision: CollisionShape2D = $CollisionShape2D

var state: State = State.NORMAL
var facing := 1
var input_enabled := true
var _search_left := 0.0
var _search_total := 0.0
var _search_target: Node = null
var _search_done: Callable
var _landing := 0.0
var _hurt_time := 0.0
var _anim_lock := ""
var _auto_move_x := 0.0
## Aim point forced by a scripted action (hide takedown); null = mouse.
var aim_override = null
## Leaning out of a hiding place (hide takedown): visible and seeable.
var _leaning := false
var _lure_cd := 0.0
const LURE_COOLDOWN := 1.2


func _ready() -> void:
	add_to_group(&"player")
	movement.stepped.connect(_on_step)
	movement.landed.connect(_on_landed)
	movement.jumped.connect(_on_jumped)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	weapons.fired.connect(_on_fired)
	breath.gasp_started.connect(func(): say("哈……哈……", 1.2))
	body_sprite.animation_finished.connect(_on_anim_finished)
	hands.setup(self)
	takedown.setup(self)
	# pull persistent stats
	health.max_hp = GameState.max_hp
	health.set_hp(GameState.hp)
	breath.reset(GameState.oxygen)


func _exit_tree() -> void:
	if health and not health.dead:
		GameState.hp = health.hp
		GameState.oxygen = breath.oxygen


# --- Input & update ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not _accepts_input():
		return
	if event.is_action_pressed(&"toggle_sneak"):
		movement.sneak_toggled = not movement.sneak_toggled
		AudioManager.play(&"ui_soft", -18.0)
	elif event.is_action_pressed(&"flashlight"):
		flashlight.toggle()
	elif state == State.HIDDEN:
		_hidden_input(event)
	elif event.is_action_pressed(&"interact"):
		if state == State.NORMAL:
			interaction.try_interact()
	elif state == State.NORMAL:
		for i in HAND_ACTIONS.size():
			if event.is_action_pressed(HAND_ACTIONS[i]):
				hands.select(i)
				return
		if event.is_action_pressed(&"attack"):
			hands.primary()


## Inside a hiding place: F leaves, Space knocks (lure), 1/2/3 pick a hand
## item (only throwables can be used from here), left mouse = takedown if a
## zombie is in reach, otherwise the held throwable.
## Space here never reaches the cutscene skip: that one only listens while
## the player is in CUTSCENE.
func _hidden_input(event: InputEvent) -> void:
	if takedown.busy:
		return
	if event.is_action_pressed(&"interact"):
		if is_instance_valid(stealth.hide_spot):
			stealth.hide_spot.call(&"release", self)
	elif event.is_action_pressed(&"jump"):
		if _lure_cd <= 0.0 and is_instance_valid(stealth.hide_spot) and stealth.hide_spot.has_method(&"lure"):
			_lure_cd = LURE_COOLDOWN
			stealth.hide_spot.call(&"lure", self)
	elif event.is_action_pressed(&"attack"):
		if takedown.can_perform():
			takedown.perform()
		elif hands.active_behavior and hands.active_behavior.usable_while_hidden():
			hands.primary()
	else:
		for i in HAND_ACTIONS.size():
			if event.is_action_pressed(HAND_ACTIONS[i]):
				hands.select(i)
				return


func _accepts_input() -> bool:
	return input_enabled and state != State.DEAD and state != State.CUTSCENE


func _physics_process(delta: float) -> void:
	var move_x := 0.0
	var jump_pressed := false
	var jump_held := false
	var sprint := false
	var active := _accepts_input() and state == State.NORMAL
	if active:
		move_x = Input.get_axis(&"move_left", &"move_right")
		jump_pressed = Input.is_action_just_pressed(&"jump")
		jump_held = Input.is_action_pressed(&"jump")
		sprint = Input.is_action_pressed(&"sprint")
	if state == State.CUTSCENE:
		move_x = _auto_move_x
	if state == State.SEARCHING:
		_update_search(delta)
	if state != State.HIDDEN:
		movement.physics_step(delta, move_x, jump_pressed, jump_held, sprint)

	var mouse := get_global_mouse_position()
	_lure_cd = maxf(_lure_cd - delta, 0.0)
	var aiming_hidden: bool = state == State.HIDDEN and not _leaning and hands.active_behavior != null \
		and hands.active_behavior.usable_while_hidden() and _accepts_input()
	# facing
	if _leaning:
		pass
	elif hands.is_aiming() and (active or aiming_hidden):
		facing = 1 if mouse.x >= global_position.x else -1
	elif absf(move_x) > 0.1 and state != State.HIDDEN:
		facing = 1 if move_x > 0 else -1
	visual.scale.x = facing

	# breath (hold with right mouse)
	breath.set_hold(_accepts_input() and state != State.SEARCHING and Input.is_action_pressed(&"hold_breath"))

	# stealth presence
	var motion := StealthComponent.Motion.IDLE
	if not is_on_floor():
		motion = StealthComponent.Motion.AIR
	elif movement.is_moving():
		match movement.mode:
			MovementComponent.Mode.SNEAK: motion = StealthComponent.Motion.SNEAK
			MovementComponent.Mode.RUN: motion = StealthComponent.Motion.RUN
			_: motion = StealthComponent.Motion.WALK
	stealth.update(delta, motion, flashlight.is_on)

	_landing = maxf(_landing - delta, 0.0)
	_hurt_time = maxf(_hurt_time - delta, 0.0)
	_update_animation()
	_update_attachments(delta, mouse)


func _update_attachments(delta: float, mouse: Vector2) -> void:
	var anim := body_sprite.animation
	var fr := body_sprite.frame
	var sh := RIG.get_point(anim, fr, "shoulder", Vector2(0, -29))
	arm_pivot.position = sh.round()
	throw_pivot.position = sh.round()
	var aim: Vector2 = aim_override if aim_override != null else mouse
	hands.update(delta, shoulder_global(), aim, facing)
	var chest := RIG.get_point(anim, fr, "chest", Vector2(1, -27))
	var chest_global := global_position + Vector2(chest.x * facing, chest.y)
	flashlight.update(delta, chest_global, facing, mouse, hands.aims_flashlight())


func shoulder_global() -> Vector2:
	return global_position + Vector2(arm_pivot.position.x * facing, arm_pivot.position.y)


func get_speech_anchor() -> Vector2:
	var head := RIG.get_point(body_sprite.animation, body_sprite.frame, "head", Vector2(0, -42))
	return global_position + Vector2(head.x * facing, head.y - 6)


# --- Animation -----------------------------------------------------------------
func _update_animation() -> void:
	if _anim_lock != "":
		return
	var armed := hands.is_aiming()
	var anim := "idle"
	match state:
		State.DEAD:
			return
		State.SEARCHING:
			anim = "search"
		State.HIDDEN, State.CUTSCENE:
			if state == State.CUTSCENE and movement.is_moving():
				anim = "walk"
			else:
				anim = "idle"
		_:
			if _hurt_time > 0.0:
				anim = "hurt"
			elif not is_on_floor():
				anim = "jump" if velocity.y < 0 else "fall"
			elif _landing > 0.0:
				anim = "land"
			elif movement.is_moving():
				match movement.mode:
					MovementComponent.Mode.SNEAK: anim = "sneak"
					MovementComponent.Mode.RUN: anim = "run"
					_: anim = "walk"
			elif movement.sneak_toggled:
				anim = "idle"
			if armed and anim in ["idle", "walk", "sneak", "run", "jump", "fall", "land"]:
				anim = "armed_" + anim
	throw_pivot.visible = throw.is_ready and state == State.NORMAL and not anim.begins_with("hurt")
	if state == State.SEARCHING or (state == State.HIDDEN and not _leaning):
		arm_pivot.visible = false
	else:
		arm_pivot.visible = weapons.is_armed() and not anim.begins_with("hurt")
	if body_sprite.animation != anim:
		body_sprite.play(anim)
	# walk animations follow actual speed
	if anim.ends_with("walk") or anim.ends_with("sneak") or anim.ends_with("run"):
		body_sprite.speed_scale = clampf(absf(velocity.x) / movement.current_speed(), 0.5, 1.2)
	else:
		body_sprite.speed_scale = 1.0


## Play a one-shot animation that overrides the state machine until it ends.
func play_locked(anim: String) -> void:
	_anim_lock = anim
	body_sprite.speed_scale = 1.0
	body_sprite.play(anim)


func unlock_animation() -> void:
	_anim_lock = ""


func _on_anim_finished() -> void:
	if _anim_lock != "" and body_sprite.animation == _anim_lock and _anim_lock != "lying" and _anim_lock != "death":
		_anim_lock = ""


# --- Sounds & noise -----------------------------------------------------------
func _on_step(mode: int) -> void:
	var noise: float = FOOTSTEP_NOISE.get(mode, 60.0)
	NoiseSystem.emit_noise(global_position, noise, self, &"footstep")
	var snd := &"step"
	var vol := -8.0
	if mode == MovementComponent.Mode.SNEAK:
		snd = &"step_soft"
		vol = -16.0
	elif mode == MovementComponent.Mode.RUN:
		snd = &"step_run"
		vol = -4.0
	AudioManager.play(snd, vol, 0.1)


func _on_jumped() -> void:
	NoiseSystem.emit_noise(global_position, 40.0, self, &"jump")
	AudioManager.play(&"jump", -10.0)


func _on_landed(speed: float) -> void:
	if speed < 120.0:
		return
	_landing = 0.12
	var r := clampf(speed * 0.35, 40.0, 170.0)
	if movement.mode == MovementComponent.Mode.SNEAK:
		r *= 0.6
	NoiseSystem.emit_noise(global_position, r, self, &"land")
	AudioManager.play(&"land", -6.0 if speed > 250 else -10.0)


func _on_fired(from: Vector2, to: Vector2, _hit: Node) -> void:
	var cam := get_tree().get_first_node_in_group(&"game_camera")
	if cam:
		cam.call(&"shake", 3.0, 0.18)
	var fx_scene: PackedScene = load("res://scenes/effects/tracer.tscn")
	var fx: Node2D = fx_scene.instantiate()
	get_parent().add_child(fx)
	fx.call(&"setup", from, to)


# --- Speech -------------------------------------------------------------------
func say(text: String, hold: float = -1.0) -> Control:
	said.emit(text)
	var ui := WorldUI.get_instance(self)
	if ui:
		return ui.say(self, text, hold)
	return null


# --- Searching ----------------------------------------------------------------
func begin_search(target: Node, duration: float, on_done: Callable) -> void:
	if state != State.NORMAL:
		return
	_set_state(State.SEARCHING)
	movement.stop()
	interaction.clear()
	interaction.enabled = false
	_search_target = target
	_search_total = duration
	_search_left = duration
	_search_done = on_done
	if target is Node2D:
		facing = 1 if (target as Node2D).global_position.x >= global_position.x else -1


func _update_search(delta: float) -> void:
	# moving or jumping cancels the search
	var move_x := Input.get_axis(&"move_left", &"move_right") if _accepts_input() else 0.0
	if absf(move_x) > 0.5 or Input.is_action_just_pressed(&"jump"):
		cancel_search()
		return
	_search_left -= delta
	var ui := WorldUI.get_instance(self)
	if ui and is_instance_valid(_search_target):
		var p: Vector2 = (_search_target as Node2D).global_position + Vector2(0, -8)
		if _search_target.has_method(&"get_meter_position"):
			p = _search_target.call(&"get_meter_position")
		ui.set_meter(&"search", p, 1.0 - _search_left / _search_total, Color(0.86, 0.8, 0.6), true)
	if _search_left <= 0.0:
		_end_search(true)


func cancel_search() -> void:
	if state == State.SEARCHING:
		_end_search(false)


func _end_search(success: bool) -> void:
	var ui := WorldUI.get_instance(self)
	if ui:
		ui.set_meter(&"search", Vector2.ZERO, 1.0, Color.WHITE, false)
	interaction.enabled = true
	_set_state(State.NORMAL)
	var cb := _search_done
	_search_done = Callable()
	_search_target = null
	if cb.is_valid():
		cb.call(success)


func is_searching() -> bool:
	return state == State.SEARCHING


# --- Hiding -------------------------------------------------------------------
func enter_hide(spot: Node2D, hide_pos: Vector2) -> void:
	_set_state(State.HIDDEN)
	movement.stop()
	velocity = Vector2.ZERO
	global_position = hide_pos
	visual.visible = false
	collision.set_deferred(&"disabled", true)
	hands.holster()
	stealth.set_hidden(true, spot)
	breath.noise_scale = 0.7
	flashlight.set_on(false, true)
	interaction.clear()
	interaction.enabled = false


func exit_hide(exit_pos: Vector2) -> void:
	global_position = exit_pos
	visual.visible = true
	collision.set_deferred(&"disabled", false)
	stealth.set_hidden(false)
	breath.noise_scale = 1.0
	interaction.enabled = true
	_set_state(State.NORMAL)


func is_hidden() -> bool:
	return state == State.HIDDEN and not _leaning


## Hide takedown: lean out of the hiding place toward `dir`.
func begin_takedown(dir: float, lean: float) -> void:
	_leaning = true
	face(int(dir))
	global_position += Vector2(dir * lean, 0)
	visual.visible = true
	play_locked("armed_idle")


func end_takedown(hide_pos: Vector2) -> void:
	_leaning = false
	unlock_animation()
	global_position = hide_pos
	visual.visible = false


# --- Items ---------------------------------------------------------------------
func receive_item(item: ItemData, count: int) -> int:
	var left := GameState.inventory.add(item, count)
	if left == count:
		say("背包已经装不下了。")
	return left


# --- Damage & death --------------------------------------------------------------
func take_damage(amount: float, source: Node = null, _dir := Vector2.ZERO) -> void:
	if state == State.HIDDEN or state == State.DEAD:
		return
	if state == State.SEARCHING:
		cancel_search()
	health.take_damage(amount, source)


func _on_damaged(_amount: float, source: Node) -> void:
	_hurt_time = 0.25
	AudioManager.play(&"player_hurt", -2.0)
	if source is Node2D:
		velocity.x = signf(global_position.x - (source as Node2D).global_position.x) * 140.0
		velocity.y = -90.0
	var cam := get_tree().get_first_node_in_group(&"game_camera")
	if cam:
		cam.call(&"shake", 4.0, 0.25)
	_flash_sprite()
	GameState.hp = health.hp


func _flash_sprite() -> void:
	var t := create_tween()
	for i in 3:
		t.tween_property(body_sprite, "modulate", Color(1.8, 0.6, 0.6), 0.05)
		t.tween_property(body_sprite, "modulate", Color.WHITE, 0.07)


func _on_died() -> void:
	_set_state(State.DEAD)
	GameState.hp = 0.0
	movement.stop()
	hands.holster()
	breath.enabled = false
	interaction.clear()
	interaction.enabled = false
	_anim_lock = "death"
	body_sprite.speed_scale = 1.0
	body_sprite.play("death")
	AudioManager.play(&"player_death", 0.0)
	died.emit()


func is_dead() -> bool:
	return state == State.DEAD


# --- Cutscene control ---------------------------------------------------------------
func set_cutscene(on: bool) -> void:
	if state == State.DEAD:
		return
	if on:
		cancel_search()
		hands.holster()
		movement.stop()
		breath.set_hold(false)
		interaction.clear()
		interaction.enabled = false
		_set_state(State.CUTSCENE)
	else:
		interaction.enabled = true
		_set_state(State.NORMAL)


## Walk to an x position during cutscenes (await it).
func walk_to(x: float, max_time: float = 8.0) -> void:
	var t := 0.0
	while absf(global_position.x - x) > 3.0 and state == State.CUTSCENE and t < max_time:
		_auto_move_x = signf(x - global_position.x) * (0.4 if absf(global_position.x - x) < 8.0 else 1.0)
		t += get_physics_process_delta_time()
		await get_tree().physics_frame
	_auto_move_x = 0.0


func face(dir: int) -> void:
	facing = dir
	visual.scale.x = dir


func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)
