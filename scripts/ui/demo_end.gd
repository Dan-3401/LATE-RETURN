extends Control
## 《迟归》 — Demo End.

@onready var logo: TextureRect = $Center/VBox/Logo
@onready var end_label: Label = $Center/VBox/End
@onready var hint: Label = $Hint

var _can_leave := false


func _ready() -> void:
	SceneManager.set_cursor(SceneManager.CursorMode.HIDDEN)
	logo.modulate.a = 0.0
	end_label.modulate.a = 0.0
	hint.modulate.a = 0.0
	AudioManager.play_loop(&"end", &"amb_wind_inside", -14.0, 3.0)
	var t := create_tween()
	t.tween_interval(1.0)
	t.tween_property(logo, "modulate:a", 1.0, 3.0)
	t.tween_interval(2.5)
	t.tween_property(end_label, "modulate:a", 1.0, 2.0)
	t.tween_interval(2.0)
	t.tween_callback(func(): _can_leave = true)
	t.tween_property(hint, "modulate:a", 0.6, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if not _can_leave:
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			_can_leave = false
			AudioManager.stop_loop(&"end", 1.5)
			SceneManager.change_scene("res://scenes/ui/main_menu.tscn", 1.5)
