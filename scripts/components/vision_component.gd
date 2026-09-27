class_name VisionComponent
extends Node2D
## Line-of-sight perception. Considers distance, facing, view cone,
## RayCast occlusion (walls / vehicles / vision blockers), the player's
## Presence and hide state. Accumulates a suspicion meter.

signal saw_player_hide(spot: Node2D)

@export var block_mask: int = 1 | 64

var zombie: Node2D
var data: ZombieData
var can_see := false
var visibility := 0.0
var suspicion := 0.0
var time_since_seen := 99.0
## Multiplier applied to suspicion gain (states set it: alert-ish states see faster).
var gain_multiplier := 1.0


func setup(z: Node2D, d: ZombieData) -> void:
	zombie = z
	data = d


func update(delta: float, player: Player) -> void:
	var was_seeing := time_since_seen < 0.4
	can_see = false
	visibility = 0.0
	if player and is_instance_valid(player) and not player.is_dead():
		if player.is_hidden():
			if was_seeing and suspicion > 0.2 and player.stealth.hide_spot:
				saw_player_hide.emit(player.stealth.hide_spot)
				time_since_seen = 99.0
		else:
			_look(player)
	if can_see:
		time_since_seen = 0.0
		suspicion = minf(suspicion + data.detection_rate * visibility * gain_multiplier * delta, 1.5)
	else:
		time_since_seen += delta
		suspicion = maxf(suspicion - data.suspicion_decay * delta, 0.0)


func _look(player: Player) -> void:
	var presence := player.stealth.presence
	if presence <= 0.01:
		return
	var eye := global_position
	var chest := player.global_position + Vector2(0, -26)
	var head := player.global_position + Vector2(0, -40)
	var d := eye.distance_to(chest)
	var near := d < data.near_sense_range and absf(player.global_position.y - zombie.global_position.y) < 30.0
	var rng := data.vision_range * lerpf(0.4, 1.0, presence)
	if d > rng and not near:
		return
	if not near:
		var fwd := Vector2(zombie.facing, 0)
		var ang := rad_to_deg(absf(fwd.angle_to(chest - eye)))
		if ang > data.vision_half_angle:
			return
	var seen := 0
	for p in [chest, head]:
		if _clear(eye, p, player):
			seen += 1
	if seen == 0:
		return
	var prox := 1.0 - clampf(d / rng, 0.0, 1.0)
	visibility = presence * (seen / 2.0) * (0.35 + 0.65 * prox)
	if near:
		visibility = maxf(visibility, 0.9 * presence)
	can_see = true
	zombie.set(&"last_seen_pos", player.global_position)


func _clear(from: Vector2, to: Vector2, player: Player) -> bool:
	var q := PhysicsRayQueryParameters2D.create(from, to, block_mask)
	q.exclude = [zombie.get_rid(), player.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()
