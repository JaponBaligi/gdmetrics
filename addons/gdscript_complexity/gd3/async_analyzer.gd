tool
extends Reference
class_name AsyncAnalyzer

# Processes files in batches without blocking UI (Godot 3.x version)

signal progress_updated(current, total, file_path)
signal file_analyzed(file_result)
signal analysis_complete(project_result)
signal analysis_cancelled()
signal process_next_batch_requested

var batch_size: int = 10
var update_interval: float = 0.1
var cancelled: bool = false
var is_running: bool = false

var batch_analyzer: BatchAnalyzer = null
var files: Array = []
var current_index: int = 0
var project_result: BatchAnalyzer.ProjectResult = null
var config: ConfigManager.Config = null
var version_adapter: VersionAdapter = null
var plugin_node: Node = null  # Reference to plugin node for deferred calls
var logger = null
var _error_codes = null
var _tools_ready: bool = false
var _tokenizer_class = null
var _detector_instance = null
var _function_detector_instance = null
var _class_detector_instance = null
var _cc_calc_instance = null
var _cog_calc_instance = null
var _confidence_calc_instance = null

func start_analysis(root_path: String, config_data: ConfigManager.Config, adapter: VersionAdapter = null, plugin: Node = null):
	print("[AsyncAnalyzer] start_analysis called with root_path: %s" % root_path)
	
	if is_running:
		print("[AsyncAnalyzer] Already running, ignoring")
		return
	
	print("[AsyncAnalyzer] Starting analysis...")
	cancelled = false
	is_running = true
	current_index = 0
	
	config = config_data
	version_adapter = adapter
	plugin_node = plugin  # Store plugin reference for deferred calls
	_error_codes = load("res://src/error_codes.gd").new()
	_ensure_logger(config)
	
	print("[AsyncAnalyzer] Loading batch_analyzer...")
	batch_analyzer = preload("res://src/batch_analyzer.gd").new()
	if batch_analyzer == null:
		push_error("[AsyncAnalyzer] Failed to create batch_analyzer!")
		is_running = false
		return
	batch_analyzer.version_adapter = version_adapter
	batch_analyzer.logger = logger
	
	print("[AsyncAnalyzer] Loading file discovery...")
	var discovery_script = "res://src/gd3/file_discovery.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/gd4/file_discovery.gd"
	var discovery_resource = load(discovery_script)
	if discovery_resource == null:
		push_error("[AsyncAnalyzer] Failed to load discovery script: %s" % discovery_script)
		is_running = false
		return
	
	var discovery = discovery_resource.new()
	if discovery == null:
		push_error("[AsyncAnalyzer] Failed to create discovery instance")
		is_running = false
		return
	
	print("[AsyncAnalyzer] Finding files...")
	files = discovery.find_files(root_path, config.include_patterns, config.exclude_patterns)
	print("[AsyncAnalyzer] Found %d files" % files.size())
	
	if files.size() == 0:
		print("[AsyncAnalyzer] No files found, stopping")
		is_running = false
		return
	
	# In Godot 3.x, process one file at a time to prevent UI freezing
	batch_size = 1
	
	print("[AsyncAnalyzer] Creating project_result...")
	project_result = BatchAnalyzer.ProjectResult.new()
	if project_result == null:
		push_error("[AsyncAnalyzer] Failed to create project_result!")
		is_running = false
		return
	project_result.total_files = files.size()
	project_result.file_results = []
	
	# Emit signal to request processing - plugin will handle deferred call
	print("[AsyncAnalyzer] Emitting process_next_batch_requested signal")
	emit_signal("process_next_batch_requested")
	print("[AsyncAnalyzer] Signal emitted successfully")

