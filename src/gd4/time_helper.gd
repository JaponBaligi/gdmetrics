# Time helper for Godot 4.x

extends Object

func get_timestamp() -> String:
	return Time.get_datetime_string_from_system()

func get_msec() -> int:
	return Time.get_ticks_msec()
