extends Reference
class_name FileDiscovery

# File discovery system
# recursively finds files matching include/exclude patterns

func find_files(root_path: String, include_patterns: Array, exclude_patterns: Array) -> Array:
	var files: Array = []
	var dir = Directory.new()
	
	if not dir.dir_exists(root_path):
		return files
	
	_find_files_recursive(root_path, root_path, include_patterns, exclude_patterns, files)
	return files

func _find_files_recursive(root_path: String, current_path: String, include_patterns: Array, exclude_patterns: Array, files: Array):
	var dir = Directory.new()
	
	if dir.open(current_path) != OK:
		return
	
	dir.list_dir_begin(true, true)
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = current_path.plus_file(file_name)
		
		if dir.current_is_dir():
			_find_files_recursive(root_path, full_path, include_patterns, exclude_patterns, files)
		else:
			if file_name.ends_with(".gd"):
				var relative_path = _make_relative(root_path, full_path)
				if _matches_patterns(relative_path, include_patterns, exclude_patterns):
					files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _make_relative(root_path: String, full_path: String) -> String:
	if full_path.begins_with(root_path):
		var relative = full_path.substr(root_path.length())
		if relative.begins_with("/") or relative.begins_with("\\"):
			relative = relative.substr(1)
		return "res://" + relative.replace("\\", "/")
	return full_path

func _matches_patterns(file_path: String, include_patterns: Array, exclude_patterns: Array) -> bool:
	if include_patterns.empty():
		return false
	
	var matches_include = false
	for pattern in include_patterns:
		if _match_pattern(file_path, pattern):
			matches_include = true
			break
	
	if not matches_include:
		return false
	
	for pattern in exclude_patterns:
		if _match_pattern(file_path, pattern):
			return false
	
	return true

func _match_pattern(file_path: String, pattern: String) -> bool:
	if pattern == "":
		return false
	
	var normalized_path = file_path.replace("\\", "/")
	var normalized_pattern = pattern.replace("\\", "/")
	
	if normalized_pattern == normalized_path:
		return true
	
	if normalized_pattern.ends_with("**/*.gd"):
		var prefix = normalized_pattern.substr(0, normalized_pattern.length() - 7)
		if normalized_path.begins_with(prefix) and normalized_path.ends_with(".gd"):
			return true
	
	if normalized_pattern.ends_with("/*.gd"):
		var prefix = normalized_pattern.substr(0, normalized_pattern.length() - 5)
		if normalized_path.begins_with(prefix) and normalized_path.ends_with(".gd"):
			var remaining = normalized_path.substr(prefix.length())
			if remaining.count("/") == 1:
				return true
	
	if normalized_pattern.ends_with(".gd"):
		return normalized_path.ends_with(normalized_pattern)
	
	return false

