# File operations helper for Godot 4.x
# This file is only loaded in Godot 4.x

extends RefCounted

func write_file(file_path: String, content: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file = null
	return true

func remove_file(file_path: String):
	var dir = DirAccess.open("user://")
	if dir != null:
		dir.remove(file_path)

func read_file(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var content = file.get_as_text()
	file = null
	return content

func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

func parse_json(content: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(content) != OK:
		return {}
	return json.get_data()

func stringify_json(data: Dictionary) -> String:
	return JSON.stringify(data, "  ")

