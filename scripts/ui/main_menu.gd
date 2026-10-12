extends Node2D
## Title screen: 迟归. Dark, quiet, a flickering lamp and drifting dust.

const FIRST_SCENE := "res://scenes/maps/convenience_store.tscn"

@onready var continue_btn: Button = $UI/Menu/Continue
@onready var settings_btn: Button = $UI/Menu/Settings
@onready var start_btn: Button = $UI/Menu/Start
@onready var save_info: Label = $UI/SaveInfo
@onready var confirm: ConfirmDialog = $ConfirmDialog
@onready var quit_btn: Button = $UI/Menu/Quit
@onready var far: Node2D = $Far
@onready var mid: Node2D = $Mid
@onready var ui_root: Control = $UI/Root
@onready var version_label: Label = $UI/Root/Version

var _t := 0.0
var _starting := false


func _ready() -> void:
	get_tree().paused = false
	# the version shown on the menu comes from project.godot (one place)
	version_label.text = String(ProjectSettings.get_setting("application/config/version", "Demo"))
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
	AudioManager.play_loop(&"menu", &"amb_menu", -2.0, 3.0)
	start_btn.pressed.connect(_on_start)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(open_settings)
	quit_btn.pressed.connect(func(): get_tree().quit())
	var info := SaveSystem.read_info()
	continue_btn.visible = not info.is_empty()
	start_btn.text = "新游戏" if continue_btn.visible else "开始游戏"
	save_info.text = "%s · %s" % [info.date, info.place] if continue_btn.visible else ""
	save_info.modulate.a = 0.0
	continue_btn.focus_entered.connect(func(): create_tween().tween_property(save_info, "modulate:a", 1.0, 0.3))
	continue_btn.focus_exited.connect(func(): create_tween().tween_property(save_info, "modulate:a", 0.0, 0.3))
	for b in [continue_btn, start_btn, settings_btn, quit_btn]:
		b.mouse_entered.connect(func():
			b.grab_focus())
		b.focus_entered.connect(func(): AudioManager.play(&"ui_move", -14.0, 0.0, &"UI"))
	ui_root.modulate.a = 0.0
	create_tween().tween_property(ui_root, "modulate:a", 1.0, 2.5).set_delay(0.6)
	(continue_btn if continue_btn.visible else start_btn).grab_focus.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	# very slow drift for depth
	far.position.x = roundf(-fmod(_t * 1.5, 960.0))
	mid.position.x = roundf(sin(_t * 0.05) * 6.0)


func _on_start() -> void:
	if _starting or confirm.is_open:
		return
	if SaveSystem.has_save():
		var yes := await confirm.ask("开始新游戏会覆盖现在的存档。")
		SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
		if not yes:
			start_btn.grab_focus()
			return
		if _starting:
			return
		SaveSystem.delete_save()
	_starting = true
	AudioManager.play(&"ui_confirm", -6.0, 0.0, &"UI")
	GameState.new_game()
	SceneManager.change_scene(FIRST_SCENE, 1.6)


var settings_menu: SettingsMenu = null


## Settings on top of the menu; closing it comes back here.
func open_settings() -> void:
	if _starting or settings_menu or confirm.is_open:
		return
	settings_menu = SettingsMenu.open_over(self)
	settings_menu.closed.connect(func():
		settings_menu = null
		settings_btn.grab_focus())


func _on_continue() -> void:
	if _starting or confirm.is_open:
		return
	var scene := SaveSystem.load_game()
	if scene == "":
		# unreadable save: fall back to a normal start
		continue_btn.visible = false
		save_info.text = "存档无法读取"
		save_info.modulate.a = 1.0
		start_btn.text = "开始游戏"
		start_btn.grab_focus()
		return
	_starting = true
	AudioManager.play(&"ui_confirm", -6.0, 0.0, &"UI")
	SceneManager.change_scene(scene, 1.2, true)
