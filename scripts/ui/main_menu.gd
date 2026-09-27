extends Node2D
## Title screen: 迟归. Dark, quiet, a flickering lamp and drifting dust.

const FIRST_SCENE := "res://scenes/maps/convenience_store.tscn"

@onready var start_btn: Button = $UI/Menu/Start
@onready var quit_btn: Button = $UI/Menu/Quit
@onready var far: Node2D = $Far
@onready var mid: Node2D = $Mid
@onready var ui_root: Control = $UI/Root

var _t := 0.0
var _starting := false


func _ready() -> void:
	get_tree().paused = false
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
	AudioManager.play_loop(&"menu", &"amb_menu", -2.0, 3.0)
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(func(): get_tree().quit())
	for b in [start_btn, quit_btn]:
		b.mouse_entered.connect(func():
			b.grab_focus())
		b.focus_entered.connect(func(): AudioManager.play(&"ui_move", -14.0, 0.0, &"UI"))
	ui_root.modulate.a = 0.0
	create_tween().tween_property(ui_root, "modulate:a", 1.0, 2.5).set_delay(0.6)
	start_btn.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	# very slow drift for depth
	far.position.x = roundf(-fmod(_t * 1.5, 960.0))
	mid.position.x = roundf(sin(_t * 0.05) * 6.0)


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	AudioManager.play(&"ui_confirm", -6.0, 0.0, &"UI")
	GameState.new_game()
	SceneManager.change_scene(FIRST_SCENE, 1.6)
