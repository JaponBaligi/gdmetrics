# File operations helper for Godot 3.5
# Used by tokenizer and other core files

extends Object

func file_exists(file_path: String) -> bool:
	var file = File.new()
	return file.file_exists(file_path)

func open_read(file_path: String):
	var file = File.new()
	var err = file.open(file_path, File.READ)
	if err != OK:
		return null
	return file

func close_file(file):
	if file != null:
		file.close()

