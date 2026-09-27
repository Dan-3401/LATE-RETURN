extends Line2D
## Short-lived bullet tracer + impact sparks.

func setup(from: Vector2, to: Vector2) -> void:
	points = PackedVector2Array([from, to])
	width = 1.0
	default_color = Color(1.0, 0.9, 0.6, 0.9)
	var sparks := get_node_or_null(^"Sparks") as CPUParticles2D
	if sparks:
		sparks.global_position = to
		sparks.emitting = true
	var t := create_tween()
	t.tween_property(self, "default_color:a", 0.0, 0.08)
	t.tween_interval(0.5)
	t.tween_callback(queue_free)
