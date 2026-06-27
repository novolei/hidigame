extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	_test_input_action()
	_test_game_settings_model()
	_test_source_wiring()
	_finish()


func _test_input_action() -> void:
	_expect(InputMap.has_action("toggle_benchmark_mode"), "InputMap should include toggle_benchmark_mode")
	var has_f4_key: bool = false
	for event in InputMap.action_get_events("toggle_benchmark_mode"):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == KEY_F4 or key_event.physical_keycode == KEY_F4:
				has_f4_key = true
	_expect(has_f4_key, "toggle_benchmark_mode should be bound to F4")


func _test_game_settings_model() -> void:
	for token in ["signal graphics_changed", "func graphics_settings", "\"display_mode\"", "\"vsync\"", "\"max_fps\"", "\"resolution_scale\"", "\"scale_filter\"", "\"taa\"", "\"msaa\"", "\"fxaa\"", "\"shadow_mapping\"", "\"ssao_quality\"", "\"ssil_quality\"", "\"bloom\"", "\"volumetric_fog\"", "\"gi_quality\""]:
		_expect(_file_has("res://scripts/game_settings.gd", token), "GameSettings source should include %s" % token)


func _test_source_wiring() -> void:
	_expect(_file_has("res://scripts/game_settings.gd", "func apply_graphics_settings"), "GameSettings should apply runtime graphics settings")
	_expect(_file_has("res://scripts/game_settings.gd", "DisplayServer.window_set_vsync_mode(vsync_mode)"), "GameSettings should apply VSync")
	_expect(_file_has("res://scripts/game_settings.gd", "Engine.max_fps = max_fps"), "GameSettings should apply max_fps")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "SettingsScroll"), "Settings menu should use a scrollable settings body")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "settings_active_tab"), "Settings menu should track the active settings tab")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "_set_settings_active_tab"), "Settings tabs should be interactive")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "_build_settings_active_page"), "Settings menu should build only the active tab page")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "_build_settings_video_page"), "Settings menu should isolate video settings")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "_build_settings_render_page"), "Settings menu should isolate render settings")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "_build_settings_gameplay_page"), "Settings menu should isolate gameplay settings")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "_add_settings_option_row"), "Settings menu should include graphics option rows")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "GameSettings.set_graphics_setting"), "Settings menu should write graphics options to GameSettings")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "settings.resolution_scale"), "Settings menu should expose resolution scale")
	_expect(_file_has("res://scripts/main_menu_ui.gd", "settings.global_illumination"), "Settings menu should expose GI quality")
	_expect(_file_has("res://scripts/level.gd", "BENCHMARK_WINDOW_SIZE"), "Level should define benchmark window size")
	_expect(_file_has("res://scripts/level.gd", "DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)"), "Benchmark mode should disable VSync")
	_expect(_file_has("res://scripts/level.gd", "_sync_menu_background_performance_state"), "Level should suspend background world rendering behind menu")
	_expect(_file_has("res://scripts/i18n.gd", "settings.display_mode"), "I18n should include settings display labels")
	_expect(_file_has("res://scripts/i18n.gd", "settings.section.gameplay"), "I18n should include settings gameplay section label")


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
		print("[PerformanceSettingsTest] PASS")
		quit(0)
		return
	for failure in failures:
		push_error("[PerformanceSettingsTest] " + failure)
	quit(1)
