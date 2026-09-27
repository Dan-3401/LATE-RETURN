class_name DialoguePlayer
extends Node
## Plays a DialogueData script: overhead bubbles for each line, pauses, and
## commands forwarded to a callback. Interact / jump / click advances.

signal line_started(speaker: String, text: String)
signal finished

## speaker name -> Node2D
var speakers := {}
## Callable(name: String, args: Array) -> may be awaited (return a Signal or null)
var command_handler: Callable
var playing := false
var _bubble: Control


func play(data: DialogueData) -> void:
	playing = true
	var ui := WorldUI.get_instance(self)
	for entry in data.parse():
		if not is_inside_tree():
			return
		match entry.type:
			"pause":
				await _wait(entry.time)
			"cmd":
				if command_handler.is_valid():
					var r = command_handler.call(entry.name, entry.args)
					if r is Signal:
						await r
			"line":
				var who: Node2D = speakers.get(entry.speaker)
				if who == null or ui == null:
					continue
				line_started.emit(entry.speaker, entry.text)
				_bubble = ui.say(who, entry.text, 0.9 + entry.text.length() * 0.06)
				await _bubble.finished
				_bubble = null
				await _wait(0.22)
	playing = false
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not playing or _bubble == null or not is_instance_valid(_bubble):
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"jump") or event.is_action_pressed(&"attack"):
		_bubble.call(&"skip")
		get_viewport().set_input_as_handled()


func _wait(t: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(t, 0.001)
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
