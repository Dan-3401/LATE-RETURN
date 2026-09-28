extends Level
## Demo 2: an outside region reached from the camp map. The expedition
## checkpoint is taken the first time the region is entered. The way home
## only opens after at least one real location has been explored.

const CAMP := "res://scenes/maps/camp_hub.tscn"

@export_file("*.tscn") var location_scene: String = "res://scenes/maps/convenience_store.tscn"
@export var start_x := 2480.0
@export var location_door_x := 160.0

@onready var gate: Interactable = $SchoolGate
@onready var location_door: Interactable = $LocationDoor

var _leaving := false
var _gate_line_cd := 0.0


func _ready() -> void:
	super._ready()
	var cp_id := StringName("expedition_%d" % GameState.day_index)
	var arriving := GameState.spawn_point != &"location_exit"
	if arriving:
		player.global_position.x = start_x
		player.face(-1)
		if GameState.checkpoint.get("id", &"") != cp_id:
			GameState.save_checkpoint(cp_id, scene_file_path)
			SaveSystem.save_checkpoint("外出途中")
	else:
		player.global_position.x = location_door_x
		player.face(1)
	GameState.spawn_point = &""
	camera.snap_to_target()
	gate.condition = func(_a): return GameState.expedition.get("location_visited", false)
	gate.actor_near.connect(_on_gate_near)
	gate.interacted.connect(_on_gate)
	location_door.interacted.connect(_on_location_door)
	if arriving:
		await wait(1.0)
		if GameState.throwable() != null:
			hud.show_hint("2：准备投掷    左键：投出", 5.0)
		elif GameState.inventory.count_item(&"empty_bottle") > 0:
			hud.show_hint("Tab：在背包里装备空瓶子，就能投掷", 5.0)


func _process(delta: float) -> void:
	_gate_line_cd = maxf(_gate_line_cd - delta, 0.0)


func _on_gate_near(actor: Node2D, near: bool) -> void:
	if near and not GameState.expedition.get("location_visited", false) and _gate_line_cd <= 0.0 \
			and actor == player and player.state == Player.State.NORMAL:
		_gate_line_cd = 5.0
		player.say("还什么都没干呢……")


func _on_gate(_a: Node2D) -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	GameState.end_expedition()
	GameState.spawn_point = &"camp_return"
	SceneManager.change_scene(CAMP, 0.9)


func _on_location_door(_a: Node2D) -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	GameState.mark_location_visited()
	GameState.spawn_point = &"location_entry"
	AudioManager.play_at(&"door_open", location_door.global_position, -4.0)
	SceneManager.change_scene(location_scene, 0.7)
