extends Object
# class_name BatchAnalyzer  # Commented out to avoid parse-time cascade

# Batch analyzer
# processes multiple files and aggregates results

class FileResult:
	var file_path: String = ""
	var success: bool = false
	var cc: int = 0
	var cog: int = 0
	var confidence: float = 0.0
	var functions: Array = []
	var classes: Array = []
	var errors: Array = []
	var cc_breakdown: Dictionary = {}
	var cog_breakdown: Dictionary = {}
	var per_function_cog: Dictionary = {}

class ProjectResult:
	var total_files: int = 0
	var successful_files: int = 0
	var failed_files: int = 0
	var total_cc: int = 0
	var total_cog: int = 0
	var average_cc: float = 0.0
	var average_cog: float = 0.0
	var average_confidence: float = 0.0
	var worst_cc_files: Array = []
	var worst_cog_files: Array = []
	var file_results: Array = []
	var errors: Array = []

var project_result = null  # ProjectResult - nested class
var version_adapter = null

func analyze_project(root_path: String, config, adapter = null):  # -> ProjectResult - nested class
	project_result = ProjectResult.new()
	version_adapter = adapter
	
	var discovery_script = "res://src/gd3/file_discovery.gd" if Engine.get_version_info().get("major", 0) == 3 else "res://src/gd4/file_discovery.gd"
	var discovery = load(discovery_script).new()
	var files = discovery.find_files(root_path, config.include_patterns, config.exclude_patterns)
	
	project_result.total_files = files.size()
	
	if files.size() == 0:
		project_result.errors.append("No files found matching include patterns")
		return project_result
	
	var file_results: Array = []
	var total_cc = 0
	var total_cog = 0
	var total_confidence = 0.0
	var successful_count = 0
	
	for i in range(files.size()):
		var file_path = files[i]
		var file_result = _analyze_file(file_path, config)
		file_results.append(file_result)
		
		if file_result.success:
			successful_count += 1
			total_cc += file_result.cc
			total_cog += file_result.cog
			total_confidence += file_result.confidence
	
	project_result.successful_files = successful_count
	project_result.failed_files = files.size() - successful_count
	project_result.total_cc = total_cc
	project_result.total_cog = total_cog
	
	if successful_count > 0:
		project_result.average_cc = float(total_cc) / float(successful_count)
		project_result.average_cog = float(total_cog) / float(successful_count)
		project_result.average_confidence = float(total_confidence) / float(successful_count)
	
	project_result.file_results = file_results
	
	_calculate_worst_offenders(file_results)
	
	return project_result

func _get_tokenizer_script() -> String:
	var version_info = Engine.get_version_info()
	var is_godot_3 = version_info.get("major", 0) == 3
	return "res://src/gd3/tokenizer.gd" if is_godot_3 else "res://src/tokenizer.gd"

func _analyze_file(file_path: String, config):  # -> FileResult - nested class
	var result = FileResult.new()
	result.file_path = file_path
	
	var tokenizer = load(_get_tokenizer_script()).new()
	var tokens = tokenizer.tokenize_file(file_path)
	var tokenizer_errors = tokenizer.get_errors()
	
	if tokenizer_errors.size() > 0:
		result.errors = tokenizer_errors
		result.success = false
		return result
	
	if tokens.size() == 0:
		result.errors.append("No tokens found")
		result.success = false
		return result
	
	var detector = load("res://src/control_flow_detector.gd").new()
	var control_flow_nodes = detector.detect_control_flow(tokens, version_adapter)
	
	var func_detector = load("res://src/function_detector.gd").new()
	var functions = func_detector.detect_functions(tokens)
	result.functions = functions
	
	var class_detector = load("res://src/class_detector.gd").new()
	var classes = class_detector.detect_classes(tokens)
	result.classes = classes
	
	var cc_calc = load("res://src/cc_calculator.gd").new()
	var cc = cc_calc.calculate_cc(control_flow_nodes)
	result.cc = cc
	result.cc_breakdown = cc_calc.get_breakdown()
	
	var cog_calc = load("res://src/cog_complexity_calculator.gd").new()
	var cog_result = cog_calc.calculate_cog(control_flow_nodes, functions)
	result.cog = cog_result.total_cog
	result.cog_breakdown = cog_result.breakdown
	result.per_function_cog = cog_result.per_function
	
	var confidence_calc = load("res://src/confidence_calculator.gd").new()
	var confidence_result = confidence_calc.calculate_confidence(tokens, tokenizer_errors, version_adapter)
	result.confidence = confidence_result.score
	
	result.success = true
	return result

func _calculate_worst_offenders(file_results: Array):
	var cc_sorted = []
	var cog_sorted = []
	
	for result in file_results:
		if result.success:
			cc_sorted.append(result)
			cog_sorted.append(result)
	
	_sort_by_cc(cc_sorted)
	_sort_by_cog(cog_sorted)
	
	project_result.worst_cc_files = cc_sorted.slice(0, min(10, cc_sorted.size()))
	project_result.worst_cog_files = cog_sorted.slice(0, min(10, cog_sorted.size()))

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

func get_project_result():  # -> ProjectResult - nested class
	return project_result

# Helper methods to create nested class instances when class_name is commented out
static func create_file_result():  # -> FileResult - nested class
	return FileResult.new()

static func create_project_result():  # -> ProjectResult - nested class
	return ProjectResult.new()

