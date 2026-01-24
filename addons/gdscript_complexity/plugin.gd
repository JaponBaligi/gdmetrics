@tool
extends EditorPlugin

var dock_panel: Control = null
var config_manager: ConfigManager = null
var godot_version: Dictionary = {}

func _enter_tree():
	print("[ComplexityAnalyzer] Plugin entering tree...")
	
	godot_version = Engine.get_version_info()
	print("[ComplexityAnalyzer] Godot version: %d.%d.%d" % [
		godot_version["major"], godot_version["minor"], godot_version["patch"]
	])
	
	if godot_version["major"] < 4:
		push_error("[ComplexityAnalyzer] Plugin requires Godot 4.x")
		return
	
	config_manager = preload("res://src/config_manager.gd").new()
	
	var config_path = "res://complexity_config.json"
	if not config_manager.load_config(config_path):
		if config_manager.has_errors():
			for error in config_manager.get_errors():
				print("[ComplexityAnalyzer] Config warning: %s" % error)
		print("[ComplexityAnalyzer] Using default configuration")
	
	print("[ComplexityAnalyzer] Plugin initialized successfully")

func _exit_tree():
	print("[ComplexityAnalyzer] Plugin exiting tree...")
	
	if dock_panel != null:
		remove_control_from_docks(dock_panel)
		dock_panel.queue_free()
		dock_panel = null
	
	config_manager = null
	print("[ComplexityAnalyzer] Plugin cleaned up")

func _get_plugin_name() -> String:
	return "GDScript Complexity Analyzer"

func _has_main_screen() -> bool:
	return false

func _make_visible(visible: bool):
	if dock_panel != null:
		dock_panel.visible = visible

func get_godot_version() -> Dictionary:
	return godot_version.duplicate()

func is_godot_4() -> bool:
	return godot_version["major"] == 4

func get_config_manager() -> ConfigManager:
	return config_manager

