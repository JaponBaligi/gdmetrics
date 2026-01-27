# File with annotations - CC: 2, C-COG: 2
# Expected: CC = 1 (base) + 1 (if) = 2
# Expected: C-COG = 2 (if at depth 1)
# Note: Annotations (@tool, @export) should be ignored for metrics

@tool
extends Node

@export var test_var: int = 0

func test_function():
	if test_var > 0:
		print("positive")
