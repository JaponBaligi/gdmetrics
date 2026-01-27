# Time helper for Godot 3.x

extends Object

func get_timestamp() -> String:
	var info = OS.get_datetime()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		info.year, info.month, info.day, info.hour, info.minute, info.second
	]
