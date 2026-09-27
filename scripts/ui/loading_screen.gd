extends CanvasLayer

@onready var dots: Label = $Root/Dots
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	dots.text = ".".repeat(int(_t * 2.0) % 4)
