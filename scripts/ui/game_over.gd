extends CanvasLayer
## GAME OVER — restart from the street checkpoint or return to menu.

@onready var root: Control = $Root
@onready var title: Label = $Root/Center/VBox/Title
@onready var line: Label = $Root/Center/VBox/Line
@onready var restart_btn: Button = $Root/Center/VBox/Buttons/Restart
@onready var menu_btn: Button = $Root/Center/VBox/Buttons/Menu

var _chosen := false


func _ready() -> void:
	layer = 101
	process_mode = Node.PROCESS_MODE_ALWAYS
	restart_btn.pressed.connect(_restart)
	menu_btn.pressed.connect(_menu)
	for b in [restart_btn, menu_btn]:
		b.mouse_entered.connect(func(): b.grab_focus())
		b.focus_entered.connect(func(): AudioManager.play(&"ui_move", -14.0, 0.0, &"UI"))
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
	title.modulate.a = 0.0
	line.modulate.a = 0.0
	$Root/Center/VBox/Buttons.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(title, "modulate:a", 1.0, 1.5)
	t.tween_interval(0.6)
	t.tween_property(line, "modulate:a", 1.0, 1.2)
	t.tween_interval(0.4)
	t.tween_property($Root/Center/VBox/Buttons, "modulate:a", 1.0, 0.8)
	t.tween_callback(restart_btn.grab_focus)


func _restart() -> void:
	if _chosen:
		return
	_chosen = true
	AudioManager.play(&"ui_confirm", -6.0, 0.0, &"UI")
	GameState.restore_checkpoint()
	var scene: String = GameState.checkpoint.get("scene", "res://scenes/maps/street.tscn")
	await SceneManager.fade_to(1.0, 0.6)
	queue_free()
	SceneManager.change_scene(scene, 0.01)


func _menu() -> void:
	if _chosen:
		return
	_chosen = true
	AudioManager.play(&"ui_back", -6.0, 0.0, &"UI")
	await SceneManager.fade_to(1.0, 0.6)
	queue_free()
	SceneManager.change_scene("res://scenes/ui/main_menu.tscn", 0.01)
