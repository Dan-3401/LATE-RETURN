extends CanvasLayer
## One save slot on disk (autosave). Written at safe points only:
##  * a checkpoint is taken (street checkpoint, expedition checkpoint) — the
##    save then resumes exactly like "restart from checkpoint", so leaving the
##    game mid-expedition never pays the cost twice and never duplicates loot;
##  * the camp hub is reached (start of a day, coming home).
## The file is a binary Variant dump read with objects disallowed, so a
## tampered file can never instantiate scripts.

signal saved

## 2: equipment slots hold {path, count}; three hand slots.
## 3: camp storage (40 slots) + overflow replace the food / water counters.
const VERSION := 3
const DEFAULT_PATH := "user://savegame.dat"
## Test scripts (a custom SceneTree) never touch the player's real save;
## each test process gets its own file, removed again on exit.
const TEST_PATH := "user://savegame_test_%d.dat"

var path := DEFAULT_PATH
var _label: Label
var _tween: Tween


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().get_script() != null:
		path = TEST_PATH % OS.get_process_id()
		delete_save()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load("res://scenes/ui/theme.tres")
	add_child(root)
	_label = Label.new()
	_label.text = "进度已保存"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_color_override(&"font_color", Color(0.72, 0.68, 0.58))
	_label.add_theme_color_override(&"font_outline_color", Color(0.03, 0.03, 0.04))
	_label.add_theme_constant_override(&"outline_size", 3)
	# top-right, under the camp resources (the quick bar owns the bottom-right);
	# anchored so it follows the stretched viewport
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -96.0
	_label.offset_top = 30.0
	_label.offset_right = -8.0
	_label.offset_bottom = 44.0
	_label.modulate.a = 0.0
	root.add_child(_label)


func _exit_tree() -> void:
	if path != DEFAULT_PATH:
		delete_save()


func has_save() -> bool:
	return not read_info().is_empty()


## Short description for the main menu, e.g. {"date": "9月29日", "place": "学校营地"}.
func read_info() -> Dictionary:
	var d := _read()
	if d.is_empty():
		return {}
	return {"date": d.get("date", ""), "place": d.get("place", ""), "day": d.get("day", 0)}


func delete_save() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Save "resume from the current checkpoint" (street / expedition start).
func save_checkpoint(place: String) -> bool:
	var cp: Dictionary = GameState.checkpoint
	if cp.is_empty():
		return false
	var spawn := &"region_start" if GameState.is_free_phase() else &""
	return _write(cp.scene, place, cp, cp, spawn)


## Save "resume in this scene with the current state" (camp hub).
func save_here(scene_path: String, place: String) -> bool:
	return _write(scene_path, place, GameState.snapshot(), GameState.checkpoint, &"")


## Restores the saved state into GameState and returns the scene to load,
## or "" if there is no usable save.
func load_game() -> String:
	var d := _read()
	if d.is_empty():
		return ""
	GameState.new_game()
	GameState.apply_snapshot(d.state)
	GameState.checkpoint = d.checkpoint.duplicate(true)
	GameState.spawn_point = d.spawn
	return d.scene


func _write(scene_path: String, place: String, state: Dictionary, checkpoint: Dictionary, spawn: StringName) -> bool:
	var data := {
		"version": VERSION,
		"scene": scene_path,
		"place": place,
		"date": GameState.date_text(int(state.get("day_index", GameState.day_index))),
		"day": int(state.get("day_index", GameState.day_index)),
		"time": Time.get_unix_time_from_system(),
		"state": state.duplicate(true),
		"checkpoint": checkpoint.duplicate(true),
		"spawn": spawn,
	}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot write %s (%d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_var(data, false)
	f.close()
	# write-then-rename so a crash mid-write never destroys the old save
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null or dir.rename(tmp.get_file(), path.get_file()) != OK:
		push_warning("SaveSystem: cannot replace %s" % path)
		return false
	_flash()
	saved.emit()
	return true


func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() == 0:
		return {}
	var d = f.get_var(false)
	if not d is Dictionary or int(d.get("version", -1)) != VERSION:
		return {}
	for k in ["scene", "state", "checkpoint", "spawn"]:
		if not d.has(k):
			return {}
	if not d.state is Dictionary or not d.checkpoint is Dictionary or not ResourceLoader.exists(String(d.scene)):
		return {}
	return d


func _flash() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 0.9, 0.3)
	_tween.tween_interval(1.6)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.8)
