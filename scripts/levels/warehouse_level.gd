extends Level
## The store's back warehouse: cramped, dark, more loot.

const STORE := "res://scenes/maps/convenience_store.tscn"

@onready var exit_interact: Interactable = $ExitDoor

var _leaving := false


func _ready() -> void:
	super._ready()
	GameState.spawn_point = &""
	camera.snap_to_target()
	exit_interact.interacted.connect(_on_exit)
	GameState.mark_location_visited()
	if not GameState.flags.get("warehouse_seen", false):
		GameState.flags["warehouse_seen"] = true
		await wait(0.8)
		await say(player, "好黑……")


func _on_exit(_a: Node2D) -> void:
	if _leaving:
		return
	_leaving = true
	player.set_cutscene(true)
	GameState.spawn_point = &"warehouse_door"
	SceneManager.change_scene(STORE, 0.6)
