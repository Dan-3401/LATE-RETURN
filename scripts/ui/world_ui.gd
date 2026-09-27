class_name WorldUI
extends CanvasLayer
## Screen-space layer for world-anchored UI: interaction prompts, overhead
## speech bubbles, small meters. Lives outside CanvasModulate so it is
## never darkened by level lighting.

const BUBBLE_SCENE := preload("res://scenes/ui/speech_bubble.tscn")
const PROMPT_SCENE := preload("res://scenes/ui/interaction_prompt.tscn")
const MARGIN := 4.0

var _prompts := {}      # owner -> {node, world_pos}
var _bubbles := {}      # speaker -> bubble
var _meters := {}       # key -> {node, world_pos}


static func get_instance(from: Node) -> WorldUI:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(&"world_ui") as WorldUI


func _ready() -> void:
	add_to_group(&"world_ui")
	layer = 5


func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


func clamp_rect_to_screen(pos: Vector2, size: Vector2) -> Vector2:
	var vs := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, MARGIN, vs.x - size.x - MARGIN)
	pos.y = clampf(pos.y, MARGIN, vs.y - size.y - MARGIN)
	return pos.round()


# --- Prompts ---------------------------------------------------------------
func show_prompt(owner_node: Object, text: String, world_pos: Vector2) -> void:
	var entry = _prompts.get(owner_node)
	var node: Control
	if entry == null:
		node = PROMPT_SCENE.instantiate()
		add_child(node)
		_prompts[owner_node] = {"node": node, "pos": world_pos}
	else:
		node = entry.node
		entry.pos = world_pos
	node.call("set_text", text)
	node.call("appear")


func hide_prompt(owner_node: Object) -> void:
	var entry = _prompts.get(owner_node)
	if entry == null:
		return
	_prompts.erase(owner_node)
	if is_instance_valid(entry.node):
		entry.node.call("disappear")


# --- Speech bubbles ----------------------------------------------------------
## Shows a typewriter bubble above `speaker` (Node2D). Returns the bubble;
## await bubble.finished to wait for it.
func say(speaker: Node2D, text: String, hold: float = -1.0, voice: StringName = &"text_tick") -> Control:
	if _bubbles.has(speaker) and is_instance_valid(_bubbles[speaker]):
		_bubbles[speaker].call("dismiss", true)
	var b: Control = BUBBLE_SCENE.instantiate()
	add_child(b)
	b.set("speaker", speaker)
	b.set("voice", voice)
	b.call("start", text, hold)
	_bubbles[speaker] = b
	b.tree_exited.connect(func(): if _bubbles.get(speaker) == b: _bubbles.erase(speaker))
	return b


func clear_bubbles() -> void:
	for b in _bubbles.values():
		if is_instance_valid(b):
			b.call("dismiss", true)
	_bubbles.clear()


# --- Meters (search progress, oxygen) -------------------------------------
func set_meter(key: StringName, world_pos: Vector2, ratio: float, color: Color, visible_now: bool, width: int = 20) -> void:
	var entry = _meters.get(key)
	if entry == null:
		if not visible_now:
			return
		var m := PixelMeter.new()
		m.bar_width = width
		add_child(m)
		entry = {"node": m, "pos": world_pos}
		_meters[key] = entry
	entry.pos = world_pos
	var node: PixelMeter = entry.node
	node.ratio = ratio
	node.fill_color = color
	node.target_alpha = 1.0 if visible_now else 0.0


func _process(_delta: float) -> void:
	for owner_node in _prompts.keys():
		var e = _prompts[owner_node]
		if not is_instance_valid(e.node):
			_prompts.erase(owner_node)
			continue
		var n: Control = e.node
		var sp := world_to_screen(e.pos) - Vector2(n.size.x * 0.5, n.size.y)
		n.position = clamp_rect_to_screen(sp, n.size)
	for key in _meters.keys():
		var e = _meters[key]
		var n: PixelMeter = e.node
		var sp := world_to_screen(e.pos) - Vector2(n.bar_width * 0.5, 0)
		n.position = clamp_rect_to_screen(sp, Vector2(n.bar_width + 2, 4))


# --- Toasts ------------------------------------------------------------------
## Small floating text (e.g. "饮用水 ×1") that rises and fades.
func toast(text: String, world_pos: Vector2, color := Color(0.9, 0.86, 0.72)) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.02, 0.02, 0.03))
	l.add_theme_constant_override(&"outline_size", 2)
	add_child(l)
	l.reset_size()
	var start := world_pos
	var t := create_tween()
	t.tween_method(func(v: float):
		if is_instance_valid(l):
			l.position = clamp_rect_to_screen(world_to_screen(start) - Vector2(l.size.x * 0.5, l.size.y + v), l.size)
		, 0.0, 14.0, 1.2)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t.tween_callback(l.queue_free)
