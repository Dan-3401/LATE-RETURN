extends Control
## Overhead speech bubble with typewriter effect. Follows its speaker.

signal finished

const CHARS_PER_SEC := 20.0

var speaker: Node2D
var voice: StringName = &"text_tick"
var _hold := 1.5
var _typing := false
var _chars := 0.0
var _hold_left := 0.0
var _done := false
var _dismissing := false

@onready var _panel: PanelContainer = $Panel
@onready var _label: Label = $Panel/Label
@onready var _tail: Control = $Tail


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func start(text: String, hold: float = -1.0) -> void:
	_label.text = text
	_label.visible_characters = 0
	_hold = hold if hold >= 0.0 else 1.1 + text.length() * 0.07
	_typing = true
	_chars = 0.0
	# size the panel for the full text so it does not grow while typing
	_label.visible_characters = -1
	_panel.reset_size()
	_label.visible_characters = 0
	size = _panel.size
	_place()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func _process(delta: float) -> void:
	if not is_instance_valid(speaker):
		dismiss(true)
		return
	if _typing:
		var before := int(_chars)
		_chars += CHARS_PER_SEC * delta
		var now := mini(int(_chars), _label.text.length())
		if now != before and now % 2 == 0 and voice != &"":
			var ch := _label.text.substr(now - 1, 1)
			if ch != "." and ch != "。" and ch != " ":
				AudioManager.play(voice, -20.0, 0.12, &"UI")
		_label.visible_characters = now
		if now >= _label.text.length():
			_typing = false
			_hold_left = _hold
	elif not _dismissing:
		_hold_left -= delta
		if _hold_left <= 0.0:
			dismiss()
	_place()


func skip() -> void:
	if _typing:
		_chars = _label.text.length()
	else:
		_hold_left = 0.0


func _place() -> void:
	var ui := get_parent() as WorldUI
	if ui == null or not is_instance_valid(speaker):
		return
	var anchor := speaker.global_position + Vector2(0, -54)
	if speaker.has_method(&"get_speech_anchor"):
		anchor = speaker.call(&"get_speech_anchor")
	var sp := ui.world_to_screen(anchor)
	var target := sp - Vector2(size.x * 0.5, size.y + 3)
	position = ui.clamp_rect_to_screen(target, size)
	# point the tail at the speaker
	_tail.position = Vector2(clampf(sp.x - position.x - 2, 4, size.x - 8), size.y - 1).round()


func dismiss(immediate := false) -> void:
	if _dismissing:
		return
	_dismissing = true
	if immediate:
		_finish()
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(_finish)


func _finish() -> void:
	if not _done:
		_done = true
		finished.emit()
	queue_free()
