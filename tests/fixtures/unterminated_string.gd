# Malformed syntax - unterminated string
# Expected: Parse errors, should not crash

func broken_string():
	var name = "unterminated
	print(name)
