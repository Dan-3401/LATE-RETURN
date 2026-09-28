extends Node
## Player settings: screen + sound only. One set of data, used by both the
## main-menu and the pause-menu settings screens, saved to
## user://settings.cfg and applied on start.
##
## Rendering stays at the 480x270 design resolution (viewport stretch,
## integer scaling): the output resolution only changes how big / sharp the
## picture is, never how much of the world the camera shows.

signal changed

enum DisplayMode { FULLSCREEN, BORDERLESS, WINDOWED }
const MODE_NAMES := ["全屏", "无边框窗口", "窗口"]
const BASE := Vector2i(480, 270)
const COMMON_RESOLUTIONS := [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const PATH := "user://settings.cfg"
const TEST_PATH := "user://settings_test_%d.cfg"

var display_mode: DisplayMode = DisplayMode.BORDERLESS
var resolution := Vector2i(1920, 1080)
## 0..100
var master := 80
var music := 70
var sfx := 80

var path := PATH
## Tests keep the window alone unless they ask for it.
var apply_display_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree().get_script() != null:
		path = TEST_PATH % OS.get_process_id()
		apply_display_enabled = false
	if not load_settings():
		reset_defaults()
		save_settings()
	apply_audio()
	apply_display()


func _exit_tree() -> void:
	if path != PATH and FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- defaults / persistence ------------------------------------------------------------
func reset_defaults() -> void:
	display_mode = DisplayMode.BORDERLESS
	resolution = screen_size()
	master = 80
	music = 70
	sfx = 80


func load_settings() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	display_mode = clampi(int(cfg.get_value("screen", "display_mode", DisplayMode.BORDERLESS)), 0, 2) as DisplayMode
	var r = cfg.get_value("screen", "resolution", screen_size())
	resolution = r if r is Vector2i else screen_size()
	master = clampi(int(cfg.get_value("audio", "master", 80)), 0, 100)
	music = clampi(int(cfg.get_value("audio", "music", 70)), 0, 100)
	sfx = clampi(int(cfg.get_value("audio", "sfx", 80)), 0, 100)
	return true


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("screen", "display_mode", int(display_mode))
	cfg.set_value("screen", "resolution", resolution)
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.save(path)


## Everything the screen code needs to put things back (display confirm).
func display_state() -> Dictionary:
	return {"mode": display_mode, "resolution": resolution}


func restore_display_state(st: Dictionary) -> void:
	display_mode = st.mode
	resolution = st.resolution
	apply_display()
	changed.emit()


# --- audio ---------------------------------------------------------------------------------
## Slider value (0..100) -> bus volume. Perceptual curve, 0 = muted;
## 100 = 0 dB, 50 ≈ -12 dB, 25 ≈ -24 dB (never "50 means 50 dB").
static func volume_to_db(v: int) -> float:
	if v <= 0:
		return -80.0
	return linear_to_db(pow(v / 100.0, 2.0))


func set_volume(bus: String, v: int) -> void:
	v = clampi(v, 0, 100)
	match bus:
		"Master": master = v
		"Music": music = v
		"SFX": sfx = v
	apply_audio()
	changed.emit()


func apply_audio() -> void:
	for b in [["Master", master], ["Music", music], ["SFX", sfx]]:
		var idx := AudioServer.get_bus_index(b[0])
		if idx < 0:
			continue
		AudioServer.set_bus_volume_db(idx, volume_to_db(b[1]))
		AudioServer.set_bus_mute(idx, b[1] <= 0)


# --- screen -----------------------------------------------------------------------------------
func screen_size() -> Vector2i:
	var s := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	return s if s.x > 0 and s.y > 0 else Vector2i(1920, 1080)


func usable_rect() -> Rect2i:
	var r := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	return r if r.size.x > 0 else Rect2i(Vector2i.ZERO, screen_size())


## Common 16:9 sizes the monitor can show, plus the monitor's own size.
func resolutions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var s := screen_size()
	for r in COMMON_RESOLUTIONS:
		if r.x <= s.x and r.y <= s.y:
			out.append(r)
	if not s in out:
		out.append(s)
	out.sort_custom(func(a, b): return a.x * a.y < b.x * b.y)
	return out


func resolution_text(r: Vector2i) -> String:
	return "%d × %d" % [r.x, r.y]


func set_display_mode(m: DisplayMode) -> void:
	display_mode = m
	apply_display()
	changed.emit()


func set_resolution(r: Vector2i) -> void:
	resolution = r
	apply_display()
	changed.emit()


## Window size actually used in windowed mode: the chosen resolution, made
## smaller (keeping 16:9) if it would not fit on the screen's usable area.
func windowed_size() -> Vector2i:
	var r := resolution
	var area := usable_rect().size - Vector2i(0, 40)   # leave room for a title bar
	if r.x > area.x or r.y > area.y:
		var k := minf(float(area.x) / r.x, float(area.y) / r.y)
		r = Vector2i(int(r.x * k), int(r.y * k))
		r.x -= r.x % 16
		r.y = r.x * 9 / 16
	return r.max(BASE)


func apply_display() -> void:
	if not apply_display_enabled or DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.window_get_current_screen()
	match display_mode:
		DisplayMode.FULLSCREEN:
			# Godot 4 fullscreen always uses the monitor's native resolution;
			# the picture is integer-scaled up from 480x270
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(screen_size())
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
		DisplayMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var size := windowed_size()
			DisplayServer.window_set_size(size)
			var ur := usable_rect()
			DisplayServer.window_set_position(ur.position + (ur.size - size) / 2)


## Does the resolution setting matter in the current mode?
func resolution_applies() -> bool:
	return display_mode == DisplayMode.WINDOWED
