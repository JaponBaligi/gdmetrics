# Malformed syntax - should handle gracefully
# Expected: Parse errors, but should not crash

func broken_function(
	# Missing closing paren
	if true
		print("broken")
