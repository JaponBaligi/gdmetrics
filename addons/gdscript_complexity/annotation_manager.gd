@tool
extends RefCounted
class_name AnnotationManager

# Adds complexity warnings to script editor
# Supports both Godot 3.x (set_error) and 4.x (add_error_annotation) APIs

var script_editor: Object = null
var has_annotation_support: bool = false
var annotation_api: String = "none"  # "set_error" (3.x) or "add_error_annotation" (4.x) or "none"
var version_adapter: VersionAdapter = null

func _init(adapter: VersionAdapter = null):
	version_adapter = adapter
	_detect_annotation_support()

func _detect_annotation_support():
	if not Engine.is_editor_hint():
		has_annotation_support = false
		annotation_api = "none"
		return
	
	var editor_interface = EditorInterface.get_singleton()
	if editor_interface == null:
		has_annotation_support = false
		annotation_api = "none"
		return
	
	script_editor = editor_interface.get_script_editor()
	if script_editor == null:
		has_annotation_support = false
		annotation_api = "none"
		return
	
	# Try Godot 4.x API first
	if script_editor.has_method("add_error_annotation"):
		has_annotation_support = true
		annotation_api = "add_error_annotation"
		return
	
	# Try Godot 3.x API
	if script_editor.has_method("set_error"):
		has_annotation_support = true
		annotation_api = "set_error"
		return
	
	# No annotation support
	has_annotation_support = false
	annotation_api = "none"
	print("[ComplexityAnalyzer] No annotation API available (neither add_error_annotation nor set_error)")

func add_complexity_annotation(script_path: String, line: int, message: String, severity: String = "warning"):
	if not has_annotation_support:
		_fallback_log(script_path, line, message, severity)
		return
	
	if script_editor == null:
		_fallback_log(script_path, line, message, severity)
		return
	
	if annotation_api == "add_error_annotation":
		_add_error_annotation_4x(script_path, line, message, severity)
	elif annotation_api == "set_error":
		_set_error_3x(script_path, line, message, severity)
	else:
		_fallback_log(script_path, line, message, severity)

func _add_error_annotation_4x(script_path: String, line: int, message: String, severity: String):
	if not script_editor.has_method("add_error_annotation"):
		_fallback_log(script_path, line, message, severity)
		return
	
	var severity_enum = 0
	if severity == "error":
		severity_enum = 0
	elif severity == "warning":
		severity_enum = 1
	else:
		severity_enum = 2
	
	script_editor.add_error_annotation(script_path, line, severity_enum, message)

func _set_error_3x(script_path: String, line: int, message: String, severity: String):
	if not script_editor.has_method("set_error"):
		_fallback_log(script_path, line, message, severity)
		return
	
	# Godot 3.x set_error signature: set_error(script, line, message)
	# Note: Godot 3.x doesn't have severity levels, so we prepend it to the message
	var full_message = "[%s] %s" % [severity.to_upper(), message]
	script_editor.set_error(script_path, line, full_message)

func add_cc_warning(script_path: String, line: int, cc_value: int, threshold: int):
	var message = "High Cyclomatic Complexity: %d (threshold: %d)" % [cc_value, threshold]
	add_complexity_annotation(script_path, line, message, "warning")

func add_cog_warning(script_path: String, line: int, cog_value: int, threshold: int):
	var message = "High Cognitive Complexity: %d (threshold: %d)" % [cog_value, threshold]
	add_complexity_annotation(script_path, line, message, "warning")

func annotate_file_results(file_result: BatchAnalyzer.FileResult, cc_threshold: int, cog_threshold: int):
	if not file_result.success:
		return
	
	var script_path = file_result.file_path
	
	if file_result.cc > cc_threshold:
		add_cc_warning(script_path, 1, file_result.cc, cc_threshold)
	
	if file_result.cog > cog_threshold:
		add_cog_warning(script_path, 1, file_result.cog, cog_threshold)
	
	for func_info in file_result.functions:
		if file_result.per_function_cog.has(func_info.name):
			var cog = file_result.per_function_cog[func_info.name]
			if cog > cog_threshold:
				add_cog_warning(script_path, func_info.start_line, cog, cog_threshold)

func clear_annotations(script_path: String):
	if not has_annotation_support or script_editor == null:
		return
	
	if annotation_api == "add_error_annotation" and script_editor.has_method("clear_annotations"):
		script_editor.clear_annotations(script_path)
	elif annotation_api == "set_error" and script_editor.has_method("clear_errors"):
		script_editor.clear_errors(script_path)

func _fallback_log(script_path: String, line: int, message: String, severity: String):
	var log_message = "[ComplexityAnalyzer] %s:%d - %s: %s" % [script_path, line, severity.to_upper(), message]
	if severity == "error":
		push_error(log_message)
	else:
		print(log_message)

func is_supported() -> bool:
	return has_annotation_support

func get_annotation_api() -> String:
	return annotation_api

