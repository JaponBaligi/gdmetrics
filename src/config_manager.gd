extends RefCounted
class_name ConfigManager

# Configuration manager
# handles JSON configuration parsing, validation, and defaults

class Config:
	var include_patterns: Array = []
	var exclude_patterns: Array = []
	var cc_config: Dictionary = {}
	var cog_config: Dictionary = {}
	var parser_config: Dictionary = {}
	var report_config: Dictionary = {}
	var performance_config: Dictionary = {}
	var telemetry_config: Dictionary = {}
	
	func _init():
		include_patterns = ["res://**/*.gd"]
		exclude_patterns = []
		cc_config = {
			"count_logical_operators": true,
			"threshold_warn": 10,
			"threshold_fail": 20
		}
		cog_config = {
			"nesting_penalty": 1,
			"threshold_warn": 15,
			"threshold_fail": 30
		}
		parser_config = {
			"prefer_ast_when_available": false,
			"fallback_to_heuristic": true,
			"parser_mode": "balanced",
			"max_expected_errors_per_100_lines": 5,
			"force_mode": null
		}
		report_config = {
			"formats": ["json"],
			"output_path": "res://complexity_report.json",
			"annotate_editor": false
		}
		performance_config = {
			"enable_caching": false,
			"cache_path": "res://.complexity_cache",
			"incremental_analysis": false
		}
		telemetry_config = {
			"enable_anonymous_reporting": false
		}

var config: Config
var config_path: String = ""
var errors: Array = []

func _init(config_file_path: String = ""):
	config = Config.new()
	if config_file_path != "":
		load_config(config_file_path)

func load_config(config_file_path: String) -> bool:
	errors.clear()
	config_path = config_file_path
	
	if not FileAccess.file_exists(config_file_path):
		errors.append("Config file not found: %s (using defaults)" % config_file_path)
		return false
	
	var file = FileAccess.open(config_file_path, FileAccess.READ)
	if file == null:
		errors.append("Failed to open config file: %s (using defaults)" % config_file_path)
		return false
	
	var json_text = file.get_as_text()
	file = null
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		errors.append("Invalid JSON in config file: %s (using defaults)" % json.get_error_message())
		return false
	
	var data = json.get_data()
	if not data is Dictionary:
		errors.append("Config file must contain a JSON object (using defaults)")
		return false
	
	_parse_config(data)
	return true

func _parse_config(data: Dictionary):
	if data.has("include"):
		if data["include"] is Array:
			config.include_patterns = data["include"]
		else:
			errors.append("Config 'include' must be an array")
	
	if data.has("exclude"):
		if data["exclude"] is Array:
			config.exclude_patterns = data["exclude"]
		else:
			errors.append("Config 'exclude' must be an array")
	
	if data.has("cc"):
		if data["cc"] is Dictionary:
			_parse_cc_config(data["cc"])
		else:
			errors.append("Config 'cc' must be an object")
	
	if data.has("cog"):
		if data["cog"] is Dictionary:
			_parse_cog_config(data["cog"])
		else:
			errors.append("Config 'cog' must be an object")
	
	if data.has("parser"):
		if data["parser"] is Dictionary:
			_parse_parser_config(data["parser"])
		else:
			errors.append("Config 'parser' must be an object")
	
	if data.has("report"):
		if data["report"] is Dictionary:
			_parse_report_config(data["report"])
		else:
			errors.append("Config 'report' must be an object")
	
	if data.has("performance"):
		if data["performance"] is Dictionary:
			_parse_performance_config(data["performance"])
		else:
			errors.append("Config 'performance' must be an object")
	
	if data.has("telemetry"):
		if data["telemetry"] is Dictionary:
			_parse_telemetry_config(data["telemetry"])
		else:
			errors.append("Config 'telemetry' must be an object")

func _parse_cc_config(cc_data: Dictionary):
	if cc_data.has("count_logical_operators"):
		if cc_data["count_logical_operators"] is bool:
			config.cc_config["count_logical_operators"] = cc_data["count_logical_operators"]
	
	if cc_data.has("threshold_warn"):
		if cc_data["threshold_warn"] is int and cc_data["threshold_warn"] >= 0:
			config.cc_config["threshold_warn"] = cc_data["threshold_warn"]
	
	if cc_data.has("threshold_fail"):
		if cc_data["threshold_fail"] is int and cc_data["threshold_fail"] >= 0:
			config.cc_config["threshold_fail"] = cc_data["threshold_fail"]

