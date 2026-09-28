extends Level
## Chapter 3 — the school camp. The brother comes home; the ending plays.

const DIARY := "res://scenes/ui/diary.tscn"

@export var dialogue: DialogueData

@onready var sister: Sister = $Sister
@onready var door: Sprite2D = $Room/Door
@onready var dialogue_player: DialoguePlayer = $DialoguePlayer
@onready var letterbox_top: ColorRect = $Letterbox/Top
@onready var letterbox_bottom: ColorRect = $Letterbox/Bottom
@onready var lamp_light: PointLight2D = $Lights/Lamp

const DOOR_OPEN := preload("res://art/environment/camp/door_open.png")
const DOOR_CLOSED := preload("res://art/environment/camp/door.png")


func _ready() -> void:
	super._ready()
	SceneManager.set_cursor(SceneManager.CursorMode.HIDDEN)
	hud.get_node("Overlay").visible = false
	player.set_cutscene(true)
	player.visible = false
	player.flashlight.set_on(false, true)
	player.hands.holster()
	camera.set_override(true)
	camera.manual_position = Vector2(250, 135)
	camera.global_position = Vector2(250, 135)
	dialogue_player.speakers = {"妹妹": sister, "哥哥": player}
	dialogue_player.command_handler = _on_command
	_letterbox(true, 0.01)
	_start()


func _start() -> void:
	await wait(1.2)
	await dialogue_player.play(dialogue)


func _on_command(cmd: String, args: Array):
	match cmd:
		"sister":
			sister.play(StringName(args[0]))
		"sister_cough":
			sister.cough(&"sit_down")
			return _timer_signal(1.2)
		"door_open":
			door.texture = DOOR_OPEN
			AudioManager.play_at(&"door_open", door.global_position, -2.0)
			player.visible = true
			return _enter_room()
		"brother_walk":
			return _walk(float(args[0]))
		"brother_putdown":
			player.play_locked("search")
			AudioManager.play(&"bag_close", -6.0)
		"brother_stand":
			player.unlock_animation()
		"brother_look_table":
			player.face(-1)
		"brother_face_sister":
			player.face(1)
		"ending":
			return _ending()
	return null


func _timer_signal(t: float) -> Signal:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = t
	add_child(timer)
	timer.start()
	timer.timeout.connect(timer.queue_free)
	return timer.timeout


func _enter_room() -> Signal:
	var s := Signal(self, &"_step_done")
	_do_enter()
	return s


signal _step_done


func _do_enter() -> void:
	await player.walk_to(118.0)
	door.texture = DOOR_CLOSED
	AudioManager.play_at(&"hide_exit", door.global_position, -8.0)
	_step_done.emit()


func _walk(x: float) -> Signal:
	_do_walk(x)
	return Signal(self, &"_step_done")


func _do_walk(x: float) -> void:
	create_tween().tween_property(camera, "manual_position", Vector2(336, 135), 3.0).set_trans(Tween.TRANS_SINE)
	await player.walk_to(x)
	player.face(1)
	_step_done.emit()


func _ending() -> Signal:
	_do_ending()
	return Signal(self, &"_step_done")


## Camera pulls back; he starts sorting the supplies, she sits nearby.
## Wind moves the window, far away something groans. Fade. 迟归.
func _do_ending() -> void:
	sister.play(&"sit_idle")
	await wait(0.6)
	player.face(-1)
	player.walk_to(214.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(camera, "manual_position", Vector2(320, 118), 7.0).set_trans(Tween.TRANS_SINE)
	_letterbox(false, 3.0)
	await wait(2.6)
	player.play_locked("search")
	AudioManager.play(&"rummage_box", -10.0)
	await wait(2.0)
	AudioManager.play_at(&"zombie_groan", Vector2(900, 120), -14.0, 2000.0)
	await wait(2.4)
	AudioManager.play(&"rummage_1", -12.0)
	await wait(2.0)
	var fade_t := create_tween()
	fade_t.tween_property(lamp_light, "energy", lamp_light.energy * 0.6, 3.0)
	await fade(1.0, 3.5)
	await wait(1.4)
	AudioManager.stop_all_loops(2.0)
	_step_done.emit()
	# the first day ends with the brother's diary
	GameState.pending_diary = {"date": GameState.date_text(0), "lines": DiaryWriter.first_day(), "next": &"first"}
	SceneManager.change_scene(DIARY, 0.01)


func _letterbox(on: bool, time: float) -> void:
	var h := 22.0 if on else 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(letterbox_top, "size:y", h, time)
	t.tween_property(letterbox_bottom, "position:y", 270.0 - h, time)
	t.tween_property(letterbox_bottom, "size:y", h, time)
