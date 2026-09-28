extends Level
## Demo 2 hub: the classroom home. Talk to the sister, check the stores,
## go out through the door (region map), come back, end the day.

const DIARY := "res://scenes/ui/diary.tscn"

@export var sister_pool: DialoguePool

@onready var sister: Sister = $Sister
@onready var door_interact: Interactable = $DoorInteract
@onready var sister_interact: Interactable = $SisterInteract
@onready var region_map: RegionMap = $RegionMap
@onready var confirm: ConfirmDialog = $ConfirmDialog
@onready var dialogue_player: DialoguePlayer = $DialoguePlayer
@onready var lamp_light: PointLight2D = $Lights/Lamp
@onready var storage_interact: Interactable = $StorageInteract
@onready var storage_ui: StorageUI = $StorageUI

const FULL_LINE := "仓库已经放不下了。"
const SORT_FIRST := "带回来的东西还没整理好。"

var _last_talk := -1
var _busy := false


func _ready() -> void:
	super._ready()
	sister.play(&"sit_idle")
	dialogue_player.speakers = {"妹妹": sister, "哥哥": player}
	door_interact.interacted.connect(_on_door)
	sister_interact.interacted.connect(_on_sister)
	storage_interact.interacted.connect(func(_a): open_storage())
	# sorting the storage is a safe point too
	storage_ui.closed.connect(func(): SaveSystem.save_here(scene_file_path, "学校营地"))
	region_map.closed.connect(_on_map_closed)
	region_map.departed.connect(_on_departed)
	_refresh_sister_prompt()
	if GameState.spawn_point == &"camp_return":
		player.global_position.x = 100.0
		player.face(1)
	GameState.spawn_point = &""
	camera.snap_to_target()
	var got := GameState.pending_settlement
	GameState.pending_settlement = {}
	# autosave: start of a day / just came home (supplies already handed over)
	SaveSystem.save_here(scene_file_path, "学校营地")
	if not got.is_empty():
		await wait(1.0)
		hud.show_settlement(got)
		await wait(1.5)
		_refresh_sister_prompt()
		if GameState.has_pending():
			# the storage is full: sort things out now, nothing is thrown away
			await wait(1.8)
			say(player, FULL_LINE)
			open_storage(FULL_LINE)
		else:
			hud.show_hint("靠近妹妹  G：结束本日", 5.0)
	elif not GameState.expedition_done_today:
		await wait(1.2)
		hud.show_hint("走到门口  F：外出", 5.0)


func _refresh_sister_prompt() -> void:
	sister_interact.prompt_text = "与妹妹交谈" + ("\n[G] 结束本日" if GameState.expedition_done_today else "")
	sister_interact.refresh_prompt()


func open_storage(message := "") -> void:
	if _busy or storage_ui.is_open() or region_map.is_open or confirm.is_open:
		return
	storage_ui.open(message)


func _unhandled_input(event: InputEvent) -> void:
	if _busy or region_map.is_open or confirm.is_open or storage_ui.is_open():
		return
	if event.is_action_pressed(&"end_day"):
		if player.interaction.focused == sister_interact and GameState.expedition_done_today:
			get_viewport().set_input_as_handled()
			_ask_end_day()


# --- door / map ------------------------------------------------------------------
func _on_door(_a: Node2D) -> void:
	if _busy:
		return
	if GameState.expedition_done_today:
		say(player, "今天已经很晚了，明天再出去吧。")
		return
	if GameState.has_pending():
		say(player, SORT_FIRST)
		open_storage(FULL_LINE)
		return
	player.set_cutscene(true)
	region_map.open()


func _on_map_closed() -> void:
	player.set_cutscene(false)


func _on_departed(loc: LocationData) -> void:
	_busy = true
	AudioManager.play_at(&"door_open", door_interact.global_position, -4.0)
	SceneManager.change_scene(loc.region_scene, 1.0)


# --- sister -----------------------------------------------------------------------
func _on_sister(_a: Node2D) -> void:
	if _busy or dialogue_player.playing or sister_pool == null:
		return
	_busy = true
	player.set_cutscene(true)
	player.face(1 if sister.global_position.x > player.global_position.x else -1)
	sister.play(&"sit_up")
	var i := sister_pool.pick(_last_talk)
	_last_talk = i
	await dialogue_player.play(sister_pool.entries()[i])
	sister.play(&"sit_idle")
	player.set_cutscene(false)
	_busy = false


func _ask_end_day() -> void:
	if GameState.has_pending():
		say(player, SORT_FIRST)
		open_storage(FULL_LINE)
		return
	_busy = true
	player.set_cutscene(true)
	var yes := await confirm.ask("结束今天吗？")
	SceneManager.set_cursor(SceneManager.CursorMode.CROSSHAIR)
	if not yes:
		player.set_cutscene(false)
		_busy = false
		return
	_end_day()


## A short, quiet close of the day, then the diary.
func _end_day() -> void:
	hud.hide_hint()
	player.walk_to(214.0)
	await wait(1.6)
	player.face(-1)
	player.play_locked("search")
	sister.play(&"sit_down")
	AudioManager.play(&"rummage_box", -12.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(lamp_light, "energy", lamp_light.energy * 0.55, 3.0)
	AudioManager.play_at(&"zombie_groan", Vector2(900, 120), -16.0, 2000.0)
	await wait(2.6)
	await fade(1.0, 2.0)
	GameState.pending_diary = {
		"date": GameState.date_text(),
		"lines": DiaryWriter.daily(GameState.daily.gains, GameState.daily.rare),
		"next": &"new_day",
	}
	AudioManager.stop_all_loops(1.0)
	SceneManager.change_scene(DIARY, 0.01)
