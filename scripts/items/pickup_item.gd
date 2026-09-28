class_name PickupItem
extends CharacterBody2D
## A dropped item: hops out, bounces on the floor, then glints until picked up.
## The world form of ONE item stack (item + count + instance data), however
## large: it is picked up whole or not at all.

@export var item: ItemData
@export var count := 1
## Extra per-stack data carried with the stack (none of the current items
## has any; kept so a dropped stack comes back exactly as it was).
var instance_data := {}

var _gravity := 700.0
var _settled := false
var _delay := 0.0
var _t := 0.0
var _glint_timer := 0.0

@onready var sprite: Sprite2D = $Sprite
@onready var glint: Sprite2D = $Glint
@onready var interactable: Interactable = $Interactable
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	add_to_group(&"pickup")
	if item:
		sprite.texture = item.icon
	_update_prompt()
	interactable.interacted.connect(_on_interacted)
	glint.visible = false


## Take over a whole inventory stack {"item", "count", ...}.
func set_stack(stack: Dictionary) -> void:
	item = stack.item
	count = int(stack.count)
	instance_data = stack.duplicate(true)
	instance_data.erase("item")
	instance_data.erase("count")
	if is_node_ready():
		sprite.texture = item.icon
		_update_prompt()


## The stack this pickup stands for.
func get_stack() -> Dictionary:
	var st := instance_data.duplicate(true)
	st.item = item
	st.count = count
	return st


func _update_prompt() -> void:
	if item == null:
		return
	interactable.prompt_title = "%s ×%d" % [item.display_name, count] if count > 1 else item.display_name
	interactable.prompt_text = "拾取"
	interactable.refresh_prompt()


func launch(v: Vector2, delay: float = 0.0) -> void:
	velocity = v
	_delay = delay
	_settled = false
	visible = delay <= 0.0
	interactable.enabled = false


func _physics_process(delta: float) -> void:
	if _delay > 0.0:
		_delay -= delta
		if _delay <= 0.0:
			visible = true
		return
	_t += delta
	if not _settled:
		velocity.y += _gravity * delta
		var col := move_and_collide(velocity * delta)
		if col:
			var n := col.get_normal()
			if n.y < -0.5:
				if absf(velocity.y) > 60.0:
					velocity.y = -velocity.y * 0.35
					velocity.x *= 0.6
					AudioManager.play_at(&"item_land", global_position, -12.0)
				else:
					velocity = Vector2.ZERO
					_settled = true
					interactable.enabled = true
			else:
				velocity = velocity.bounce(n) * 0.4
		sprite.rotation += velocity.x * delta * 0.05
	else:
		sprite.rotation = lerp_angle(sprite.rotation, 0.0, delta * 10.0)
		# gentle float
		sprite.position.y = -8.0 + roundf(sin(_t * 2.6) * 1.0)
		_glint_timer -= delta
		if _glint_timer <= 0.0:
			_glint_timer = randf_range(1.4, 2.6)
			_play_glint()
	glow.energy = 0.25 + 0.1 * sin(_t * 3.0)


func _play_glint() -> void:
	glint.visible = true
	glint.frame = 0
	glint.position = sprite.position + Vector2(randi_range(-4, 3), randi_range(-4, 2))
	var t := create_tween()
	for f in [1, 2, 1]:
		t.tween_interval(0.06)
		t.tween_callback(func(): glint.frame = f)
	t.tween_interval(0.06)
	t.tween_callback(func(): glint.visible = false)


func _on_interacted(actor: Node2D) -> void:
	if not actor.has_method(&"receive_item"):
		return
	# whole stack or nothing: a refused pickup stays exactly as it was
	var left: int = actor.call(&"receive_item", item, count)
	if left != 0:
		return
	AudioManager.play(&"pickup", -4.0)
	var ui := WorldUI.get_instance(self)
	if ui:
		ui.call(&"toast", "%s ×%d" % [item.display_name, count], global_position + Vector2(0, -18))
	interactable.enabled = false
	remove_from_group(&"pickup")
	var t := create_tween()
	t.tween_property(sprite, "position:y", sprite.position.y - 10, 0.15)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
