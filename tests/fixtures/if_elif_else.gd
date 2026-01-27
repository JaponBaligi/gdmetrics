# if/elif/else chain - CC: 3, C-COG: 6
# Expected: CC = 1 (base) + 1 (if) + 1 (elif) = 3
# Expected: C-COG = 2 (if depth 1) + 2 (elif depth 1) + 1 (return) + 1 (return) = 6

func categorize(value):
	if value < 0:
		return "negative"
	elif value == 0:
		return "zero"
	else:
		return "positive"
