# File operations helper for Godot 3.5
# This file is only loaded in Godot 3.5

extends Reference

func write_file(file_path: String, content: String) -> bool:
	var file = File.new()
	var err = file.open(file_path, File.WRITE)
	if err != OK:
		return false
	file.store_string(content)
	file.close()
	return true

func remove_file(file_path: String):
	var dir = Directory.new()
	if dir.open("user://") == OK:
		dir.remove(file_path)

func read_file(file_path: String) -> String:
	var file = File.new()
	var err = file.open(file_path, File.READ)
	if err != OK:
		return ""
	var content = file.get_as_text()
	file.close()
	return content

func file_exists(file_path: String) -> bool:
	var file = File.new()
	return file.file_exists(file_path)

func parse_json(content: String) -> Dictionary:
	var parse_result = JSON.parse(content)
	if parse_result.error != OK:
		return {}
	return parse_result.result

func stringify_json(data: Dictionary) -> String:
	return to_json(data)

