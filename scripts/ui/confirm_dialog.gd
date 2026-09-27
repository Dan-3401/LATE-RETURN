class_name ConfirmDialog
extends CanvasLayer
## Tiny pixel yes/no prompt. `var ok = await dialog.ask("结束今天吗？")`

signal answered(yes: bool)

@onready var root: Control = $Root
@onready var label: Label = $Root/Panel/VBox/Text
@onready var yes_btn: Button = $Root/Panel/VBox/Buttons/Yes
@onready var no_btn: Button = $Root/Panel/VBox/Buttons/No

var is_open := false


func _ready() -> void:
	layer = 26
	root.visible = false
	yes_btn.pressed.connect(func(): _answer(true))
	no_btn.pressed.connect(func(): _answer(false))


func ask(text: String, yes_text := "是", no_text := "否") -> bool:
	label.text = text
	yes_btn.text = yes_text
	no_btn.text = no_text
	root.visible = true
	is_open = true
	no_btn.grab_focus()
	SceneManager.set_cursor(SceneManager.CursorMode.ARROW)
	AudioManager.play(&"ui_confirm", -12.0, 0.0, &"UI")
	var r: bool = await answered
	return r


func _answer(v: bool) -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	AudioManager.play(&"ui_confirm" if v else &"ui_back", -10.0, 0.0, &"UI")
	answered.emit(v)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_answer(false)
