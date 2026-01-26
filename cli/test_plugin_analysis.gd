# Test script to debug plugin analysis in Godot 3.x
# Run with: godot3 --headless --path . --script cli/test_plugin_analysis.gd

extends SceneTree

func _init():
	var separator = "============================================================"
	print(separator)
	print("Testing Plugin Analysis Components")
	print(separator)
	
	# Test 1: Load async analyzer
	print("\n[Test 1] Loading async analyzer...")
	var async_analyzer_script = load("res://addons/gdscript_complexity/gd3/async_analyzer.gd")
	if async_analyzer_script == null:
		print("ERROR: Failed to load async_analyzer script")
		quit(1)
		return
	
	var async_analyzer = async_analyzer_script.new()
	if async_analyzer == null:
		print("ERROR: Failed to create async_analyzer instance")
		quit(1)
		return
	print("OK: Async analyzer loaded")
	
	# Test 2: Load config manager
	print("\n[Test 2] Loading config manager...")
	var config_manager_script = load("res://src/config_manager.gd")
	if config_manager_script == null:
		print("ERROR: Failed to load config_manager script")
		quit(1)
		return
	
	var config_manager = config_manager_script.new()
	if config_manager == null:
		print("ERROR: Failed to create config_manager instance")
		quit(1)
		return
	
	var config_path = "res://complexity_config.json"
	if not config_manager.load_config(config_path):
		print("WARNING: Config file not found, using defaults")
		print("Config errors: ", config_manager.get_errors())
	print("OK: Config manager loaded")
	
	# Test 3: Load version adapter
	print("\n[Test 3] Loading version adapter...")
	var version_adapter_script = load("res://addons/gdscript_complexity/version_adapter.gd")
	if version_adapter_script == null:
		print("ERROR: Failed to load version_adapter script")
		quit(1)
		return
	
	var version_adapter = version_adapter_script.new()
	if version_adapter == null:
		print("ERROR: Failed to create version_adapter instance")
		quit(1)
		return
	print("OK: Version adapter loaded: %s" % version_adapter.get_version_string())
	
	# Test 4: Load file discovery
	print("\n[Test 4] Loading file discovery...")
	var discovery_script = load("res://src/gd3/file_discovery.gd")
	if discovery_script == null:
		print("ERROR: Failed to load file_discovery script")
		quit(1)
		return
	
	var discovery = discovery_script.new()
	if discovery == null:
		print("ERROR: Failed to create discovery instance")
		quit(1)
		return
	print("OK: File discovery loaded")
	
	# Test 5: Find files
	print("\n[Test 5] Finding files...")
	var config = config_manager.get_config()
	var files = discovery.find_files("res://", config.include_patterns, config.exclude_patterns)
	print("Found %d files" % files.size())
	if files.size() > 0:
		print("First 5 files:")
		for i in range(min(5, files.size())):
			print("  - %s" % files[i])
	print("OK: Files found")
	
	# Test 6: Connect signals
	print("\n[Test 6] Testing signal connections...")
	var signal_connected = false
	if async_analyzer.connect("progress_updated", self, "_on_progress_updated") == OK:
		signal_connected = true
		print("OK: progress_updated signal connected")
	else:
		print("ERROR: Failed to connect progress_updated signal")
	
	if async_analyzer.connect("file_analyzed", self, "_on_file_analyzed") == OK:
		print("OK: file_analyzed signal connected")
	else:
		print("ERROR: Failed to connect file_analyzed signal")
	
	if async_analyzer.connect("analysis_complete", self, "_on_analysis_complete") == OK:
		print("OK: analysis_complete signal connected")
	else:
		print("ERROR: Failed to connect analysis_complete signal")
	
	if async_analyzer.connect("analysis_cancelled", self, "_on_analysis_cancelled") == OK:
		print("OK: analysis_cancelled signal connected")
	else:
		print("ERROR: Failed to connect analysis_cancelled signal")
	
	if async_analyzer.connect("process_next_batch_requested", self, "_on_process_next_batch_requested") == OK:
		print("OK: process_next_batch_requested signal connected")
	else:
		print("ERROR: Failed to connect process_next_batch_requested signal")
	
	# Test 7: Try to start analysis (but don't actually process)
	print("\n[Test 7] Testing analysis start (will cancel immediately)...")
	
	# Start analysis (pass null for plugin since we're testing in headless mode)
	async_analyzer.start_analysis("res://", config, version_adapter, null)
	
	if async_analyzer.is_analysis_running():
		print("OK: Analysis started")
		# Cancel immediately
		async_analyzer.cancel()
		print("OK: Analysis cancelled")
	else:
		print("ERROR: Analysis did not start")
	
	print("\n" + separator)
	print("All tests completed")
	print(separator)
	
	quit(0)

func _on_progress_updated(current, total, file_path):
	print("[Signal] Progress: %d/%d - %s" % [current, total, file_path])

func _on_file_analyzed(file_result):
	print("[Signal] File analyzed: %s (success: %s)" % [file_result.file_path, file_result.success])

func _on_analysis_complete(project_result):
	print("[Signal] Analysis complete: %d files" % project_result.total_files)

func _on_analysis_cancelled():
	print("[Signal] Analysis cancelled")

func _on_process_next_batch_requested():
	print("[Signal] Process next batch requested")
