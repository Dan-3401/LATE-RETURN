class_name ThrowComponent
extends Node
## Throw mechanics (the empty bottle), driven by ThrowBehavior while a
## throwable is the active hand item: aim (a dotted pixel arc shows the
## flight), throw.
## The bottle really flies; the noise happens where it breaks.

signal readied(on: bool)
signal thrown(item: ItemData)

const PROJECTILE := preload("res://scenes/items/bottle_projectile.tscn")

@export var gravity := 620.0
@export var max_speed := 480.0
@export var min_flight := 0.32
@export var max_flight := 1.15
@export var cooldown := 0.55
@export var arm_path: NodePath

var is_ready := false
var _cd := 0.0
var _arm: Node2D
var _velocity := Vector2.ZERO
var _origin := Vector2.ZERO


func _ready() -> void:
	_arm = get_node_or_null(arm_path)
	if _arm:
		_arm.visible = false


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)


func set_ready(on: bool) -> void:
	if on == is_ready:
		return
	is_ready = on
	if _arm:
		_arm.visible = on
	if not on:
		_hide_preview()
	AudioManager.play(&"equip" if on else &"holster", -12.0)
	readied.emit(on)


## Initial velocity so that, unobstructed, the bottle lands at `target`.
func solve_velocity(origin: Vector2, target: Vector2) -> Vector2:
	var d := target - origin
	var t := clampf(d.length() / 320.0, min_flight, max_flight)
	var v := (d - 0.5 * Vector2(0, gravity) * t * t) / t
	if v.length() > max_speed:
		v = v.normalized() * max_speed
	return v


## Called every frame by the actor while ready.
func update(actor: Node2D, hand: Vector2, aim_point: Vector2, facing: int) -> void:
	if not is_ready:
		return
	_origin = hand
	_velocity = solve_velocity(hand, aim_point)
	if _arm:
		var a := _velocity.angle()
		_arm.rotation = a if facing > 0 else PI - a
	var ui := WorldUI.get_instance(actor)
	if ui:
		ui.set_trajectory(simulate(actor, hand, _velocity), true)


## Pixel arc points until the first collision (for the preview).
func simulate(actor: Node2D, from: Vector2, v: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var space := actor.get_world_2d().direct_space_state
	var p := from
	var dt := 1.0 / 60.0
	for i in 160:
		var nv := v + Vector2(0, gravity) * dt
		var np := p + nv * dt
		var q := PhysicsRayQueryParameters2D.create(p, np, 1)
		q.exclude = [actor.get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			pts.append(hit.position)
			return pts
		pts.append(np)
		p = np
		v = nv
	return pts


## Throws one `item` held in the hand slot `slot` (it is used up there).
func try_throw(actor: Node2D, item: ItemData, slot: String) -> bool:
	if not is_ready or _cd > 0.0 or GameState.equip_count(slot) <= 0:
		return false
	_cd = cooldown
	var b: Node2D = PROJECTILE.instantiate()
	actor.get_parent().add_child(b)
	b.call(&"launch", _origin, _velocity, gravity, actor)
	AudioManager.play(&"throw", -6.0)
	thrown.emit(item)
	# last one gone -> the slot empties and the hands are put away
	GameState.consume_hand(slot, 1)
	return true


func _hide_preview() -> void:
	var ui := WorldUI.get_instance(self)
	if ui:
		ui.set_trajectory(PackedVector2Array(), false)
