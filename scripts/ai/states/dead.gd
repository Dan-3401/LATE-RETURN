extends ZombieState

func enter(_msg: Dictionary) -> void:
	zombie.nav.stop()
	zombie.play(&"death")


func physics_update(_delta: float) -> void:
	zombie.nav.stop()


func on_noise(_ev: Dictionary, _i: float) -> void:
	pass


func on_damaged(_source: Node) -> void:
	pass
