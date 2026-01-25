extends Object
class_name VersionAdapter

# Handles version detection and feature flags

var godot_version: Dictionary = {}
var is_godot_3: bool = false
var is_godot_4: bool = false
var major_version: int = 0
var minor_version: int = 0

var features: Dictionary = {}

func _init():
	godot_version = Engine.get_version_info()
	major_version = godot_version.get("major", 0)
	minor_version = godot_version.get("minor", 0)
	
	is_godot_3 = (major_version == 3)
	is_godot_4 = (major_version == 4)
	
	_detect_features()

func _detect_features():
	features = {
		"match_statement": is_godot_4,
		"await_keyword": is_godot_4,
		"yield_keyword": is_godot_3,
		"class_name_declaration": true,
		"extends_declaration": true,
		"static_func": true,
		"signal": true,
		"editor_annotations": is_godot_4,
		"script_editor_api": is_godot_4,
		"confidence_cap_3x": is_godot_3,
		"confidence_cap_4x": is_godot_4
	}

func get_version_string() -> String:
	return "%d.%d.%d" % [major_version, minor_version, godot_version.get("patch", 0)]

func supports_match_statements() -> bool:
	return features.get("match_statement", false)

func supports_await() -> bool:
	return features.get("await_keyword", false)

func supports_yield() -> bool:
	return features.get("yield_keyword", false)

func supports_editor_annotations() -> bool:
	return features.get("editor_annotations", false)

func get_confidence_cap() -> float:
	if is_godot_3:
		return 0.90
	return 1.0

func get_parser_mode() -> String:
	if is_godot_3:
		return "heuristic"
	return "balanced"

func should_skip_match() -> bool:
	return not supports_match_statements()

func get_annotation_api() -> String:
	if is_godot_4:
		return "add_error_annotation"
	elif is_godot_3:
		return "set_error"
	return "none"

func is_supported_version() -> bool:
	return is_godot_3 or is_godot_4

func get_version_info() -> Dictionary:
	return {
		"major": major_version,
		"minor": minor_version,
		"patch": godot_version.get("patch", 0),
		"is_3x": is_godot_3,
		"is_4x": is_godot_4,
		"supported": is_supported_version(),
		"features": features.duplicate()
	}

