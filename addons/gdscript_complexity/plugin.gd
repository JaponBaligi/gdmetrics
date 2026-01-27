@tool
extends EditorPlugin

var dock_panel: Control = null
var config_manager = null  # ConfigManager - loaded dynamically
var async_analyzer = null  # AsyncAnalyzer - loaded dynamically based on version
var annotation_manager = null  # AnnotationManager - loaded dynamically based on version
var config_dialog = null  # ConfigDialog - loaded dynamically based on version
var version_adapter = null  # VersionAdapter - loaded dynamically
var godot_version: Dictionary = {}
var process_timer: Timer = null  # Timer for deferred processing in Godot 3.x
var last_project_result = null
var logger = null

func _enter_tree():
	logger = load("res://src/logger.gd").new()
	logger.log_message("info", "Plugin entering tree")
	
	godot_version = Engine.get_version_info()
	logger.log_message("info", "Godot version: %d.%d.%d" % [
		godot_version["major"], godot_version["minor"], godot_version["patch"]
	])
	
	version_adapter = load("res://addons/gdscript_complexity/version_adapter.gd").new()
	
	if not version_adapter.is_supported_version():
		logger.log_with_code("error", "ANALYSIS_FAILED", "Unsupported Godot version: %s" % version_adapter.get_version_string())
		return
	
	logger.log_message("info", "Version adapter initialized: %s" % version_adapter.get_version_string())
	
	if godot_version["major"] < 4:
		logger.log_message("info", "Running in Godot 3.x mode (best-effort support)")
	
	config_manager = load("res://src/config_manager.gd").new()
	
	var config_path = "res://complexity_config.json"
	if not config_manager.load_config(config_path):
		if config_manager.has_errors():
			for error in config_manager.get_errors():
				logger.log_message("warning", "Config warning: %s" % error)
		logger.log_message("warning", "Using default configuration")
	
	logger.configure(config_manager.get_config().logging_config)

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
	# Use Godot 4.x Callable syntax (required for 4.x parser)
	async_analyzer.connect("progress_updated", Callable(self, "_on_progress_updated"))
	async_analyzer.connect("file_analyzed", Callable(self, "_on_file_analyzed"))
	async_analyzer.connect("analysis_complete", Callable(self, "_on_analysis_complete"))
	async_analyzer.connect("analysis_cancelled", Callable(self, "_on_analysis_cancelled"))
	# Connect process_next_batch_requested signal for Godot 3.x deferred processing
	if version_adapter.is_godot_3:
		async_analyzer.connect("process_next_batch_requested", Callable(self, "_on_process_next_batch_requested"))
	
	var annotation_manager_script: String
	if is_godot_3:
		annotation_manager_script = "res://addons/gdscript_complexity/gd3/annotation_manager.gd"
	else:
		annotation_manager_script = "res://addons/gdscript_complexity/gd4/annotation_manager.gd"
	annotation_manager = load(annotation_manager_script).new(version_adapter)
	if annotation_manager.is_supported():
		logger.log_message("info", "Editor annotations supported (%s)" % annotation_manager.get_annotation_api())
	else:
		logger.log_message("info", "Editor annotations not available, using console logging")
	
	if version_adapter != null and not version_adapter.supports_editor_annotations():
		logger.log_message("info", "Editor annotations disabled for Godot 3.x")
	
	var config_dialog_script: String
	if is_godot_3:
		config_dialog_script = "res://addons/gdscript_complexity/gd3/config_dialog.gd"
	else:
		config_dialog_script = "res://addons/gdscript_complexity/gd4/config_dialog.gd"
	config_dialog = load(config_dialog_script).new()
	config_dialog.set_config_manager(config_manager)
	config_dialog.set_config_path("res://complexity_config.json")
	# Use Godot 4.x Callable syntax (required for 4.x parser)
	config_dialog.connect("config_saved", Callable(self, "_on_config_saved"))
	add_child(config_dialog)
	
	# Use Godot 4.x Callable syntax (required for 4.x parser)
	# Verify method exists before connecting (helps debug connection issues)
	if not has_method("_on_analyze_requested"):
		logger.log_with_code("error", "ANALYSIS_FAILED", "_on_analyze_requested method not found")
	else:
		var connect_result = dock_panel.connect("analyze_requested", Callable(self, "_on_analyze_requested"))
		if connect_result != OK:
			logger.log_with_code("error", "ANALYSIS_FAILED", "Failed to connect analyze_requested signal: %d" % connect_result)
		else:
			logger.log_message("info", "Successfully connected analyze_requested signal")
	
	if has_method("_on_cancel_requested"):
		dock_panel.connect("cancel_requested", Callable(self, "_on_cancel_requested"))
	else:
		logger.log_with_code("error", "ANALYSIS_FAILED", "_on_cancel_requested method not found")
	
	if has_method("_on_config_requested"):
		dock_panel.connect("config_requested", Callable(self, "_on_config_requested"))
	else:
		logger.log_with_code("error", "ANALYSIS_FAILED", "_on_config_requested method not found")
	
	if has_method("_on_export_requested"):
		dock_panel.connect("export_requested", Callable(self, "_on_export_requested"))
	else:
		logger.log_with_code("error", "ANALYSIS_FAILED", "_on_export_requested method not found")
	
	# Create timer for deferred processing in Godot 3.x
	if version_adapter.is_godot_3:
		process_timer = Timer.new()
		process_timer.wait_time = 0.01  # Process every 10ms
		process_timer.one_shot = true
		process_timer.autostart = false
		add_child(process_timer)
		# Note: This will only execute in Godot 3.x, but parser requires 4.x syntax
		process_timer.connect("timeout", Callable(self, "_process_next_batch_deferred"))
	
		logger.log_message("info", "Plugin initialized successfully")

