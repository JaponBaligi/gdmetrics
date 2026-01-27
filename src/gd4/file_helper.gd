# File operations helper for Godot 4.x
# Used by tokenizer and other core files
# Note: This file uses 4.x APIs but extends Object for 3.x parse compatibility

extends Object

func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

func open_read(file_path: String):
	return FileAccess.open(file_path, FileAccess.READ)

func open_append(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return null
	file.seek_end()
	return file

func close_file(file):
	if file != null:
		file = null

func write_line(file, text: String):
	if file != null:
		file.store_string(text + "\n")
