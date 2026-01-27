# Nested control flow - CC: 4, C-COG: 9
# Expected: CC = 1 (base) + 1 (if) + 1 (for) + 1 (if inside for) = 4
# Expected: C-COG = 2 (if depth 1) + 3 (for depth 2) + 4 (if depth 3) = 9

func process_items(items):
	if items.size() > 0:
		for item in items:
			if item.valid:
				process(item)