func _exit_tree():
	if logger != null:
		logger.log_message("info", "Plugin exiting tree")
	
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
	last_project_result = null
	if logger != null:
		logger.log_message("info", "Plugin cleaned up")
	logger = null
	_unload_script_cache()
	_clear_script_caches()
	_clear_resource_cache()

func _unload_script_cache():
	var paths = [
		"res://src/batch_analyzer.gd",
		"res://src/control_flow_detector.gd",
		"res://src/function_detector.gd",
		"res://src/class_detector.gd",
		"res://src/cc_calculator.gd",
		"res://src/cog_complexity_calculator.gd",
		"res://src/confidence_calculator.gd",
		"res://src/config_manager.gd",
		"res://src/cache_manager.gd",
		"res://src/logger.gd",
		"res://src/error_codes.gd",
		"res://src/error_summary.gd",
		"res://src/gd3/file_helper.gd",
		"res://src/gd4/file_helper.gd",
		"res://src/gd3/time_helper.gd",
		"res://src/gd4/time_helper.gd",
		"res://addons/gdscript_complexity/version_adapter.gd",
		"res://addons/gdscript_complexity/gd3/async_analyzer.gd",
		"res://addons/gdscript_complexity/gd4/async_analyzer.gd",
		"res://addons/gdscript_complexity/gd3/annotation_manager.gd",
		"res://addons/gdscript_complexity/gd4/annotation_manager.gd",
		"res://addons/gdscript_complexity/gd3/dock_panel.gd",
		"res://addons/gdscript_complexity/gd4/dock_panel.gd",
		"res://addons/gdscript_complexity/gd3/config_dialog.gd",
		"res://addons/gdscript_complexity/gd4/config_dialog.gd"
	]
	for path in paths:
		_unload_cached(path)

func _unload_cached(path: String):
	if not ResourceLoader.has_method("has_cached") or not ResourceLoader.has_method("unload_cached"):
		return
	var has_cached = ResourceLoader.call("has_cached", path)
	if has_cached:
		ResourceLoader.call("unload_cached", path)

func _clear_script_caches():
	# ScriptServer is not guaranteed to be available in editor runtime.
	pass

func _clear_resource_cache():
	if ResourceLoader.has_method("clear_cache"):
		ResourceLoader.call("clear_cache")

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

func get_version_adapter():
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

func _start_analysis_deferred(project_path: String, config, adapter, plugin: Node):
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

func _on_file_analyzed(file_result):
	call_deferred("_add_file_result", file_result)

func _add_file_result(file_result):
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

func _on_analysis_complete(project_result):
	print("[Plugin] _on_analysis_complete called")
	call_deferred("_finalize_analysis", project_result)

func _finalize_analysis(project_result):
	print("[Plugin] _finalize_analysis called")
	last_project_result = project_result
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
	
	if config_manager != null:
		var config = config_manager.get_config()
		if config.report_config.get("auto_export", false):
			call_deferred("_auto_export_reports", project_result)
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
	if last_project_result == null:
		if dock_panel != null:
			dock_panel.set_status("No analysis results to export")
		return
	
	var report_gen_script = "res://src/gd3/report_generator.gd" if version_adapter.is_godot_3 else "res://src/gd4/report_generator.gd"
	var report_gen = load(report_gen_script).new()
	var config = config_manager.get_config()
	var ok = false
	var output_path = ""
	
	if format == "json":
		var report = report_gen.generate_report(last_project_result, config)
		output_path = config.report_config["output_path"]
		ok = report_gen.write_report(report, output_path)
	elif format == "csv":
		var csv_text = report_gen.generate_csv(last_project_result, config)
		output_path = config.report_config.get("csv_output_path", "res://complexity_report.csv")
		ok = report_gen.write_csv(csv_text, output_path)
	else:
		if dock_panel != null:
			dock_panel.set_status("Unsupported export format: %s" % format)
		return
	
	if dock_panel != null:
		if ok:
			dock_panel.set_status("Exported %s to %s" % [format.to_upper(), output_path])
		else:
			dock_panel.set_status("Failed to export %s" % format.to_upper())

func _auto_export_reports(project_result):
	if project_result == null or config_manager == null:
		return
	var report_gen_script = "res://src/gd3/report_generator.gd" if version_adapter.is_godot_3 else "res://src/gd4/report_generator.gd"
	var report_gen = load(report_gen_script).new()
	var config = config_manager.get_config()
	var formats = config.report_config.get("formats", ["json"])
	var failed = false
	
	if formats.has("json"):
		var report = report_gen.generate_report(project_result, config)
		var json_output = config.report_config["output_path"]
		if not report_gen.write_report(report, json_output):
			failed = true
	
	if formats.has("csv"):
		var csv_text = report_gen.generate_csv(project_result, config)
		var csv_output = config.report_config.get("csv_output_path", "res://complexity_report.csv")
		if not report_gen.write_csv(csv_text, csv_output):
			failed = true
	
	if dock_panel != null:
		if failed:
			dock_panel.set_status("Auto export failed")
		else:
			dock_panel.set_status("Auto export complete")

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

