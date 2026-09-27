class_name Level
extends Node2D
## Shared level plumbing: references to player / HUD / camera, ambience.

@export var ambience: Array[StringName] = []
@export var ambience_volume_db := -6.0
@export var cursor_crosshair := true

var player: Player
var hud: HUD
var camera: GameCamera


func _ready() -> void:
	player = get_tree().get_first_node_in_group(&"player") as Player
	hud = find_child("HUD", true, false) as HUD
	camera = get_tree().get_first_node_in_group(&"game_camera") as GameCamera
	SceneManager.set_cursor(SceneManager.CursorMode.CROSSHAIR if cursor_crosshair else SceneManager.CursorMode.ARROW)
	for i in ambience.size():
		AudioManager.play_loop(StringName("amb_%d" % i), ambience[i], ambience_volume_db, 2.5)
	if player:
		player.died.connect(_on_player_died)


func say(speaker: Node2D, text: String, hold: float = -1.0) -> void:
	var ui := WorldUI.get_instance(self)
	if ui == null:
		return
	var b := ui.say(speaker, text, hold)
	await b.finished


func wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout


func _on_player_died() -> void:
	pass
