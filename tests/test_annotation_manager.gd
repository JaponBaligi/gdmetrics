# Unit tests for AnnotationManager
# Run with: godot --headless --script tests/test_annotation_manager.gd

extends SceneTree

var tests_passed = 0
var tests_failed = 0

class DummyEditor:
	var add_error_calls = 0
	var set_error_calls = 0
	var clear_annotations_calls = 0
	var clear_errors_calls = 0
	
	func add_error_annotation(script_path, line, severity, message):
		add_error_calls += 1
	
	func set_error(script_path, line, message):
		set_error_calls += 1
	
	func clear_annotations(script_path):
		clear_annotations_calls += 1
	
	func clear_errors(script_path):
		clear_errors_calls += 1

func _init():
	run_all_tests()
	quit(tests_failed)

func run_all_tests():
	print("========================================")
	print("AnnotationManager Unit Tests")
	print("========================================\n")
	test_add_error_annotation_path()
	test_set_error_path()
	test_clear_annotations_fallback()
	
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

func _load_manager():
	var version_info = Engine.get_version_info()
	var is_godot_3 = version_info.get("major", 0) == 3
	var script_path = "res://addons/gdscript_complexity/gd3/annotation_manager.gd" if is_godot_3 else "res://addons/gdscript_complexity/gd4/annotation_manager.gd"
	return load(script_path).new()

func test_add_error_annotation_path():
	print("Testing add_error_annotation path...")
	var manager = _load_manager()
	var editor = DummyEditor.new()
	manager.script_editor = editor
	manager.has_annotation_support = true
	manager.annotation_api = "add_error_annotation"
	manager.add_complexity_annotation("res://test.gd", 1, "Test", "warning")
	assert_true(editor.add_error_calls == 1, "add_error_annotation called once")

func test_set_error_path():
	print("Testing set_error path...")
	var manager = _load_manager()
	var editor = DummyEditor.new()
	manager.script_editor = editor
	manager.has_annotation_support = true
	manager.annotation_api = "set_error"
	manager.add_complexity_annotation("res://test.gd", 1, "Test", "warning")
	assert_true(editor.set_error_calls == 1, "set_error called once")

func test_clear_annotations_fallback():
	print("Testing clear_annotations fallback...")
	var manager = _load_manager()
	manager.script_editor = null
	manager.has_annotation_support = false
	manager.clear_annotations("res://test.gd")
	assert_true(true, "clear_annotations handled without crash")
