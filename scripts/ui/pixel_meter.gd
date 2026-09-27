class_name PixelMeter
extends Control
## Tiny crisp bar (search progress, oxygen).

var ratio := 0.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()
var fill_color := Color(0.85, 0.8, 0.62)
var back_color := Color(0.05, 0.05, 0.06, 0.75)
var bar_width := 20
var target_alpha := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


func _process(delta: float) -> void:
	modulate.a = move_toward(modulate.a, target_alpha, delta * 5.0)


func _draw() -> void:
	draw_rect(Rect2(0, 0, bar_width + 2, 4), back_color)
	var w := roundi(bar_width * ratio)
	if w > 0:
		draw_rect(Rect2(1, 1, w, 2), fill_color)
