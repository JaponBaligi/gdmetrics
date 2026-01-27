# Single if statement - CC: 2, C-COG: 3
# Expected: CC = 1 (base) + 1 (if) = 2
# Expected: C-COG = 2 (if at depth 1) + 1 (return)

func check_value(x):
	if x > 0:
		return true
	return false
