# Deep nesting (10+ levels) - CC: 5, C-COG: 20+
# Expected: CC = 1 (base) + 1 (if) + 1 (for) + 1 (while) + 1 (if) = 5
# Expected: C-COG = 1 (if d0) + 1 (for d0) + 2 (while d1) + 3 (if d2) + ... = high value

func deeply_nested():
	if true:
		for i in range(10):
			while i > 0:
				if i % 2 == 0:
					if i > 5:
						if i < 8:
							if i == 6:
								if true:
									if false:
										if true:
											print("deep")
