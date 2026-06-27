extends SceneTree

const DebugOverlayScript := preload("res://scripts/debug_overlay.gd")

var failures: Array[String] = []


func _init() -> void:
	_test_input_action()
	_test_overlay_content()
	_test_source_wiring()
	_finish()


func _test_input_action() -> void:
	_expect(InputMap.has_action("toggle_debug"), "InputMap should include toggle_debug")
	var has_f3_key: bool = false
	for event in InputMap.action_get_events("toggle_debug"):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == KEY_F3 or key_event.physical_keycode == KEY_F3:
				has_f3_key = true
	_expect(has_f3_key, "toggle_debug should be bound to F3")

	_expect(InputMap.has_action("toggle_benchmark_mode"), "InputMap should include toggle_benchmark_mode")
	var has_f4_key: bool = false
	for event in InputMap.action_get_events("toggle_benchmark_mode"):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == KEY_F4 or key_event.physical_keycode == KEY_F4:
				has_f4_key = true
	_expect(has_f4_key, "toggle_benchmark_mode should be bound to F4")


func _test_overlay_content() -> void:
	var overlay: DebugOverlay = DebugOverlayScript.new() as DebugOverlay
	root.add_child(overlay)
	overlay._ready()
	overlay._process(0.016)

	for token in ["FPS:", "VSync:", "Benchmark:", "Memory:", "Online:"]:
		_expect(overlay.text.contains(token), "DebugOverlay text should include %s" % token)
	_expect(overlay.position == Vector2(12.0, 12.0), "DebugOverlay should render at the upper-left viewport corner")
	_expect(overlay.visible, "DebugOverlay should be visible by default")
	var f3_event: InputEventKey = InputEventKey.new()
	f3_event.keycode = KEY_F3
	f3_event.pressed = true
	overlay._input(f3_event)
	_expect(not overlay.visible, "DebugOverlay should hide after F3 is pressed")
	overlay._input(f3_event)
	_expect(overlay.visible, "DebugOverlay should show after F3 is pressed again")

	overlay.queue_free()


func _test_source_wiring() -> void:
	_expect(_file_has("res://scripts/debug_overlay.gd", "event.is_action_pressed(\"toggle_debug\")"), "DebugOverlay should toggle from toggle_debug input")
	_expect(_file_has("res://scripts/debug_overlay.gd", "_benchmark_status()"), "DebugOverlay should display benchmark state")
	_expect(_file_has("res://scripts/level.gd", "const DebugOverlayScript := preload(\"res://scripts/debug_overlay.gd\")"), "Level should preload DebugOverlay")
	_expect(_file_has("res://scripts/level.gd", "_ensure_debug_overlay()"), "Level should create DebugOverlay at runtime")
	_expect(_file_has("res://scripts/level.gd", "event.is_action_pressed(\"toggle_benchmark_mode\")"), "Level should toggle benchmark mode from input")
	_expect(_file_has("res://scripts/level.gd", "_sync_menu_background_performance_state()"), "Level should suspend the menu background world")


func _file_has(path: String, token: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	return content.contains(token)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("[DebugOverlayTest] PASS")
		quit(0)
		return
	for failure in failures:
		push_error("[DebugOverlayTest] " + failure)
	quit(1)