func _parse_cog_config(cog_data: Dictionary):
	if cog_data.has("nesting_penalty"):
		if cog_data["nesting_penalty"] is int and cog_data["nesting_penalty"] >= 0:
			config.cog_config["nesting_penalty"] = cog_data["nesting_penalty"]
	
	if cog_data.has("threshold_warn"):
		if cog_data["threshold_warn"] is int and cog_data["threshold_warn"] >= 0:
			config.cog_config["threshold_warn"] = cog_data["threshold_warn"]
	
	if cog_data.has("threshold_fail"):
		if cog_data["threshold_fail"] is int and cog_data["threshold_fail"] >= 0:
			config.cog_config["threshold_fail"] = cog_data["threshold_fail"]

func _parse_parser_config(parser_data: Dictionary):
	if parser_data.has("prefer_ast_when_available"):
		if parser_data["prefer_ast_when_available"] is bool:
			config.parser_config["prefer_ast_when_available"] = parser_data["prefer_ast_when_available"]
	
	if parser_data.has("fallback_to_heuristic"):
		if parser_data["fallback_to_heuristic"] is bool:
			config.parser_config["fallback_to_heuristic"] = parser_data["fallback_to_heuristic"]
	
	if parser_data.has("parser_mode"):
		if parser_data["parser_mode"] is String:
			var mode = parser_data["parser_mode"]
			if mode == "fast" or mode == "balanced" or mode == "thorough":
				config.parser_config["parser_mode"] = mode
			else:
				errors.append("Invalid parser_mode '%s', using 'balanced'" % mode)
	
	if parser_data.has("max_expected_errors_per_100_lines"):
		if parser_data["max_expected_errors_per_100_lines"] is int and parser_data["max_expected_errors_per_100_lines"] >= 0:
			config.parser_config["max_expected_errors_per_100_lines"] = parser_data["max_expected_errors_per_100_lines"]
	
	if parser_data.has("force_mode"):
		if parser_data["force_mode"] == null:
			config.parser_config["force_mode"] = null
		elif parser_data["force_mode"] is String:
			var mode = parser_data["force_mode"]
			if mode == "fast" or mode == "balanced" or mode == "thorough":
				config.parser_config["force_mode"] = mode
			else:
				errors.append("Invalid force_mode '%s', using null" % mode)
	
	if parser_data.has("confidence_weights"):
		if parser_data["confidence_weights"] is Dictionary:
			config.parser_config["confidence_weights"] = parser_data["confidence_weights"]

func _parse_report_config(report_data: Dictionary):
	if report_data.has("formats"):
		if report_data["formats"] is Array:
			config.report_config["formats"] = report_data["formats"]
	
	if report_data.has("output_path"):
		if report_data["output_path"] is String:
			config.report_config["output_path"] = report_data["output_path"]
	
	if report_data.has("annotate_editor"):
		if report_data["annotate_editor"] is bool:
			config.report_config["annotate_editor"] = report_data["annotate_editor"]

func _parse_performance_config(perf_data: Dictionary):
	if perf_data.has("enable_caching"):
		if perf_data["enable_caching"] is bool:
			config.performance_config["enable_caching"] = perf_data["enable_caching"]
	
	if perf_data.has("cache_path"):
		if perf_data["cache_path"] is String:
			config.performance_config["cache_path"] = perf_data["cache_path"]
	
	if perf_data.has("incremental_analysis"):
		if perf_data["incremental_analysis"] is bool:
			config.performance_config["incremental_analysis"] = perf_data["incremental_analysis"]

func _parse_telemetry_config(telemetry_data: Dictionary):
	if telemetry_data.has("enable_anonymous_reporting"):
		if telemetry_data["enable_anonymous_reporting"] is bool:
			config.telemetry_config["enable_anonymous_reporting"] = telemetry_data["enable_anonymous_reporting"]

func get_include_patterns() -> Array:
	return config.include_patterns.duplicate()

func get_exclude_patterns() -> Array:
	return config.exclude_patterns.duplicate()

func get_cc_threshold_warn() -> int:
	return config.cc_config["threshold_warn"]

func get_cc_threshold_fail() -> int:
	return config.cc_config["threshold_fail"]

func get_cog_threshold_warn() -> int:
	return config.cog_config["threshold_warn"]

func get_cog_threshold_fail() -> int:
	return config.cog_config["threshold_fail"]

func get_parser_mode() -> String:
	return config.parser_config["parser_mode"]

func get_force_mode():
	return config.parser_config["force_mode"]

func get_config() -> Config:
	return config

func get_errors() -> Array:
	return errors.duplicate()

func has_errors() -> bool:
	return errors.size() > 0

