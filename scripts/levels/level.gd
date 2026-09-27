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
	var b: Control
	if speaker.has_method(&"say"):
		b = speaker.call(&"say", text, hold)
	else:
		b = ui.say(speaker, text, hold)
	if b:
		await b.finished


## Waits using a Timer owned by the level: if the level is freed mid-wait
## (restart, quit to menu) the coroutine is dropped instead of resuming on a
## freed instance.
func wait(t: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(t, 0.001)
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()


## Starts a SceneManager fade and waits for it on a level-owned timer.
func fade(alpha: float, time: float) -> void:
	SceneManager.fade_to(alpha, time)
	await wait(time)


# --- Death sequence -------------------------------------------------------------
## The player collapses, nearby zombies close in and feed, the world drains
## to a dark red silhouette, then GAME OVER.
func _on_player_died() -> void:
	var cm := find_child("CanvasModulate", false, false) as CanvasModulate
	hud.hide_hint()
	hud.get_node("Overlay/Objective").visible = false
	for z in get_tree().get_nodes_in_group(&"zombie"):
		if z.dead:
			continue
		if z.global_position.distance_to(player.global_position) < 460.0 and z.machine.state_name() != &"Feed":
			z.machine.transition_to(&"Feed")
	AudioManager.stop_all_loops(2.0)
	AudioManager.play(&"sting_death", -2.0)
	await wait(0.8)
	var vig := hud.get_node("Overlay/DamageVignette") as CanvasItem
	var t := create_tween().set_parallel(true)
	if cm:
		t.tween_property(cm, "color", Color(0.3, 0.03, 0.035), 3.0)
	t.tween_property(vig, "modulate:a", 0.95, 3.0)
	for l in find_children("*", "Light2D", true, false):
		if l.get_parent() != player:
			t.tween_property(l, "energy", 0.0, 2.5)
	for i in 3:
		AudioManager.play(&"heartbeat", -4.0 - i * 4.0, 0.0)
		await wait(0.9 + i * 0.3)
	await wait(1.4)
	await fade(1.0, 1.5)
	var go: Node = load("res://scenes/ui/game_over.tscn").instantiate()
	get_tree().root.add_child(go)
	SceneManager.set_black(0.0)
