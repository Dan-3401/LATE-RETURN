class_name Sister
extends Node2D
## The sister: sits on her bedroll. Animation driven by the ending script.

@onready var sprite: AnimatedSprite2D = $Sprite


func play(anim: StringName) -> void:
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


func get_speech_anchor() -> Vector2:
	return global_position + Vector2(0, -40)


## One-shot cough, then back to `after`.
func cough(after: StringName = &"sit_down") -> void:
	sprite.play(&"cough")
	AudioManager.play_at(&"cough", global_position + Vector2(0, -30), -6.0)
	await sprite.animation_finished
	if is_inside_tree():
		sprite.play(&"cough")
		await sprite.animation_finished
		if is_inside_tree():
			sprite.play(after)
