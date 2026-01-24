extends Reference
class_name BatchAnalyzer

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

var project_result: ProjectResult
var version_adapter: VersionAdapter = null

func analyze_project(root_path: String, config: ConfigManager.Config, adapter: VersionAdapter = null) -> ProjectResult:
	project_result = ProjectResult.new()
	version_adapter = adapter
	
	var discovery = preload("res://src/file_discovery.gd").new()
	var files = discovery.find_files(root_path, config.include_patterns, config.exclude_patterns)
	
	project_result.total_files = files.size()
	
	if files.empty():
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

func _analyze_file(file_path: String, config: ConfigManager.Config) -> FileResult:
	var result = FileResult.new()
	result.file_path = file_path
	
	var tokenizer = preload("res://src/tokenizer.gd").new()
	var tokens = tokenizer.tokenize_file(file_path)
	var tokenizer_errors = tokenizer.get_errors()
	
	if tokenizer_errors.size() > 0:
		result.errors = tokenizer_errors
		result.success = false
		return result
	
	if tokens.empty():
		result.errors.append("No tokens found")
		result.success = false
		return result
	
	var detector = preload("res://src/control_flow_detector.gd").new()
	var control_flow_nodes = detector.detect_control_flow(tokens, version_adapter)
	
	var func_detector = preload("res://src/function_detector.gd").new()
	var functions = func_detector.detect_functions(tokens)
	result.functions = functions
	
	var class_detector = preload("res://src/class_detector.gd").new()
	var classes = class_detector.detect_classes(tokens)
	result.classes = classes
	
	var cc_calc = preload("res://src/cc_calculator.gd").new()
	var cc = cc_calc.calculate_cc(control_flow_nodes)
	result.cc = cc
	result.cc_breakdown = cc_calc.get_breakdown()
	
	var cog_calc = preload("res://src/cog_complexity_calculator.gd").new()
	var cog_result = cog_calc.calculate_cog(control_flow_nodes, functions)
	result.cog = cog_result.total_cog
	result.cog_breakdown = cog_result.breakdown
	result.per_function_cog = cog_result.per_function
	
	var confidence_calc = preload("res://src/confidence_calculator.gd").new()
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
	
	cc_sorted.sort_custom(self, "_compare_cc")
	cog_sorted.sort_custom(self, "_compare_cog")
	
	project_result.worst_cc_files = cc_sorted.slice(0, min(10, cc_sorted.size()))
	project_result.worst_cog_files = cog_sorted.slice(0, min(10, cog_sorted.size()))

func _compare_cc(a: FileResult, b: FileResult) -> bool:
	return a.cc > b.cc

func _compare_cog(a: FileResult, b: FileResult) -> bool:
	return a.cog > b.cog

func get_project_result() -> ProjectResult:
	return project_result

