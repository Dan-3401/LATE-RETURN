extends PanelContainer
## "[F] 搜刮" prompt that fades in/out next to world objects.

@onready var _label: Label = $Label
var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_text(t: String) -> void:
	if _label.text != t:
		_label.text = t
		reset_size()


func appear() -> void:
	_fade(1.0, 0.18)


func disappear() -> void:
	_fade(0.0, 0.25, true)


func _fade(a: float, t: float, free_after := false) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", a, t)
	if free_after:
		_tween.tween_callback(queue_free)
