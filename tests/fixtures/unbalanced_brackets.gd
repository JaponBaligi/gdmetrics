# Malformed syntax - unbalanced brackets
# Expected: Parse errors, should not crash

func broken_brackets():
	var items = [1, 2, 3
	print(items)
