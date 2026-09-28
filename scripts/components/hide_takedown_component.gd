class_name HideTakedownComponent
extends Node
## Knife kill from a hiding place.
## Available while the player is hidden, a living zombie is within `reach`
## of the hiding place and a knife sits in ANY of the three hand slots (it
## does not have to be the active one). Only the nearest valid zombie gets
## the "[鼠标左键] 击杀" prompt.
## The kill: input locked, quick camera zoom, the brother leans out with the
## knife (borrowed from its slot), one fast blow to the head, the body drops,
## he slips back in, zoom and hands are restored. The world keeps running:
## other zombies can see him while he leans out and can hear the blow.

signal performed(zombie: Zombie)

@export var reach := 38.0
@export var zoom := 1.25
@export var lean_distance := 10.0

var player: Player
var target: Zombie = null
var busy := false
var _prompt_for: Zombie = null


func setup(p: Player) -> void:
	player = p


## Index of the first hand slot holding a melee weapon, or -1.
func knife_slot() -> int:
	for i in GameState.HAND_SLOTS.size():
		var it := GameState.hand_item(i)
		if it and it.equipment_category == ItemData.EquipmentCategory.MELEE_WEAPON:
			return i
	return -1


func can_perform() -> bool:
	return not busy and target != null and is_instance_valid(target) and not target.dead


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var t: Zombie = null
	if not busy and player.state == Player.State.HIDDEN and knife_slot() >= 0:
		t = _nearest()
	target = t
	_update_prompt()


func _nearest() -> Zombie:
	var spot := player.stealth.hide_spot as Node2D
	var origin: Vector2 = spot.global_position if spot else player.global_position
	var best: Zombie = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"zombie"):
		var z := n as Zombie
		if z == null or z.dead:
			continue
		var dx := absf(z.global_position.x - origin.x)
		if dx <= reach and absf(z.global_position.y - origin.y) < 30.0 and dx < best_d:
			best_d = dx
			best = z
	return best


func _update_prompt() -> void:
	var ui := WorldUI.get_instance(player)
	if ui == null:
		return
	if target and not busy:
		ui.show_prompt(self, "[鼠标左键] 击杀", target.global_position + Vector2(0, -86))
		_prompt_for = target
	elif _prompt_for:
		ui.hide_prompt(self)
		_prompt_for = null


func perform() -> void:
	if not can_perform():
		return
	busy = true
	var z := target
	target = null
	_update_prompt()
	var cam := get_tree().get_first_node_in_group(&"game_camera") as GameCamera
	var dir := 1.0 if z.global_position.x >= player.global_position.x else -1.0
	var hide_pos := player.global_position
	# 1-3: lock, zoom in, lean out with the knife from whatever slot it is in
	player.hands.borrow(knife_slot())
	player.begin_takedown(dir, lean_distance)
	player.aim_override = z.global_position + Vector2(0, -36)
	if cam:
		cam.set_override(true)
		var mid := (player.global_position + z.global_position) * 0.5 + Vector2(0, -34)
		create_tween().tween_property(cam, "manual_position", mid, 0.12)
		cam.zoom_to(zoom, 0.12)
	AudioManager.play(&"hide_exit", -10.0)
	await _wait(0.14)
	# 4-5: one fast blow to the head
	player.weapons.swing_only()
	AudioManager.play(&"knife_swing", -4.0)
	await _wait(0.07)
	if is_instance_valid(z) and not z.dead:
		z.take_damage(9999.0, player, Vector2(dir, 0))
		z._spawn_blood(Vector2(dir, -0.3))
		AudioManager.play_at(&"knife_hit", z.global_position + Vector2(0, -30), 0.0)
		NoiseSystem.emit_noise(z.global_position, 60.0, player, &"knife_hit")
		if cam:
			cam.shake(2.5, 0.16)
	await _wait(0.4)
	# 6-8: back into hiding, camera and hands restored, control back
	player.aim_override = null
	player.end_takedown(hide_pos)
	player.hands.give_back()
	AudioManager.play(&"hide_enter", -12.0)
	if cam:
		cam.zoom_to(1.0, 0.18)
		cam.set_override(false)
	await _wait(0.18)
	busy = false
	performed.emit(z)


## Timers owned by this node: if the scene goes away mid-kill the coroutine
## simply never resumes.
func _wait(t: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = t
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
