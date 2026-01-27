# Plugin component verification
# Run: godot --headless --path . --script tests/verify_plugin_components.gd
# Checks plugin components for structure and API compatibility issues.

extends SceneTree

var _passed: bool = true
var _errors: Array = []
var _warnings: Array = []
var _api_differences: Array = []

func _initialize():
	var code = run_verify()
	call_deferred("quit", code)

func run_verify() -> int:
	print("=== Plugin Component Verification ===")
	print("")
	_passed = true
	_errors.clear()
	_warnings.clear()
	_api_differences.clear()
	var version_info = Engine.get_version_info()
	var is_godot_3 = version_info.get("major", 0) == 3
	print("Godot version: %s" % ("3.x" if is_godot_3 else "4.x"))
	print("")
	_check_dock_panel(is_godot_3)
	_check_config_dialog(is_godot_3)
	_check_annotation_manager(is_godot_3)
	_check_async_analyzer()
	_print_summary()
	return 0 if _passed else 1

func _check_dock_panel(is_godot_3: bool):
	print("Checking dock_panel.gd...")
	var file_helper_script = "res://tests/file_helper_3.gd" if is_godot_3 else "res://tests/file_helper_4.gd"
	var file_helper = load(file_helper_script).new()
	var path = "res://addons/gdscript_complexity/gd3/dock_panel.gd" if is_godot_3 else "res://addons/gdscript_complexity/gd4/dock_panel.gd"
	if not file_helper.file_exists(path):
		_errors.append("dock_panel.gd not found")
		_passed = false
		return
	var content = file_helper.read_file(path)
	if content.find("extends Control") < 0:
		_errors.append("dock_panel.gd does not extend Control")
		_passed = false
		return
	if content.find("@tool") < 0:
		_warnings.append("dock_panel.gd missing @tool annotation")
	if content.find("set_anchors_and_offsets_preset") >= 0:
		if is_godot_3:
			_api_differences.append("dock_panel.gd uses set_anchors_and_offsets_preset (4.x API) - should use set_anchors_and_margins_preset in 3.x")
		else:
			print("  ✓ dock_panel.gd uses correct 4.x anchor API")
	if content.find("pressed.connect") >= 0:
		if is_godot_3:
			_api_differences.append("dock_panel.gd uses pressed.connect (4.x signal syntax) - should use pressed in 3.x")
		else:
			print("  ✓ dock_panel.gd uses correct 4.x signal syntax")
	print("  ✓ dock_panel.gd structure valid")

func _check_config_dialog(is_godot_3: bool):
	print("Checking config_dialog.gd...")
	var file_helper_script = "res://tests/file_helper_3.gd" if is_godot_3 else "res://tests/file_helper_4.gd"
	var file_helper = load(file_helper_script).new()
	var path = "res://addons/gdscript_complexity/gd3/config_dialog.gd" if is_godot_3 else "res://addons/gdscript_complexity/gd4/config_dialog.gd"
	if not file_helper.file_exists(path):
		_errors.append("config_dialog.gd not found")
		_passed = false
		return
	var content = file_helper.read_file(path)
	if content.find("extends AcceptDialog") < 0:
		_errors.append("config_dialog.gd does not extend AcceptDialog")
		_passed = false
		return
	if content.find("@tool") < 0:
		_warnings.append("config_dialog.gd missing @tool annotation")
	if content.find("set_anchors_and_offsets_preset") >= 0:
		if is_godot_3:
			_api_differences.append("config_dialog.gd uses set_anchors_and_offsets_preset (4.x API) - should use set_anchors_and_margins_preset in 3.x")
		else:
			print("  ✓ config_dialog.gd uses correct 4.x anchor API")
	if content.find("add_theme_constant_override") >= 0:
		if is_godot_3:
			_api_differences.append("config_dialog.gd uses add_theme_constant_override (4.x API) - may need add_constant_override in 3.x")
		else:
			print("  ✓ config_dialog.gd uses correct 4.x theme API")
	print("  ✓ config_dialog.gd structure valid")