func _process_next_batch():
	if cancelled:
		is_running = false
		emit_signal("analysis_cancelled")
		return
	
	if current_index >= files.size():
		print("[AsyncAnalyzer] Analysis complete, finalizing results")
		_finalize_results()
		is_running = false
		emit_signal("analysis_complete", project_result)
		return
	
	# Process one file at a time in Godot 3.x to prevent UI freezing
	var file_path = files[current_index]
	print("[AsyncAnalyzer] Processing file %d/%d: %s" % [current_index + 1, files.size(), file_path])
	
	if cancelled:
		is_running = false
		emit_signal("analysis_cancelled")
		return
	
	# Wrap file analysis in error handling to prevent crashes
	var file_result = null
	
	print("[AsyncAnalyzer] Calling _analyze_file_safe...")
	# Use a wrapper to catch any errors during analysis
	file_result = _analyze_file_safe(file_path)
	print("[AsyncAnalyzer] _analyze_file_safe completed")
	
	if file_result == null:
		print("[AsyncAnalyzer] ERROR: File analysis returned null for: %s" % file_path)
		# Create error result if analysis failed
		file_result = BatchAnalyzer.FileResult.new()
		file_result.file_path = file_path
		file_result.errors.append(_error_codes.format("ANALYSIS_FAILED", "Analysis failed: unexpected error"))
		file_result.success = false
	
	project_result.file_results.append(file_result)
	
	if file_result.success:
		project_result.successful_files += 1
		project_result.total_cc += file_result.cc
		project_result.total_cog += file_result.cog
	else:
		project_result.failed_files += 1
		if file_result.errors.size() > 0:
			print("[AsyncAnalyzer] File analysis failed: %s - %s" % [file_path, file_result.errors[0]])
	
	emit_signal("file_analyzed", file_result)
	current_index += 1
	print("[AsyncAnalyzer] Emitting progress_updated signal...")
	emit_signal("progress_updated", current_index, files.size(), file_path)
	
	# Emit signal to request next batch - plugin will handle deferred call
	# Always emit, even after last file, so finalization check can run
	if current_index < files.size():
		print("[AsyncAnalyzer] More files to process, emitting process_next_batch_requested")
	else:
		print("[AsyncAnalyzer] Last file processed, emitting final process_next_batch_requested for finalization")
	emit_signal("process_next_batch_requested")

func _analyze_file_safe(file_path: String) -> BatchAnalyzer.FileResult:
	# Wrapper function with error handling to prevent crashes
	var result = null
	result = _analyze_file(file_path)
	return result

func _analyze_file(file_path: String) -> BatchAnalyzer.FileResult:
	var result = BatchAnalyzer.FileResult.new()
	result.file_path = file_path
	
	# Check if file exists before processing
	if not ResourceLoader.exists(file_path):
		result.errors.append(_error_codes.format("FILE_NOT_FOUND", "File does not exist: %s" % file_path))
		result.success = false
		_log_error("FILE_NOT_FOUND", "File does not exist: %s" % file_path)
		return result
	
	# Add error handling to prevent crashes
	var tokenizer_script = "res://src/gd3/tokenizer.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/tokenizer.gd"
	var tokenizer = null
	var tokens = []
	var tokenizer_errors = []
	
	# Wrap tokenizer loading in error handling
	_ensure_tools()
	if _tokenizer_class == null:
		result.errors.append(_error_codes.format("ANALYSIS_FAILED", "Failed to load tokenizer script: %s" % tokenizer_script))
		result.success = false
		_log_error("ANALYSIS_FAILED", "Failed to load tokenizer script: %s" % tokenizer_script)
		return result
	
	tokenizer = _tokenizer_class.new()
	if tokenizer == null:
		result.errors.append(_error_codes.format("ANALYSIS_FAILED", "Failed to create tokenizer instance"))
		result.success = false
		_log_error("ANALYSIS_FAILED", "Failed to create tokenizer instance")
		return result
	
	# Try to tokenize the file
	tokens = tokenizer.tokenize_file(file_path)
	tokenizer_errors = tokenizer.get_errors()
	
	if tokenizer_errors.size() > 0:
		result.errors = tokenizer_errors
		result.success = false
		_log_error("TOKEN_PARSE_ERROR", "Tokenization failed for %s" % file_path)
		return result
	
	if tokens.size() == 0:
		result.errors.append(_error_codes.format("NO_TOKENS_FOUND", "No tokens found"))
		result.success = false
		_log_error("NO_TOKENS_FOUND", "No tokens found in %s" % file_path)
		return result
	
	# Process with detectors
	var control_flow_nodes = _detector_instance.detect_control_flow(tokens, version_adapter)
	var detector_errors = _detector_instance.get_errors()
	if detector_errors.size() > 0:
		result.errors += detector_errors
	
	var functions = _function_detector_instance.detect_functions(tokens)
	result.functions = functions
	
	var classes = _class_detector_instance.detect_classes(tokens)
	result.classes = classes
	var class_errors = _class_detector_instance.get_errors()
	if class_errors.size() > 0:
		result.errors += class_errors
	
	var cc = _cc_calc_instance.calculate_cc(control_flow_nodes)
	result.cc = cc
	result.cc_breakdown = _cc_calc_instance.get_breakdown()
	result.per_function_cc = _calculate_per_function_cc(control_flow_nodes, functions)
	
	var cog_result = _cog_calc_instance.calculate_cog(control_flow_nodes, functions)
	result.cog = cog_result.total_cog
	result.cog_breakdown = cog_result.breakdown
	result.per_function_cog = cog_result.per_function
	
	var confidence_weights = {}
	if config != null and config.parser_config.has("confidence_weights"):
		confidence_weights = config.parser_config["confidence_weights"]
	var confidence_result = _confidence_calc_instance.calculate_confidence(tokens, tokenizer_errors, version_adapter, confidence_weights)
	result.confidence = confidence_result.score
	
	result.success = true
	return result

