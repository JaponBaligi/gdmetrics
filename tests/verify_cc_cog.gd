# Verification script for CC/C-COG values against fixtures
# Run with: godot --headless --script tests/verify_cc_cog.gd

extends SceneTree

var batch_analyzer = null
var config_manager = null
var version_adapter = null
var tests_passed = 0
var tests_failed = 0

# Expected values from fixtures
var expected_values = {
	"simple_function.gd": {"cc": 1, "cog": 0},
	"if_statement.gd": {"cc": 2, "cog": 3},
	"if_elif_else.gd": {"cc": 3, "cog": 6},
	"for_loop.gd": {"cc": 2, "cog": 2},
	"while_loop.gd": {"cc": 2, "cog": 2},
	"nested_control_flow.gd": {"cc": 4, "cog": 9},
	"match_statement.gd": {"cc": 2, "cog": 5},
	"logical_operators.gd": {"cc": 5, "cog": 8},
	"class_with_inheritance.gd": {"cc": 2, "cog": 2},
	"empty_file.gd": {"cc": 1, "cog": 0},
	"with_yield.gd": {"cc": 2, "cog": 2},
	"no_match.gd": {"cc": 3, "cog": 6},
	"annotations.gd": {"cc": 2, "cog": 2}
}

func _init():
	batch_analyzer = load("res://src/batch_analyzer.gd").new()
	config_manager = load("res://src/config_manager.gd").new()
	version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	
	run_verification()
	quit(tests_failed)

func run_verification():
	print("========================================")
	print("CC/C-COG Verification Against Fixtures")
	print("========================================\n")
	
	var config = config_manager.get_config()
	config.include_patterns = ["res://**/*.gd"]
	config.exclude_patterns = []
	
	var project_result = batch_analyzer.analyze_project("res://tests/fixtures", config, version_adapter)
	
	print("Files analyzed: %d" % project_result.total_files)
	print("\nVerifying values...\n")
	
	for file_result in project_result.file_results:
		var filename = file_result.file_path.get_file()
		if version_adapter.is_godot_3 and filename == "match_statement.gd":
			print("SKIP: %s (match not supported in Godot 3.x)" % filename)
			continue
		if expected_values.has(filename):
			var expected = expected_values[filename]
			var actual_cc = file_result.cc
			var actual_cog = file_result.cog
			
			var cc_match = actual_cc == expected["cc"]
			var cog_match = actual_cog == expected["cog"]
			
			if cc_match and cog_match:
				tests_passed += 1
				print("PASS: %s (CC: %d, C-COG: %d)" % [filename, actual_cc, actual_cog])
			else:
				tests_failed += 1
				var issues = []
				if not cc_match:
					issues.append("CC: expected %d, got %d" % [expected["cc"], actual_cc])
				if not cog_match:
					issues.append("C-COG: expected %d, got %d" % [expected["cog"], actual_cog])
				print("FAIL: %s (%s)" % [filename, ", ".join(issues)])
		else:
			print("SKIP: %s (no expected values)" % filename)
	
	# Check confidence cap for Godot 3.x
	if version_adapter.is_godot_3:
		print("\nChecking Godot 3.x confidence cap...")
		for file_result in project_result.file_results:
			if file_result.confidence > 0.90:
				tests_failed += 1
				print("FAIL: %s confidence (%f) exceeds 0.90 cap" % [file_result.file_path.get_file(), file_result.confidence])
			else:
				tests_passed += 1
				print("PASS: %s confidence (%f) <= 0.90" % [file_result.file_path.get_file(), file_result.confidence])
	
	print("\n========================================")
	print("Results: %d passed, %d failed" % [tests_passed, tests_failed])
	print("========================================")
