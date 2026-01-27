# Single for loop - CC: 2, C-COG: 2
# Expected: CC = 1 (base) + 1 (for) = 2
# Expected: C-COG = 2 (for at depth 1)

func sum_array(arr):
	var total = 0
	for item in arr:
		total += item
	return total
