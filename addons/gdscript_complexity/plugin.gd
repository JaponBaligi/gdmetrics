@tool
extends EditorPlugin

var dock_panel: Control = null
var config_manager: ConfigManager = null
var async_analyzer: AsyncAnalyzer = null
var annotation_manager: AnnotationManager = null
var config_dialog: ConfigDialog = null
var version_adapter: VersionAdapter = null
var godot_version: Dictionary = {}

func _enter_tree():
	print("[ComplexityAnalyzer] Plugin entering tree...")
	
	godot_version = Engine.get_version_info()
	print("[ComplexityAnalyzer] Godot version: %d.%d.%d" % [
		godot_version["major"], godot_version["minor"], godot_version["patch"]
	])
	
	version_adapter = preload("res://addons/gdscript_complexity/version_adapter.gd").new()
	
	if not version_adapter.is_supported_version():
		push_error("[ComplexityAnalyzer] Unsupported Godot version: %s" % version_adapter.get_version_string())
		return
	
	print("[ComplexityAnalyzer] Version adapter initialized: %s" % version_adapter.get_version_string())
	
	if godot_version["major"] < 4:
		print("[ComplexityAnalyzer] Running in Godot 3.x mode (best-effort support)")
	
	config_manager = preload("res://src/config_manager.gd").new()
	
	var config_path = "res://complexity_config.json"
	if not config_manager.load_config(config_path):
		if config_manager.has_errors():
			for error in config_manager.get_errors():
				print("[ComplexityAnalyzer] Config warning: %s" % error)
		print("[ComplexityAnalyzer] Using default configuration")

	dock_panel = preload("res://addons/gdscript_complexity/dock_panel.gd").new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock_panel)
	
	async_analyzer = preload("res://addons/gdscript_complexity/async_analyzer.gd").new()
	async_analyzer.batch_size = 10
	async_analyzer.progress_updated.connect(_on_progress_updated)
	async_analyzer.file_analyzed.connect(_on_file_analyzed)
	async_analyzer.analysis_complete.connect(_on_analysis_complete)
	async_analyzer.analysis_cancelled.connect(_on_analysis_cancelled)
	
	annotation_manager = preload("res://addons/gdscript_complexity/annotation_manager.gd").new()
	if annotation_manager.is_supported():
		print("[ComplexityAnalyzer] Editor annotations supported")
	else:
		print("[ComplexityAnalyzer] Editor annotations not available, using console logging")
	
	if version_adapter != null and not version_adapter.supports_editor_annotations():
		print("[ComplexityAnalyzer] Editor annotations disabled for Godot 3.x")
	
	config_dialog = preload("res://addons/gdscript_complexity/config_dialog.gd").new()
	config_dialog.set_config_manager(config_manager)
	config_dialog.set_config_path("res://complexity_config.json")
	config_dialog.config_saved.connect(_on_config_saved)
	add_child(config_dialog)
	
	dock_panel.analyze_requested.connect(_on_analyze_requested)
	dock_panel.cancel_requested.connect(_on_cancel_requested)
	dock_panel.config_requested.connect(_on_config_requested)
	dock_panel.export_requested.connect(_on_export_requested)
	
	print("[ComplexityAnalyzer] Plugin initialized successfully")

func _exit_tree():
	print("[ComplexityAnalyzer] Plugin exiting tree...")
	
	if async_analyzer != null and async_analyzer.is_analysis_running():
		async_analyzer.cancel()
	
	if dock_panel != null:
		remove_control_from_docks(dock_panel)
		dock_panel.queue_free()
		dock_panel = null
	
	if config_dialog != null:
		config_dialog.queue_free()
		config_dialog = null
	
	async_analyzer = null
	annotation_manager = null
	version_adapter = null
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

func get_version_adapter() -> VersionAdapter:
	return version_adapter

func _on_analyze_requested():
	if async_analyzer == null or async_analyzer.is_analysis_running():
		return
	
	var project_path = "res://"
	dock_panel.clear_results()
	dock_panel.set_status("Starting analysis...")
	dock_panel.set_analyze_button_enabled(false)
	dock_panel.set_cancel_button_enabled(true)
	dock_panel.show_progress(true)
	
	async_analyzer.start_analysis(project_path, config_manager.get_config(), version_adapter)

func _on_progress_updated(current: int, total: int, file_path: String):
	call_deferred("_update_progress", current, total, file_path)

func _update_progress(current: int, total: int, file_path: String):
	if dock_panel != null:
		dock_panel.set_progress(current, total)
		dock_panel.set_status("Analyzing: %s (%d/%d)" % [file_path.get_file(), current, total])

func _on_file_analyzed(file_result: BatchAnalyzer.FileResult):
	call_deferred("_add_file_result", file_result)

func _add_file_result(file_result: BatchAnalyzer.FileResult):
	if dock_panel == null or not file_result.success:
		return
	
	var file_item = dock_panel.add_file_result(
		file_result.file_path,
		file_result.cc,
		file_result.cog,
		file_result.confidence
	)
	
	if file_item != null and file_result.per_function_cog.size() > 0:
		for func_info in file_result.functions:
			if file_result.per_function_cog.has(func_info.name):
				var cog = file_result.per_function_cog[func_info.name]
				dock_panel.add_function_result(file_item, func_info.name, 0, cog)
	
	if annotation_manager != null and config_manager != null:
		var config = config_manager.get_config()
		var cc_threshold = config.cc_config["threshold_warn"]
		var cog_threshold = config.cog_config["threshold_warn"]
		annotation_manager.annotate_file_results(file_result, cc_threshold, cog_threshold)

func _on_analysis_complete(project_result: BatchAnalyzer.ProjectResult):
	call_deferred("_finalize_analysis", project_result)

func _finalize_analysis(project_result: BatchAnalyzer.ProjectResult):
	if dock_panel != null:
		dock_panel.set_status("Analysis complete: %d files, CC: %d, C-COG: %d" % [
			project_result.successful_files,
			project_result.total_cc,
			project_result.total_cog
		])
		dock_panel.set_progress(project_result.total_files, project_result.total_files)
		dock_panel.show_progress(false)
		dock_panel.set_analyze_button_enabled(true)
		dock_panel.set_cancel_button_enabled(false)

func _on_analysis_cancelled():
	call_deferred("_handle_cancellation")

func _handle_cancellation():
	if dock_panel != null:
		dock_panel.set_status("Analysis cancelled")
		dock_panel.show_progress(false)
		dock_panel.set_analyze_button_enabled(true)
		dock_panel.set_cancel_button_enabled(false)

func _on_cancel_requested():
	if async_analyzer != null and async_analyzer.is_analysis_running():
		async_analyzer.cancel()

func _on_config_requested():
	if config_dialog != null:
		config_dialog.popup_centered()

func _on_config_saved():
	print("[ComplexityAnalyzer] Configuration saved")
	if config_manager != null:
		var config_path = "res://complexity_config.json"
		config_manager.load_config(config_path)

func _on_export_requested(format: String):
	print("[ComplexityAnalyzer] Export requested: %s (not implemented yet)" % format)

