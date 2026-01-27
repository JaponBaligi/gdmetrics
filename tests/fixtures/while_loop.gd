# Single while loop - CC: 2, C-COG: 2
# Expected: CC = 1 (base) + 1 (while) = 2
# Expected: C-COG = 2 (while at depth 1)

func countdown(n):
	var count = n
	while count > 0:
		print(count)
		count -= 1
