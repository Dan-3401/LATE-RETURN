extends Level
## Chapter 2 — the abandoned street. Sneak east to the school.
## A Street Checkpoint is created the first time the level is entered;
## GAME OVER restarts here with the player's state at that moment.

const CAMP_SCENE := "res://scenes/maps/school_camp.tscn"

@onready var exit_zone: TriggerZone = $ExitZone
@onready var first_sight: TriggerZone = $Triggers/FirstSight
@onready var breath_hint: TriggerZone = $Triggers/BreathHint
@onready var hide_hint_zone: TriggerZone = $Triggers/HideHint

var _leaving := false


func _ready() -> void:
	super._ready()
	if GameState.checkpoint.get("id", &"") != &"street":
		GameState.save_checkpoint(&"street", scene_file_path)
	GameState.start_objective(&"street", "穿过街道，返回营地", {})
	exit_zone.triggered.connect(_on_exit)
	first_sight.triggered.connect(_on_first_sight)
	breath_hint.triggered.connect(func(_p): hud.show_hint("按住鼠标右键：屏住呼吸", 5.0))
	hide_hint_zone.triggered.connect(func(_p): hud.show_hint("F：躲藏", 4.0))
	camera.snap_to_target()
	_intro()


func _intro() -> void:
	player.set_cutscene(true)
	await wait(0.8)
	player.set_cutscene(false)
	await wait(0.6)
	hud.show_hint("Caps Lock：静步    Shift：奔跑", 6.0)


func _on_first_sight(_p: Player) -> void:
	await say(player, "还是不要招惹这些家伙比较好……")


func _on_exit(_p: Player) -> void:
	if _leaving or player.is_dead():
		return
	_leaving = true
	player.set_cutscene(true)
	GameState.flags["street_done"] = true
	GameState.clear_objective()
	player.walk_to(player.global_position.x + 60.0)
	await wait(0.6)
	SceneManager.change_scene(CAMP_SCENE, 1.4, true)
