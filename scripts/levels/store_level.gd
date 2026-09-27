extends Level
## Chapter 1 — the abandoned convenience store.
## Wake up -> flashlight -> loot water x4 / food x4 -> exit.

const STREET_SCENE := "res://scenes/maps/street.tscn"
const REQUIRED := {&"water": 4, &"food": 4}

@export var skip_intro := false

@onready var exit_door: ExitDoor = $ExitDoor
@onready var warehouse_door: WarehouseDoor = $WarehouseDoor

var _objective_started := false
var _completion_announced := false
var _bag_hint_shown := false


const WAREHOUSE_SCENE := "res://scenes/maps/warehouse.tscn"

var _leaving := false


func _ready() -> void:
	var free := GameState.is_free_phase()
	set_meta(&"hold_black", not skip_intro and not free)
	super._ready()
	warehouse_door.entered.connect(_on_warehouse)
	if free:
		_setup_free_mode()
		return
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.inventory_changed.connect(_on_inventory_changed)
	exit_door.exit_requested.connect(_on_exit)
	player.flashlight.toggled.connect(_on_flashlight_toggled)
	if skip_intro:
		_start_objective()
	else:
		_intro()


## Demo 2: the same store, visited again. Whatever was searched before stays
## empty (see LootDirector); the exit leads back to the street.
func _setup_free_mode() -> void:
	exit_door.set_unlocked(true)
	exit_door.exit_requested.connect(_on_exit_free)
	if GameState.spawn_point == &"warehouse_door":
		player.global_position.x = warehouse_door.global_position.x + 14.0
		player.face(1)
	else:
		player.global_position.x = exit_door.global_position.x - 16.0
		player.face(-1)
	GameState.spawn_point = &""
	camera.snap_to_target()


func _on_exit_free(_actor: Node2D) -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	GameState.spawn_point = &"location_exit"
	SceneManager.change_scene(GameState.expedition.get("region", "res://scenes/maps/region_store.tscn"), 0.7)


func _on_warehouse(_actor: Node2D) -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	GameState.mark_location_visited()
	AudioManager.play_at(&"door_open", warehouse_door.global_position, -4.0)
	SceneManager.change_scene(WAREHOUSE_SCENE, 0.7)


func _intro() -> void:
	player.set_cutscene(true)
	player.play_locked("lying")
	camera.snap_to_target()
	SceneManager.set_black(1.0)
	await wait(1.0)
	AudioManager.play(&"wake_breath", -8.0)
	await fade(0.0, 3.5)
	await wait(1.4)
	player.play_locked("getup")
	await player.body_sprite.animation_finished
	player.unlock_animation()
	await wait(0.5)
	await say(player, "我居然在这种地方睡着了吗……")
	await wait(0.7)
	await say(player, "不行，我得加快了。")
	player.set_cutscene(false)
	hud.show_hint("H：打开手电筒", 8.0)
	# If the player never turns on the light, start the task anyway.
	await wait(9.0)
	_start_objective()


func _on_flashlight_toggled(on: bool) -> void:
	if on and not _objective_started and player.state == Player.State.NORMAL:
		hud.hide_hint()
		await wait(0.8)
		_start_objective()


func _start_objective() -> void:
	if _objective_started:
		return
	_objective_started = true
	GameState.start_objective(&"store_supplies", "搜集足够的生存物资", REQUIRED)
	AudioManager.play(&"objective", -8.0, 0.0, &"UI")
	hud.show_hint("靠近货架  F：搜刮", 5.0)


func _on_inventory_changed() -> void:
	if not _bag_hint_shown and GameState.inventory.count_item(&"water") + GameState.inventory.count_tag(&"food") > 0:
		_bag_hint_shown = true
		await wait(1.0)
		hud.show_hint("Tab：查看背包", 4.0)


func _on_objective_changed() -> void:
	var done: bool = GameState.objective.get("id") == &"store_supplies" and GameState.is_objective_complete()
	exit_door.set_unlocked(done)
	if done and not _completion_announced:
		_completion_announced = true
		AudioManager.play(&"objective", -6.0, 0.0, &"UI")
		await wait(0.6)
		await say(player, "物资准备完成。")
		await wait(0.3)
		GameState.objective.title = "前往出口，返回营地。"
		GameState.objective_changed.emit()
		hud.show_hint("前往出口，返回营地。", 5.0)


func _on_exit(_actor: Node2D) -> void:
	player.set_cutscene(true)
	GameState.flags["store_done"] = true
	GameState.clear_objective()
	await wait(0.4)
	if ResourceLoader.exists(STREET_SCENE):
		SceneManager.change_scene(STREET_SCENE, 1.2)
	else:
		push_warning("Street scene not built yet")
		player.set_cutscene(false)
