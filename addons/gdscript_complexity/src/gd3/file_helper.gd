# File operations helper for Godot 3.5 & 4.x
# Used by tokenizer and other core files

extends Object

func _get_is_godot_3() -> bool:
	return Engine.get_version_info().get("major", 0) == 3

func file_exists(file_path: String) -> bool:
	if _get_is_godot_3():
		var file = File.new()
		return file.file_exists(file_path)
	else:
		return FileAccess.file_exists(file_path)

func open_read(file_path: String):
	if _get_is_godot_3():
		var file = File.new()
		var err = file.open(file_path, File.READ)
		if err != OK:
			return null
		return file
	else:
		return FileAccess.open(file_path, FileAccess.READ)

func open_append(file_path: String):
	if _get_is_godot_3():
		var file = File.new()
		var err = file.open(file_path, File.READ_WRITE)
		if err != OK:
			err = file.open(file_path, File.WRITE)
			if err != OK:
				return null
		file.seek_end()
		return file
	else:
		var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
		if file == null:
			file = FileAccess.open(file_path, FileAccess.WRITE)
			if file == null:
				return null
		# FileAccess doesn't have seek_end, so we'll just return it
		return file

func close_file(file):
	# Godot 4.x handles this automatically via scope
	if file != null and _get_is_godot_3():
		file.close()

func write_line(file, text: String):
	if file != null:
		file.store_string(text + "\n")

func parse_json(content: String) -> Dictionary:
	var parse_result = JSON.parse(content)
	if parse_result.error != OK:
		return {}
	return parse_result.result

func stringify_json(data: Dictionary) -> String:
	if _get_is_godot_3():
		return var2str(data)
	else:
		var json = JSON.new()
		return json.stringify(data)
