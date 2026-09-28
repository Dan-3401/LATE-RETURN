class_name CutsceneSkip
extends CanvasLayer
## "长按 Space 跳过" for long story scenes.
## The hint shows briefly when the scene starts, and again for a moment
## whenever a key is pressed while it is hidden. Holding Space (the `jump`
## action) for `hold_time` seconds emits `skipped` once — a normal tap never
## skips. Only listens while the player is in a CUTSCENE, so it can never
## compete with Space in normal / hidden gameplay (hide lure).
## The level decides what "skip" means and must end in the same state as
## the scene playing out (see CampLevel._finish_story).

signal skipped

@export var hold_time := 1.0
@export var show_time := 2.6

var active := false
var _held := 0.0
var _done := false
var _label: Label
var _bar: ColorRect
var _bar_bg: ColorRect
var _root: Control
var _tween: Tween


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_label = Label.new()
	_label.text = "长按 Space 跳过"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override(&"font_color", Color(0.72, 0.68, 0.6))
	_label.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
	_label.add_theme_constant_override(&"outline_size", 3)
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -120.0
	_label.offset_right = -10.0
	_label.offset_top = -40.0
	_label.offset_bottom = -26.0
	_root.add_child(_label)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.2, 0.19, 0.17, 0.7)
	_bar_bg.anchor_left = 1.0
	_bar_bg.anchor_right = 1.0
	_bar_bg.anchor_top = 1.0
	_bar_bg.anchor_bottom = 1.0
	_bar_bg.offset_left = -76.0
	_bar_bg.offset_right = -10.0
	_bar_bg.offset_top = -24.0
	_bar_bg.offset_bottom = -23.0
	_root.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(0.86, 0.8, 0.64)
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(0, 1)
	_bar_bg.add_child(_bar)
	_root.modulate.a = 0.0


## Start listening; shows the hint for a moment.
func begin() -> void:
	active = true
	_done = false
	_held = 0.0
	flash_hint()


func end() -> void:
	active = false
	_held = 0.0
	_hide()


func flash_hint() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 1.0, 0.3)
	_tween.tween_interval(show_time)
	_tween.tween_property(_root, "modulate:a", 0.0, 0.8)


func _hide() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_root, "modulate:a", 0.0, 0.3)


func is_hint_visible() -> bool:
	return _root.modulate.a > 0.05


func _listening() -> bool:
	if not active or _done:
		return false
	var p := get_tree().get_first_node_in_group(&"player") as Player
	return p == null or p.state == Player.State.CUTSCENE


func _input(event: InputEvent) -> void:
	if not _listening():
		return
	# any key while the hint is gone brings it back briefly
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) or (event is InputEventAction and event.pressed)
	if pressed and _root.modulate.a < 0.5 and (_tween == null or not _tween.is_running() or _root.modulate.a < 0.05):
		flash_hint()


func _process(delta: float) -> void:
	if not _listening():
		_held = 0.0
		_bar.size.x = 0.0
		return
	if Input.is_action_pressed(&"jump"):
		_held += delta
		if _root.modulate.a < 1.0:
			if _tween:
				_tween.kill()
			_root.modulate.a = 1.0
	else:
		if _held > 0.0 and _root.modulate.a >= 1.0:
			flash_hint()
		_held = 0.0
	_bar.size.x = roundf(_bar_bg.size.x * clampf(_held / hold_time, 0.0, 1.0))
	if _held >= hold_time:
		_done = true
		active = false
		_hide()
		skipped.emit()
