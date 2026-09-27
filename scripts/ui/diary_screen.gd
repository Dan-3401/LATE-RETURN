extends Control
## A handwritten diary page fading in from the dark. Any key continues.
## Reads GameState.pending_diary = {date, lines, next}.

const CAMP_HUB := "res://scenes/maps/camp_hub.tscn"

@onready var paper: Control = $Paper
@onready var date_label: Label = $Paper/Date
@onready var lines_box: VBoxContainer = $Paper/Lines
@onready var hint: Label = $Hint
@onready var task_box: Control = $Task
@onready var task_title: Label = $Task/Title

var _can_continue := false
var _leaving := false


func _ready() -> void:
	SceneManager.set_cursor(SceneManager.CursorMode.HIDDEN)
	var page: Dictionary = GameState.pending_diary
	if page.is_empty():
		page = {"date": GameState.date_text(), "lines": DiaryWriter.first_day(), "next": &"first"}
	date_label.text = page.date
	for l in page.lines:
		var lab := Label.new()
		lab.text = l
		lab.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		lab.custom_minimum_size = Vector2(236, 0)
		lab.theme_type_variation = &"DiaryLabel"
		lab.modulate.a = 0.0
		lines_box.add_child(lab)
	paper.modulate.a = 0.0
	date_label.modulate.a = 0.0
	hint.modulate.a = 0.0
	task_box.modulate.a = 0.0
	AudioManager.play_loop(&"diary", &"amb_wind_inside", -16.0, 3.0)
	_reveal()


func _reveal() -> void:
	await _wait(1.0)
	var t := create_tween()
	t.tween_property(paper, "modulate:a", 1.0, 2.2)
	await t.finished
	AudioManager.play(&"page", -10.0)
	await _fade_in(date_label, 0.8)
	await _wait(0.5)
	for lab in lines_box.get_children():
		await _fade_in(lab, 0.9)
		await _wait(0.45 + lab.text.length() * 0.03)
	await _wait(0.6)
	_can_continue = true
	create_tween().tween_property(hint, "modulate:a", 0.7, 1.0)


func _fade_in(n: CanvasItem, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(n, "modulate:a", 1.0, t)
	await tw.finished


func _wait(t: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = t
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_continue or _leaving:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_continue()


func _continue() -> void:
	_leaving = true
	var next: StringName = GameState.pending_diary.get("next", &"first")
	var t := create_tween().set_parallel(true)
	t.tween_property(paper, "modulate:a", 0.0, 1.6)
	t.tween_property(hint, "modulate:a", 0.0, 0.6)
	await t.finished
	await _wait(0.8)
	AudioManager.stop_loop(&"diary", 1.5)
	GameState.pending_diary = {}
	if next == &"first":
		# the task quietly appears in the dark, then day two begins
		task_title.text = GameState.MAIN_QUEST_TITLE
		AudioManager.play(&"objective", -8.0, 0.0, &"UI")
		await _fade_in(task_box, 2.0)
		await _wait(2.6)
		GameState.start_free_phase()
		SceneManager.change_scene(CAMP_HUB, 1.2)
	else:
		GameState.new_day()
		SceneManager.change_scene(CAMP_HUB, 1.2)
