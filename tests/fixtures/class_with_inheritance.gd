# Class with inheritance - CC: 2, C-COG: 2
# Expected: CC = 1 (base) + 1 (if) = 2
# Expected: C-COG = 2 (if at depth 1)

class_name TestClass
extends Node

func _ready():
	if true:
		print("ready")
