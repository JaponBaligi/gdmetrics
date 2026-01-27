# Match statement (Godot 4.x only) - CC: 2, C-COG: 5
# Expected: CC = 1 (base) + 1 (match) = 2
# Expected: C-COG = 2 (match depth 1) + 1 (return) + 1 (return) + 1 (return) = 5
# Note: Patterns are not counted as "case" tokens in this fixture

func handle_state(state):
	match state:
		"idle":
			return "waiting"
		"active":
			return "running"
		_:
			return "unknown"
