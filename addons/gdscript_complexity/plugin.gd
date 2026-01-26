tool
extends EditorPlugin

var dock_panel: Control = null
var config_manager: ConfigManager = null
var async_analyzer: AsyncAnalyzer = null
var annotation_manager: AnnotationManager = null
var config_dialog: ConfigDialog = null
var version_adapter: VersionAdapter = null
var godot_version: Dictionary = {}
var process_timer: Timer = null  # Timer for deferred processing in Godot 3.x

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

	var is_godot_3 = godot_version["major"] == 3
	var dock_panel_script: String
	if is_godot_3:
		dock_panel_script = "res://addons/gdscript_complexity/gd3/dock_panel.gd"
	else:
		dock_panel_script = "res://addons/gdscript_complexity/gd4/dock_panel.gd"
	dock_panel = load(dock_panel_script).new()
	add_control_to_dock(DOCK_SLOT_LEFT_UL, dock_panel)
	
	var async_analyzer_script: String
	if is_godot_3:
		async_analyzer_script = "res://addons/gdscript_complexity/gd3/async_analyzer.gd"
	else:
		async_analyzer_script = "res://addons/gdscript_complexity/gd4/async_analyzer.gd"
	async_analyzer = load(async_analyzer_script).new()
	async_analyzer.batch_size = 10
	# Use connect() syntax compatible with both 3.x and 4.x
	async_analyzer.connect("progress_updated", self, "_on_progress_updated")
	async_analyzer.connect("file_analyzed", self, "_on_file_analyzed")
	async_analyzer.connect("analysis_complete", self, "_on_analysis_complete")
	async_analyzer.connect("analysis_cancelled", self, "_on_analysis_cancelled")
	# Connect process_next_batch_requested signal for Godot 3.x deferred processing
	if is_godot_3:
		async_analyzer.connect("process_next_batch_requested", self, "_on_process_next_batch_requested")
	
	var annotation_manager_script: String
	if is_godot_3:
		annotation_manager_script = "res://addons/gdscript_complexity/gd3/annotation_manager.gd"
	else:
		annotation_manager_script = "res://addons/gdscript_complexity/gd4/annotation_manager.gd"
	annotation_manager = load(annotation_manager_script).new(version_adapter)
	if annotation_manager.is_supported():
		print("[ComplexityAnalyzer] Editor annotations supported (%s)" % annotation_manager.get_annotation_api())
	else:
		print("[ComplexityAnalyzer] Editor annotations not available, using console logging")
	
	if version_adapter != null and not version_adapter.supports_editor_annotations():
		print("[ComplexityAnalyzer] Editor annotations disabled for Godot 3.x")
	
	var config_dialog_script: String
	if is_godot_3:
		config_dialog_script = "res://addons/gdscript_complexity/gd3/config_dialog.gd"
	else:
		config_dialog_script = "res://addons/gdscript_complexity/gd4/config_dialog.gd"
	config_dialog = load(config_dialog_script).new()
	config_dialog.set_config_manager(config_manager)
	config_dialog.set_config_path("res://complexity_config.json")
	# Use connect() syntax compatible with both 3.x and 4.x
	config_dialog.connect("config_saved", self, "_on_config_saved")
	add_child(config_dialog)
	
	# Use connect() syntax compatible with both 3.x and 4.x
	# Verify method exists before connecting (helps debug connection issues)
	if not has_method("_on_analyze_requested"):
		push_error("[ComplexityAnalyzer] ERROR: _on_analyze_requested method not found!")
	else:
		var connect_result = dock_panel.connect("analyze_requested", self, "_on_analyze_requested")
		if connect_result != OK:
			push_error("[ComplexityAnalyzer] Failed to connect analyze_requested signal: %d" % connect_result)
		else:
			print("[ComplexityAnalyzer] Successfully connected analyze_requested signal")
	
	if has_method("_on_cancel_requested"):
		dock_panel.connect("cancel_requested", self, "_on_cancel_requested")
	else:
		push_error("[ComplexityAnalyzer] ERROR: _on_cancel_requested method not found!")
	
	if has_method("_on_config_requested"):
		dock_panel.connect("config_requested", self, "_on_config_requested")
	else:
		push_error("[ComplexityAnalyzer] ERROR: _on_config_requested method not found!")
	
	if has_method("_on_export_requested"):
		dock_panel.connect("export_requested", self, "_on_export_requested")
	else:
		push_error("[ComplexityAnalyzer] ERROR: _on_export_requested method not found!")
	
	# Create timer for deferred processing in Godot 3.x
	if is_godot_3:
		process_timer = Timer.new()
		process_timer.wait_time = 0.01  # Process every 10ms
		process_timer.one_shot = true
		process_timer.autostart = false
		add_child(process_timer)
		process_timer.connect("timeout", self, "_process_next_batch_deferred")
	
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
	
	if process_timer != null:
		process_timer.queue_free()
		process_timer = null
	
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
	print("[Plugin] _on_analyze_requested called")
	
	# Wrap everything in defensive checks
	if async_analyzer == null:
		push_error("[Plugin] ERROR: async_analyzer is null!")
		return
	
	if async_analyzer.is_analysis_running():
		print("[Plugin] Analysis already running, ignoring request")
		return
	
	print("[Plugin] Starting analysis...")
	
	var project_path = "res://"
	
	if dock_panel == null:
		push_error("[Plugin] ERROR: dock_panel is null!")
		return
	
	# Update UI first (safely)
	dock_panel.clear_results()
	dock_panel.set_status("Starting analysis...")
	dock_panel.set_analyze_button_enabled(false)
	dock_panel.set_cancel_button_enabled(true)
	dock_panel.show_progress(true)
	
	if config_manager == null:
		push_error("[Plugin] ERROR: config_manager is null!")
		return
	
	if version_adapter == null:
		push_error("[Plugin] ERROR: version_adapter is null!")
		return
	
	var config = config_manager.get_config()
	if config == null:
		push_error("[Plugin] ERROR: config is null!")
		return
	
	print("[Plugin] Calling async_analyzer.start_analysis...")
	
	# Use call_deferred to start analysis on next frame to prevent immediate crash
	var is_godot_3 = godot_version["major"] == 3
	if is_godot_3:
		print("[Plugin] Using Godot 3.x path with plugin reference (deferred)")
		call_deferred("_start_analysis_deferred", project_path, config, version_adapter, self)
	else:
		print("[Plugin] Using Godot 4.x path (deferred)")
		call_deferred("_start_analysis_deferred", project_path, config, version_adapter, null)
	
	print("[Plugin] Deferred call scheduled")

