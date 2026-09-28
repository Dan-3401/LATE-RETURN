class_name ForegroundFader
extends Parallax2D
## A near-camera foreground layer (pure visuals, no collision). Every child
## sprite fades down while it covers something the player must see — the
## player, a zombie, an interactable, a pickup — and comes back afterwards.
## Foreground is for depth and mood; it never gets to hide danger.

@export var visible_alpha := 1.0
@export var faded_alpha := 0.35
@export var fade_speed := 4.0
## Extra screen pixels around watched things.
@export var margin := 6.0

const WATCH_GROUPS := [&"player", &"zombie", &"interactable", &"loot_container", &"hide_spot", &"pickup"]
## Rough body box of an actor relative to its feet.
const ACTOR_BOX := Rect2(-10, -46, 20, 48)


func _ready() -> void:
	for c in get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = visible_alpha


func _process(delta: float) -> void:
	var watched := _watched_rects()
	var step := fade_speed * delta
	for c in get_children():
		if not c is Sprite2D:
			continue
		var s := c as Sprite2D
		var r := s.get_global_transform_with_canvas() * s.get_rect()
		var target := visible_alpha
		for w in watched:
			if r.intersects(w):
				target = faded_alpha
				break
		s.modulate.a = move_toward(s.modulate.a, target, step)


func is_covering(node: Node2D) -> bool:
	var w := _rect_of(node)
	for c in get_children():
		if c is Sprite2D:
			var s := c as Sprite2D
			if (s.get_global_transform_with_canvas() * s.get_rect()).intersects(w):
				return true
	return false


func _watched_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var view := get_viewport_rect().grow(32)
	for g in WATCH_GROUPS:
		for n in get_tree().get_nodes_in_group(g):
			if n is Node2D and (n as Node2D).is_visible_in_tree():
				var r := _rect_of(n)
				if view.intersects(r):
					out.append(r)
	return out


func _rect_of(n: Node2D) -> Rect2:
	var p := n.get_global_transform_with_canvas().origin
	var box := ACTOR_BOX
	if not (n.is_in_group(&"player") or n.is_in_group(&"zombie")):
		box = Rect2(-12, -24, 24, 28)
	return Rect2(p + box.position, box.size).grow(margin)
