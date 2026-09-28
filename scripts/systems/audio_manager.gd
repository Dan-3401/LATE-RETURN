extends Node
## Sound playback. Sounds are looked up by name: res://audio/<group>/<name>_<n>.wav
## (numbered variations are picked at random) or res://audio/<group>/<name>.wav.

const SEARCH_DIRS := ["res://audio/sfx/", "res://audio/amb/", "res://audio/ui/"]
const MAX_VARIANTS := 8
const POOL_SIZE := 12

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)


## Bus tree (the three volume sliders are Master, Music and SFX):
##   Master <- Music <- Ambience          (background / atmosphere loops)
##   Master <- SFX   <- World, UI, Voice   (every gameplay / UI sound)
## A bus may only send to one created before it, hence the order.
const BUSES := [["Music", &"Master"], ["SFX", &"Master"], ["Ambience", &"Music"],
	["World", &"SFX"], ["UI", &"SFX"], ["Voice", &"SFX"]]


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b[0]) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b[0])
		AudioServer.set_bus_send(AudioServer.get_bus_index(b[0]), b[1])
	# a subtle room reverb on positional world sounds
	var w := AudioServer.get_bus_index("World")
	if AudioServer.get_bus_effect_count(w) == 0:
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.45
		rev.damping = 0.6
		rev.wet = 0.12
		rev.dry = 1.0
		AudioServer.add_bus_effect(w, rev)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), -4.0)


func get_streams(sound: StringName) -> Array:
	if _cache.has(sound):
		return _cache[sound]
	var found: Array = []
	for dir in SEARCH_DIRS:
		var single: String = dir + String(sound) + ".wav"
		if ResourceLoader.exists(single):
			found.append(load(single))
		for i in range(1, MAX_VARIANTS + 1):
			var p: String = dir + "%s_%d.wav" % [sound, i]
			if ResourceLoader.exists(p):
				found.append(load(p))
		if not found.is_empty():
			break
	if found.is_empty():
		push_warning("AudioManager: missing sound '%s'" % sound)
	_cache[sound] = found
	return found


func _pick(sound: StringName) -> AudioStream:
	var s := get_streams(sound)
	return null if s.is_empty() else s[randi() % s.size()]


## Non-positional one-shot (UI, player-centric sounds).
func play(sound: StringName, volume_db: float = 0.0, pitch_var: float = 0.06, bus: StringName = &"SFX") -> void:
	var stream := _pick(sound)
	if stream == null:
		return
	var player: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _pool[0]
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	player.bus = bus
	player.play()


## Positional one-shot in the current scene.
func play_at(sound: StringName, pos: Vector2, volume_db: float = 0.0, max_distance: float = 900.0, pitch_var: float = 0.08) -> AudioStreamPlayer2D:
	var stream := _pick(sound)
	var scene := get_tree().current_scene
	if stream == null or scene == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.attenuation = 1.6
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.bus = &"World"
	p.global_position = pos
	scene.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Looping ambience by key; fades in.
func play_loop(key: StringName, sound: StringName, volume_db: float = 0.0, fade: float = 1.5) -> void:
	if _loops.has(key):
		return
	var stream := _pick(sound)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Ambience"
	p.volume_db = -60.0
	add_child(p)
	p.play()
	_loops[key] = p
	create_tween().tween_property(p, "volume_db", volume_db, fade)


func stop_loop(key: StringName, fade: float = 1.5) -> void:
	if not _loops.has(key):
		return
	var p: AudioStreamPlayer = _loops[key]
	_loops.erase(key)
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, fade)
	t.tween_callback(p.queue_free)


func stop_all_loops(fade: float = 1.0) -> void:
	for k in _loops.keys():
		stop_loop(k, fade)
