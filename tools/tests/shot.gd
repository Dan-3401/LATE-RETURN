extends SceneTree
## Usage: godot --path . -s res://tools/tests/shot.gd -- <scene> <out.png> [seconds] [actions]
## actions: comma list of "t:action" e.g. "1.0:flashlight,2.0:move_right_down,3.5:move_right_up"

var _scene: String
var _out: String
var _secs := 3.0
var _actions: Array = []
var _t := 0.0
var _shots: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_scene = args[0]
	_out = args[1]
	if args.size() > 2:
		_secs = float(args[2])
	if args.size() > 3 and args[3] != "":
		for a in args[3].split(","):
			var p := a.split(":")
			_actions.append({"t": float(p[0]), "a": p[1], "arg": p[2] if p.size() > 2 else ""})
	var packed: PackedScene = load(_scene)
	var inst := packed.instantiate()
	if args.size() > 4 and args[4] != "":
		for kv in args[4].split(","):
			var p := kv.split("=")
			inst.set(p[0], str_to_var(p[1]))
	root.add_child.call_deferred(inst)
	set_deferred("current_scene", inst)


func _process(delta: float) -> bool:
	_t += delta
	while not _actions.is_empty() and _actions[0].t <= _t:
		var a: Dictionary = _actions.pop_front()
		_do(a.a, a.arg)
	if _t >= _secs:
		_save(_out)
		return true
	return false


func _do(a: String, arg: String) -> void:
	if a == "shot":
		_save(arg)
		return
	if a == "mouse":
		var p := arg.split(";")
		var ev := InputEventMouseMotion.new()
		ev.position = Vector2(float(p[0]), float(p[1]))
		root.warp_mouse(ev.position)
		Input.parse_input_event(ev)
		return
	if a == "call":
		# call:<node path>;<method>
		var p := arg.split(";")
		var n := root.get_node_or_null(p[0])
		if n:
			n.call(p[1])
		return
	var down := a.ends_with("_down")
	var up := a.ends_with("_up")
	var act := a.trim_suffix("_down").trim_suffix("_up")
	if down:
		Input.action_press(act)
	elif up:
		Input.action_release(act)
	else:
		var ev := InputEventAction.new()
		ev.action = act
		ev.pressed = true
		Input.parse_input_event(ev)
		var ev2 := InputEventAction.new()
		ev2.action = act
		ev2.pressed = false
		Input.parse_input_event.call_deferred(ev2)


func _save(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
