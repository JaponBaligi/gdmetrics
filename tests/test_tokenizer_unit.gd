# Unit tests for Tokenizer
# Run with: godot --headless --script tests/test_tokenizer_unit.gd

extends SceneTree

var tokenizer = null
var tests_passed = 0
var tests_failed = 0

func _init():
	var version_info = Engine.get_version_info()
	var is_godot_3 = version_info.get("major", 0) == 3
	
	if is_godot_3:
		tokenizer = load("res://src/gd3/tokenizer.gd").new()
	else:
		tokenizer = load("res://src/tokenizer.gd").new()
	
	run_all_tests()
	quit(tests_failed)

func run_all_tests():
	print("========================================")
	print("Tokenizer Unit Tests")
	print("========================================\n")
	
	test_keywords()
	test_operators()
	test_identifiers()
	test_numbers()
	test_strings()
	test_comments()
	test_annotations()
	test_malformed_input()
	test_edge_cases()
	
	print("\n========================================")
	print("Results: %d passed, %d failed" % [tests_passed, tests_failed])
	print("========================================")

func assert_true(condition: bool, message: String):
	if condition:
		tests_passed += 1
		print("PASS: %s" % message)
	else:
		tests_failed += 1
		print("FAIL: %s" % message)

func test_keywords():
	print("Testing keywords...")
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/keywords_test.gd")
	var keyword_count = 0
	for token in tokens:
		if token.type == tokenizer.TokenType.KEYWORD:
			keyword_count += 1
	assert_true(keyword_count > 0, "Keywords detected")

func test_operators():
	print("Testing operators...")
	var test_code = "x = 1 + 2 - 3 * 4 / 5"
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/operators_test.gd")
	var operator_count = 0
	for token in tokens:
		if token.type == tokenizer.TokenType.OPERATOR:
			operator_count += 1
	assert_true(operator_count > 0, "Operators detected")

func test_identifiers():
	print("Testing identifiers...")
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/identifiers_test.gd")
	var identifier_count = 0
	for token in tokens:
		if token.type == tokenizer.TokenType.IDENTIFIER:
			identifier_count += 1
	assert_true(identifier_count > 0, "Identifiers detected")

func test_numbers():
	print("Testing numbers...")
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/numbers_test.gd")
	var number_count = 0
	for token in tokens:
		if token.type == tokenizer.TokenType.NUMBER:
			number_count += 1
	assert_true(number_count > 0, "Numbers detected")

func test_strings():
	print("Testing strings...")
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/strings_test.gd")
	var string_count = 0
	for token in tokens:
		if token.type == tokenizer.TokenType.STRING:
			string_count += 1
	assert_true(string_count > 0, "Strings detected")

func test_comments():
	print("Testing comments...")
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/comments_test.gd")
	var comment_count = 0
	for token in tokens:
		if token.type == tokenizer.TokenType.COMMENT:
			comment_count += 1
	assert_true(comment_count > 0, "Comments detected")

func test_annotations():
	print("Testing annotations...")
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/annotations.gd")
	var annotation_found = false
	for token in tokens:
		if token.value == "@tool" or token.value == "@export":
			annotation_found = true
			break
	assert_true(annotation_found, "Annotations detected")

func test_malformed_input():
	print("Testing malformed input handling...")
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/malformed_syntax.gd")
	# Should not crash, may have errors
	assert_true(tokens != null, "Malformed input handled without crash")
	assert_true(tokenizer.errors.size() > 0, "Parse errors reported")

func test_edge_cases():
	print("Testing edge cases...")
	# Empty file
	var tokens = tokenizer.tokenize_file("res://tests/fixtures/empty_file.gd")
	assert_true(tokens != null, "Empty file handled")
	
	# Special characters
	tokens = tokenizer.tokenize_file("res://tests/fixtures/special_chars_test.gd")
	assert_true(tokens != null, "Special characters handled")