func _calculate_per_function_cc(control_flow_nodes: Array, functions: Array) -> Dictionary:
	var per_function = {}
	if functions.size() == 0:
		return per_function
	
	for func_info in functions:
		var func_nodes: Array = []
		for node in control_flow_nodes:
			if node.line >= func_info.start_line and node.line <= func_info.end_line:
				func_nodes.append(node)
		
		var func_cc = _cc_calc_instance.calculate_cc(func_nodes)
		per_function[func_info.name] = func_cc
	
	return per_function

func _finalize_results():
	if project_result.successful_files > 0:
		project_result.average_cc = float(project_result.total_cc) / float(project_result.successful_files)
		project_result.average_cog = float(project_result.total_cog) / float(project_result.successful_files)
		
		var total_confidence = 0.0
		for file_result in project_result.file_results:
			if file_result.success:
				total_confidence += file_result.confidence
		project_result.average_confidence = total_confidence / float(project_result.successful_files)
	
	_calculate_worst_offenders()
	_set_error_summary()

func _calculate_worst_offenders():
	var cc_sorted = []
	var cog_sorted = []
	
	for result in project_result.file_results:
		if result.success:
			cc_sorted.append(result)
			cog_sorted.append(result)
	
	_sort_by_cc(cc_sorted)
	_sort_by_cog(cog_sorted)
	
	project_result.worst_cc_files = cc_sorted.slice(0, min(10, cc_sorted.size()))
	project_result.worst_cog_files = cog_sorted.slice(0, min(10, cog_sorted.size()))

func _set_error_summary():
	var helper = load("res://src/error_summary.gd").new()
	var summary = helper.summarize(project_result.file_results, project_result.errors)
	project_result.error_summary = summary.by_code
	project_result.error_severity_summary = summary.by_severity
	project_result.total_errors = summary.total

func _sort_by_cc(arr: Array):
	var n = arr.size()
	var i = 0
	while i < n:
		var best = i
		var j = i + 1
		while j < n:
			if arr[j].cc > arr[best].cc:
				best = j
			j += 1
		if best != i:
			var tmp = arr[i]
			arr[i] = arr[best]
			arr[best] = tmp
		i += 1

func _sort_by_cog(arr: Array):
	var n = arr.size()
	var i = 0
	while i < n:
		var best = i
		var j = i + 1
		while j < n:
			if arr[j].cog > arr[best].cog:
				best = j
			j += 1
		if best != i:
			var tmp = arr[i]
			arr[i] = arr[best]
			arr[best] = tmp
		i += 1

func cancel():
	cancelled = true

func is_analysis_running() -> bool:
	return is_running

func _ensure_logger(config_data):
	if logger != null:
		return
	logger = load("res://src/logger.gd").new()
	if config_data != null and config_data.logging_config != null:
		logger.configure(config_data.logging_config)

func _log_error(code: String, message: String):
	if logger == null:
		return
	logger.log_with_code("error", code, message)

func _ensure_tools():
	if _tools_ready:
		return
	var tokenizer_script = "res://src/gd3/tokenizer.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/tokenizer.gd"
	_tokenizer_class = load(tokenizer_script)
	_detector_instance = load("res://src/control_flow_detector.gd").new()
	_function_detector_instance = load("res://src/function_detector.gd").new()
	_class_detector_instance = load("res://src/class_detector.gd").new()
	_cc_calc_instance = load("res://src/cc_calculator.gd").new()
	_cog_calc_instance = load("res://src/cog_complexity_calculator.gd").new()
	_confidence_calc_instance = load("res://src/confidence_calculator.gd").new()
	_tools_ready = true