func _start_analysis_deferred(project_path: String, config: ConfigManager.Config, adapter: VersionAdapter, plugin: Node):
	print("[Plugin] _start_analysis_deferred called")
	
	if async_analyzer == null:
		push_error("[Plugin] ERROR: async_analyzer is null in deferred call!")
		return
	
	var is_godot_3 = godot_version["major"] == 3
	if is_godot_3:
		print("[Plugin] Calling start_analysis with plugin reference")
		async_analyzer.start_analysis(project_path, config, adapter, plugin)
	else:
		print("[Plugin] Calling start_analysis without plugin reference")
		async_analyzer.start_analysis(project_path, config, adapter)
	
	print("[Plugin] start_analysis call completed")

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
	print("[Plugin] _on_analysis_complete called")
	call_deferred("_finalize_analysis", project_result)

func _finalize_analysis(project_result: BatchAnalyzer.ProjectResult):
	print("[Plugin] _finalize_analysis called")
	if dock_panel != null:
		var status_msg = "Analysis complete: %d files, CC: %d, C-COG: %d" % [
			project_result.successful_files,
			project_result.total_cc,
			project_result.total_cog
		]
		print("[Plugin] Setting status: %s" % status_msg)
		dock_panel.set_status(status_msg)
		dock_panel.set_progress(project_result.total_files, project_result.total_files)
		dock_panel.show_progress(false)
		dock_panel.set_analyze_button_enabled(true)
		dock_panel.set_cancel_button_enabled(false)
		print("[Plugin] Analysis finalized successfully")
	else:
		push_error("[Plugin] ERROR: dock_panel is null in _finalize_analysis!")

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

func _on_process_next_batch_requested():
	# Handle deferred processing for Godot 3.x using Timer
	# This is more reliable than call_deferred for Reference classes
	print("[Plugin] _on_process_next_batch_requested received")
	
	if async_analyzer == null:
		push_error("[Plugin] ERROR: async_analyzer is null in _on_process_next_batch_requested!")
		return
	
	if not async_analyzer.is_analysis_running():
		print("[Plugin] WARNING: Analyzer not running, ignoring request")
		return
	
	if process_timer != null:
		print("[Plugin] Starting timer for deferred processing")
		process_timer.start()
	else:
		print("[Plugin] WARNING: process_timer is null, using call_deferred fallback")
		# Fallback to call_deferred if timer not available
		call_deferred("_process_next_batch_deferred")

func _process_next_batch_deferred():
	print("[Plugin] _process_next_batch_deferred called")
	
	if async_analyzer == null:
		push_error("[Plugin] ERROR: async_analyzer is null in _process_next_batch_deferred!")
		return
	
	if async_analyzer.is_analysis_running():
		print("[Plugin] Calling async_analyzer._process_next_batch()")
		async_analyzer._process_next_batch()
		print("[Plugin] _process_next_batch call completed")
	else:
		print("[Plugin] WARNING: Analyzer not running in _process_next_batch_deferred")

