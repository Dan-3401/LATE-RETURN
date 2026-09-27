extends ZombieState
## Continue a patrol leg after a mid-way stop (keeps the same destination).

func enter(_msg: Dictionary) -> void:
	var p: ZombieState = machine.states[&"Patrol"]
	machine.transition_to(&"Patrol", {"x": p.get("_x")})
