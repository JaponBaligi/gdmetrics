# Logical operators - CC: 5, C-COG: 8
# Expected: CC = 1 (base) + 1 (if) + 1 (and) + 1 (if) + 1 (or) = 5
# Expected: C-COG = 2 (if depth 1) + 2 (and depth 1) + 2 (if depth 1) + 2 (or depth 1) = 8

func validate_input(x, y):
	if x > 0 and y > 0:
		return true
	if x < 0 or y < 0:
		return false
	return true
