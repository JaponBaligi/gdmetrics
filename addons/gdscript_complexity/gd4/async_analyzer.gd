@tool
extends RefCounted
# class_name AsyncAnalyzer  # Commented out to avoid parse-time cascade

# Processes files in batches without blocking UI

signal progress_updated(current: int, total: int, file_path: String)
signal file_analyzed(file_result)  # BatchAnalyzer.FileResult - loaded dynamically
signal analysis_complete(project_result)  # BatchAnalyzer.ProjectResult - loaded dynamically
signal analysis_cancelled()

var batch_size: int = 10
var update_interval: float = 0.1
var cancelled: bool = false
var is_running: bool = false

var batch_analyzer = null  # BatchAnalyzer - loaded dynamically
var files: Array = []
var current_index: int = 0
var project_result = null  # BatchAnalyzer.ProjectResult - loaded dynamically
var config = null  # ConfigManager.Config - loaded dynamically
var version_adapter = null  # VersionAdapter - loaded dynamically
var logger = null
var _error_codes = null

func start_analysis(root_path: String, config_data, adapter = null):  # ConfigManager.Config, VersionAdapter - loaded dynamically
	if is_running:
		return
	
	cancelled = false
	is_running = true
	current_index = 0
	
	config = config_data
	version_adapter = adapter
	_error_codes = load("res://src/error_codes.gd").new()
	_ensure_logger(config)
	batch_analyzer = load("res://src/batch_analyzer.gd").new()
	batch_analyzer.version_adapter = version_adapter
	batch_analyzer.logger = logger
	
	var discovery_script = "res://src/gd3/file_discovery.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/gd4/file_discovery.gd"
	var discovery = load(discovery_script).new()
	files = discovery.find_files(root_path, config.include_patterns, config.exclude_patterns)
	
	if files.size() == 0:
		is_running = false
		return
	
	# Create ProjectResult using helper method
	var batch_script = load("res://src/batch_analyzer.gd")
	project_result = batch_script.create_project_result()
	project_result.total_files = files.size()
	project_result.file_results = []
	
	_process_next_batch()

func _process_next_batch():
	if cancelled:
		is_running = false
		analysis_cancelled.emit()
		return
	
	var batch_end = min(current_index + batch_size, files.size())
	var batch_files = files.slice(current_index, batch_end)
	
	for file_path in batch_files:
		if cancelled:
			break
		
		var file_result = _analyze_file(file_path)
		project_result.file_results.append(file_result)
		
		if file_result.success:
			project_result.successful_files += 1
			project_result.total_cc += file_result.cc
			project_result.total_cog += file_result.cog
		else:
			project_result.failed_files += 1
		
		file_analyzed.emit(file_result)
		current_index += 1
		
		progress_updated.emit(current_index, files.size(), file_path)
	
	if current_index >= files.size():
		_finalize_results()
		is_running = false
		analysis_complete.emit(project_result)
	else:
		call_deferred("_process_next_batch")

func _analyze_file(file_path: String):  # -> BatchAnalyzer.FileResult - loaded dynamically
	# Create FileResult using helper method
	var batch_script = load("res://src/batch_analyzer.gd")
	var result = batch_script.create_file_result()
	result.file_path = file_path
	
	var tokenizer_script = "res://src/gd3/tokenizer.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/tokenizer.gd"
	var tokenizer = load(tokenizer_script).new()
	var tokens = tokenizer.tokenize_file(file_path)
	var tokenizer_errors = tokenizer.get_errors()
	
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
	
	var detector = preload("res://src/control_flow_detector.gd").new()
	var control_flow_nodes = detector.detect_control_flow(tokens, version_adapter)
	var detector_errors = detector.get_errors()
	if detector_errors.size() > 0:
		result.errors += detector_errors
	
	var func_detector = preload("res://src/function_detector.gd").new()
	var functions = func_detector.detect_functions(tokens)
	result.functions = functions
	
	var class_detector = preload("res://src/class_detector.gd").new()
	var classes = class_detector.detect_classes(tokens)
	result.classes = classes
	var class_errors = class_detector.get_errors()
	if class_errors.size() > 0:
		result.errors += class_errors
	
	var cc_calc = preload("res://src/cc_calculator.gd").new()
	var cc = cc_calc.calculate_cc(control_flow_nodes)
	result.cc = cc
	result.cc_breakdown = cc_calc.get_breakdown()
	result.per_function_cc = _calculate_per_function_cc(control_flow_nodes, functions)
	
	var cog_calc = preload("res://src/cog_complexity_calculator.gd").new()
	var cog_result = cog_calc.calculate_cog(control_flow_nodes, functions)
	result.cog = cog_result.total_cog
	result.cog_breakdown = cog_result.breakdown
	result.per_function_cog = cog_result.per_function
	
	var confidence_calc = preload("res://src/confidence_calculator.gd").new()
	var confidence_weights = {}
	if config != null and config.parser_config.has("confidence_weights"):
		confidence_weights = config.parser_config["confidence_weights"]
	var confidence_result = confidence_calc.calculate_confidence(tokens, tokenizer_errors, version_adapter, confidence_weights)
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
		
		var cc_calc = preload("res://src/cc_calculator.gd").new()
		var func_cc = cc_calc.calculate_cc(func_nodes)
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
	
	cc_sorted.sort_custom(_compare_cc)
	cog_sorted.sort_custom(_compare_cog)
	
	project_result.worst_cc_files = cc_sorted.slice(0, min(10, cc_sorted.size()))
	project_result.worst_cog_files = cog_sorted.slice(0, min(10, cog_sorted.size()))

func _set_error_summary():
	var helper = load("res://src/error_summary.gd").new()
	var summary = helper.summarize(project_result.file_results, project_result.errors)
	project_result.error_summary = summary.by_code
	project_result.error_severity_summary = summary.by_severity
	project_result.total_errors = summary.total

func _compare_cc(a, b) -> bool:  # BatchAnalyzer.FileResult - loaded dynamically
	return a.cc > b.cc

func _compare_cog(a, b) -> bool:  # BatchAnalyzer.FileResult - loaded dynamically
	return a.cog > b.cog

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
