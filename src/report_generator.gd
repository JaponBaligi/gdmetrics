extends RefCounted
class_name ReportGenerator

# JSON report generator 
# generates JSON reports from analysis results

func generate_report(project_result: BatchAnalyzer.ProjectResult, config: ConfigManager.Config) -> Dictionary:
	var report = {
		"version": "1.0",
		"timestamp": OS.get_datetime_string_from_system(),
		"project": {
			"total_files": project_result.total_files,
			"successful_files": project_result.successful_files,
			"failed_files": project_result.failed_files,
			"totals": {
				"cc": project_result.total_cc,
				"cog": project_result.total_cog
			},
			"averages": {
				"cc": project_result.average_cc,
				"cog": project_result.average_cog,
				"confidence": project_result.average_confidence
			}
		},
		"worst_offenders": {
			"cc": _format_worst_offenders(project_result.worst_cc_files, "cc"),
			"cog": _format_worst_offenders(project_result.worst_cog_files, "cog")
		},
		"files": _format_file_results(project_result.file_results),
		"errors": project_result.errors
	}
	
	return report

func _format_worst_offenders(file_results: Array, metric: String) -> Array:
	var offenders = []
	for result in file_results:
		if result.success:
			var value = result.cc if metric == "cc" else result.cog
			offenders.append({
				"file": result.file_path,
				metric: value,
				"confidence": result.confidence
			})
	return offenders

func _format_file_results(file_results: Array) -> Array:
	var files = []
	for result in file_results:
		var file_data = {
			"file": result.file_path,
			"success": result.success,
			"cc": result.cc,
			"cog": result.cog,
			"confidence": result.confidence,
			"cc_breakdown": result.cc_breakdown,
			"cog_breakdown": result.cog_breakdown,
			"errors": result.errors
		}
		
		if result.success:
			file_data["functions"] = _format_functions(result.functions, result.per_function_cog)
			file_data["classes"] = _format_classes(result.classes)
		
		files.append(file_data)
	return files

func _format_functions(functions: Array, per_function_cog: Dictionary = {}) -> Array:
	var func_list = []
	for func_info in functions:
		var func_data = {
			"name": func_info.name,
			"type": func_info.type,
			"start_line": func_info.start_line,
			"end_line": func_info.end_line,
			"parameters": func_info.parameters.size(),
			"return_type": func_info.return_type if func_info.return_type != "" else "void"
		}
		if per_function_cog.has(func_info.name):
			func_data["cog"] = per_function_cog[func_info.name]
		func_list.append(func_data)
	return func_list

func _format_classes(classes: Array) -> Array:
	var class_list = []
	for class_info in classes:
		class_list.append({
			"name": class_info.name,
			"class_name": class_info.class_name_decl,
			"extends": class_info.extends_class,
			"start_line": class_info.start_line,
			"end_line": class_info.end_line
		})
	return class_list

extends RefCounted
class_name ReportGenerator

# JSON report generator 
# generates JSON reports from analysis results

var FORBIDDEN_OUTPUT_PATHS = [
	"project.godot",
	".git",
	"src/",
	"cli/",
	"docs/",
	".github/"
]

func write_report(report: Dictionary, output_path: String) -> bool:
	output_path = _sanitize_path(output_path)
	
	if not _check_output_overwrite(output_path):
		return false
	
	var json_string = to_json(report)
	
	var file = File.new()
	if file.open(output_path, File.WRITE) != OK:
		return false
	
	file.store_string(json_string)
	file.close()
	
	return true

func _sanitize_path(path: String) -> String:
	if path.empty():
		return "complexity_report.json"
	
	var sanitized = path.replace("\\", "/")
	
	# Remove path traversal attempts
	while sanitized.find("../") >= 0:
		sanitized = sanitized.replace("../", "")
	
	# Remove leading slashes
	while sanitized.begins_with("/"):
		sanitized = sanitized.substr(1)
	
	# Ensure it's relative
	if sanitized.begins_with("res://"):
		sanitized = sanitized.substr(6)
	
	return sanitized

func _check_output_overwrite(output_path: String) -> bool:
	var normalized = output_path.replace("\\", "/").to_lower()
	
	for forbidden in FORBIDDEN_OUTPUT_PATHS:
		if normalized.find(forbidden.to_lower()) >= 0:
			print("ERROR: Output path '%s' would overwrite protected path '%s'" % [output_path, forbidden])
			return false
	
	return true

func generate_and_write(project_result: BatchAnalyzer.ProjectResult, config: ConfigManager.Config) -> bool:
	var report = generate_report(project_result, config)
	var output_path = config.report_config["output_path"]
	return write_report(report, output_path)

