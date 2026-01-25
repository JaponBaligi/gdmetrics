# File operations helper for Godot 4.x
# Used by tokenizer and other core files

extends RefCounted

func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

func open_read(file_path: String):
	return FileAccess.open(file_path, FileAccess.READ)

func close_file(file):
	if file != null:
		file = null

