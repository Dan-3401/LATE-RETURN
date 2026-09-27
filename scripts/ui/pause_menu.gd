extends CanvasLayer

@onready var root: Control = $Root
@onready var resume_btn: Button = $Root/Panel/VBox/Resume
@onready var menu_btn: Button = $Root/Panel/VBox/MainMenu
@onready var quit_btn: Button = $Root/Panel/VBox/Quit

var _open := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.visible = false
	resume_btn.pressed.connect(func(): set_open(false))
	menu_btn.pressed.connect(_to_menu)
	quit_btn.pressed.connect(func(): get_tree().quit())
	for b in [resume_btn, menu_btn, quit_btn]:
		b.mouse_entered.connect(func(): AudioManager.play(&"ui_move", -12.0, 0.0, &"UI"))


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if SceneManager.is_busy():
			return
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if not _open and p and p.is_dead():
			return
		set_open(not _open)
		get_viewport().set_input_as_handled()


func set_open(v: bool) -> void:
	_open = v
	root.visible = v
	get_tree().paused = v
	AudioManager.play(&"ui_confirm" if v else &"ui_back", -10.0, 0.0, &"UI")
	if v:
		resume_btn.grab_focus()


func _to_menu() -> void:
	set_open(false)
	SceneManager.change_scene("res://scenes/ui/main_menu.tscn", 0.8)
