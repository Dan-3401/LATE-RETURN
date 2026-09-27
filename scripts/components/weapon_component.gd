class_name WeaponComponent
extends Node
## Pistol / knife handling: equip, aim, attack. Only one weapon can be out,
## so the two can never be in an attack state at the same time.

signal equipped_changed(weapon: WeaponData)
signal attacked(weapon: WeaponData)
signal fired(from: Vector2, to: Vector2, hit: Node)
signal dry_fire

@export var pistol: WeaponData
@export var knife: WeaponData
@export var arm_pivot_path: NodePath
@export var arm_sprite_path: NodePath
@export var muzzle_flash_path: NodePath
@export var hit_mask: int = 1 | (1 << 2)

var current: WeaponData = null
var aim_angle := 0.0
var busy := false
var enabled := true
var _cooldown := 0.0
var _arm_pivot: Node2D
var _arm_sprite: Sprite2D
var _flash: PointLight2D
var _swing_offset := 0.0
var _recoil := 0.0


func _ready() -> void:
	_arm_pivot = get_node_or_null(arm_pivot_path)
	_arm_sprite = get_node_or_null(arm_sprite_path)
	_flash = get_node_or_null(muzzle_flash_path)
	if _arm_pivot:
		_arm_pivot.visible = false
	if _flash:
		_flash.enabled = false


func is_armed() -> bool:
	return current != null


func toggle(weapon: WeaponData) -> void:
	if busy or not enabled:
		return
	if current == weapon:
		equip(null)
	else:
		equip(weapon)


func equip(weapon: WeaponData) -> void:
	current = weapon
	if _arm_pivot:
		_arm_pivot.visible = weapon != null
	if weapon and _arm_sprite:
		_arm_sprite.texture = weapon.arm_texture
		_arm_sprite.offset = -weapon.arm_pivot
	AudioManager.play(&"equip" if weapon else &"holster", -8.0)
	equipped_changed.emit(weapon)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_recoil = move_toward(_recoil, 0.0, delta * 3.0)


## facing: current visual facing (+1/-1). Called every frame by the actor.
func update_aim(shoulder_global: Vector2, aim_point: Vector2, facing: int) -> void:
	if _arm_pivot == null:
		return
	aim_angle = (aim_point - shoulder_global).angle()
	var a := aim_angle + (_swing_offset - _recoil) * facing
	# arm pivot lives under the mirrored Visual node
	_arm_pivot.rotation = a if facing > 0 else PI - a


func try_attack(actor: Node2D, shoulder_global: Vector2, facing: int) -> bool:
	if current == null or busy or _cooldown > 0.0 or not enabled:
		return false
	if current.is_ranged:
		return _fire(actor, shoulder_global, facing)
	_swing(actor, shoulder_global, facing)
	return true


# --- pistol ------------------------------------------------------------------
func _fire(actor: Node2D, origin: Vector2, facing: int) -> bool:
	_cooldown = current.cooldown
	if GameState.ammo <= 0:
		AudioManager.play(&"dry_fire", -4.0)
		dry_fire.emit()
		return false
	GameState.ammo -= 1
	var dir := Vector2.from_angle(aim_angle)
	var muzzle := origin + dir * (current.tip.x - current.arm_pivot.x)
	var to := muzzle + dir * current.attack_range
	var space := actor.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(muzzle, to, hit_mask)
	q.exclude = [actor.get_rid()]
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	var hit_node: Node = null
	if not hit.is_empty():
		to = hit.position
		hit_node = hit.collider
		if hit_node and hit_node.has_method(&"take_damage"):
			hit_node.call(&"take_damage", current.damage, actor, dir)
	AudioManager.play(current.attack_sound, 0.0, 0.05)
	NoiseSystem.emit_noise(muzzle, current.noise_radius, actor, &"gunshot")
	_recoil = 0.35
	_flash_muzzle(muzzle)
	fired.emit(muzzle, to, hit_node)
	attacked.emit(current)
	return true


func _flash_muzzle(pos: Vector2) -> void:
	if _flash == null:
		return
	_flash.global_position = pos
	_flash.enabled = true
	var t := create_tween()
	t.tween_interval(0.06)
	t.tween_callback(func(): _flash.enabled = false)


# --- knife -----------------------------------------------------------------
func _swing(actor: Node2D, origin: Vector2, facing: int) -> void:
	busy = true
	_cooldown = current.cooldown
	AudioManager.play(current.attack_sound, -3.0)
	attacked.emit(current)
	var t := create_tween()
	t.tween_property(self, "_swing_offset", -1.1, 0.07)
	t.tween_callback(_knife_hit.bind(actor, origin))
	# the swoosh is heard after the blow lands (a victim cannot turn in time)
	t.tween_callback(func(): NoiseSystem.emit_noise(origin, current.noise_radius if current else 34.0, actor, &"knife"))
	t.tween_property(self, "_swing_offset", 0.7, 0.08)
	t.tween_property(self, "_swing_offset", 0.0, 0.18)
	t.tween_callback(func(): busy = false)


func _knife_hit(actor: Node2D, origin: Vector2) -> void:
	var dir := Vector2.from_angle(aim_angle)
	var center := origin + dir * (current.attack_range * 0.6)
	var shape := CircleShape2D.new()
	shape.radius = current.attack_range * 0.55
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, center)
	q.collision_mask = 1 << 2
	q.exclude = [actor.get_rid()]
	var results := actor.get_world_2d().direct_space_state.intersect_shape(q, 4)
	for r in results:
		var n: Node = r.collider
		if n and n.has_method(&"take_damage"):
			var dmg := current.damage
			if n.has_method(&"is_vulnerable_to_sneak_attack") and n.call(&"is_vulnerable_to_sneak_attack", actor):
				dmg *= current.sneak_multiplier
			n.call(&"take_damage", dmg, actor, dir)
			AudioManager.play_at(&"knife_hit", center, -2.0)
			NoiseSystem.emit_noise(center, current.hit_noise_radius, actor, &"knife_hit")
			break