func _check_annotation_manager(is_godot_3: bool):
	print("Checking annotation_manager.gd...")
	var file_helper_script = "res://tests/file_helper_3.gd" if is_godot_3 else "res://tests/file_helper_4.gd"
	var file_helper = load(file_helper_script).new()
	var path = "res://addons/gdscript_complexity/gd3/annotation_manager.gd" if is_godot_3 else "res://addons/gdscript_complexity/gd4/annotation_manager.gd"
	if not file_helper.file_exists(path):
		_errors.append("annotation_manager.gd not found")
		_passed = false
		return
	var content = file_helper.read_file(path)
	if is_godot_3:
		if content.find("extends Reference") < 0:
			_errors.append("annotation_manager.gd does not extend Reference")
			_passed = false
			return
	else:
		if content.find("extends RefCounted") < 0:
			_errors.append("annotation_manager.gd does not extend RefCounted")
			_passed = false
			return
	if content.find("@tool") < 0:
		_warnings.append("annotation_manager.gd missing @tool annotation")
	if content.find("add_error_annotation") >= 0 and content.find("set_error") >= 0:
		print("  ✓ annotation_manager.gd supports both 3.x (set_error) and 4.x (add_error_annotation) APIs")
	else:
		_warnings.append("annotation_manager.gd may not support both 3.x and 4.x annotation APIs")
	print("  ✓ annotation_manager.gd structure valid")

func _check_async_analyzer():
	print("Checking async_analyzer.gd...")
	var is_godot_3 = Engine.get_version_info().get("major", 0) == 3
	var file_helper_script = "res://tests/file_helper_3.gd" if is_godot_3 else "res://tests/file_helper_4.gd"
	var file_helper = load(file_helper_script).new()
	var path = "res://addons/gdscript_complexity/gd3/async_analyzer.gd" if is_godot_3 else "res://addons/gdscript_complexity/gd4/async_analyzer.gd"
	if not file_helper.file_exists(path):
		_errors.append("async_analyzer.gd not found")
		_passed = false
		return
	var content = file_helper.read_file(path)
	if is_godot_3:
		if content.find("extends Reference") < 0:
			_errors.append("async_analyzer.gd does not extend Reference")
			_passed = false
			return
	else:
		if content.find("extends RefCounted") < 0:
			_errors.append("async_analyzer.gd does not extend RefCounted")
			_passed = false
			return
	if content.find("@tool") < 0:
		_warnings.append("async_analyzer.gd missing @tool annotation")
	if content.find("files.is_empty()") >= 0:
		if is_godot_3:
			_api_differences.append("async_analyzer.gd uses is_empty() (4.x API) - should use size() == 0 in 3.x")
		else:
			print("  ✓ async_analyzer.gd uses correct 4.x array API")
	print("  ✓ async_analyzer.gd structure valid")

func _print_summary():
	if _api_differences.size() > 0:
		print("")
		print("API Differences Detected:")
		for diff in _api_differences:
			print("  ⚠ %s" % diff)
	if _warnings.size() > 0:
		print("")
		print("Warnings:")
		for w in _warnings:
			print("  - %s" % w)
	if _errors.size() > 0:
		print("")
		print("Errors:")
		for e in _errors:
			print("  - %s" % e)
		print("")
	if _passed:
		print("")
		print("++ Plugin component verification PASSED")
		if _api_differences.size() > 0:
			print("")
			print("Note: Some API differences detected. Plugin may need manual testing")
			print("in Godot 3.5 editor to verify UI components work correctly.")
		print("")
		print("Manual testing checklist:")
		print("  1. Load plugin in Godot 3.5 editor")
		print("  2. Verify dock panel appears and UI renders correctly")
		print("  3. Test 'Analyze Project' button - should start analysis")
		print("  4. Test 'Config' button - should open configuration dialog")
		print("  5. Test 'Cancel' button during analysis")
		print("  6. Check Output panel for any errors")
		print("  7. Verify annotation system (if available in 3.x)")
	else:
		print("")
		print("xx Plugin component verification FAILED")
		print("Fix errors before testing in editor")
