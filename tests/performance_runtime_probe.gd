extends SceneTree

const LEVEL_SCENE_PATH := "res://scenes/level/level.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(LEVEL_SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Failed to load level scene")
		_finish()
		return
	var level: Node = packed.instantiate()
	root.add_child(level)
	await _wait_frames(90)
	print("[PerformanceRuntimeProbe] level_probe=" + JSON.stringify({"name": level.name, "class": level.get_class(), "script": _script_path(level), "methods": _filtered_methods(level)}))
	_expect(level.has_method("get_benchmark_metrics"), "Level should expose benchmark metrics")
	_expect(level.has_method("_set_benchmark_mode_enabled"), "Level should expose benchmark toggle implementation")
	var menu: Node = level.get_node_or_null("MainMenuUI")
	if menu != null:
		print("[PerformanceRuntimeProbe] menu_probe=" + JSON.stringify({"name": menu.name, "class": menu.get_class(), "script": _script_path(menu), "methods": _filtered_methods(menu)}))
	if menu != null and menu.has_method("_set_settings_visible"):
		menu.call("_set_settings_visible", true)
	await _wait_frames(30)
	var settings_panel: CanvasItem = menu.get_node_or_null("SettingsPanel") as CanvasItem if menu != null else null
	var scroll_found: bool = menu != null and menu.get_node_or_null("SettingsPanel/SettingsCanvas/SettingsScroll") != null
	_expect(settings_panel != null and settings_panel.visible, "Settings panel should open")
	_expect(scroll_found, "Settings panel should include SettingsScroll")
	var tab_rows: Dictionary = await _settings_tab_rows(menu)
	print("[PerformanceRuntimeProbe] settings_tabs=" + JSON.stringify(tab_rows))
	_expect_rows(tab_rows.get("general", []) as Array, ["LanguageSettingRow"], ["DisplayModeSettingRow", "TaaSettingRow", "FovSettingRow"], "general")
	_expect_rows(tab_rows.get("video", []) as Array, ["DisplayModeSettingRow", "VSyncSettingRow", "MaxFpsSettingRow", "ResolutionScaleSettingRow", "ScaleFilterSettingRow"], ["LanguageSettingRow", "TaaSettingRow", "FovSettingRow"], "video")
	_expect_rows(tab_rows.get("render", []) as Array, ["TaaSettingRow", "MsaaSettingRow", "FxaaSettingRow", "ShadowSettingRow", "SsaoSettingRow", "SsilSettingRow", "BloomSettingRow", "VolumetricFogSettingRow", "GiSettingRow"], ["LanguageSettingRow", "DisplayModeSettingRow", "FovSettingRow"], "render")
	_expect_rows(tab_rows.get("gameplay", []) as Array, ["FovSettingRow"], ["LanguageSettingRow", "DisplayModeSettingRow", "TaaSettingRow"], "gameplay")
	var before: Dictionary = _metrics(level)
	if level.has_method("_set_benchmark_mode_enabled"):
		level.call("_set_benchmark_mode_enabled", true)
	await _wait_frames(90)
	var after: Dictionary = _metrics(level)
	_expect(bool(after.get("enabled", false)), "Benchmark mode should be enabled")
	_expect(int(after.get("vsync_mode", -1)) == DisplayServer.VSYNC_DISABLED, "Benchmark mode should disable VSync")
	_expect(int(after.get("max_fps", -1)) == 0, "Benchmark mode should uncap FPS")
	_expect(str(after.get("window_size", "")).contains("1280"), "Benchmark mode should use 1280 width")
	print("[PerformanceRuntimeProbe] settings=" + JSON.stringify({"visible": settings_panel != null and settings_panel.visible, "scroll_found": scroll_found}))
	print("[PerformanceRuntimeProbe] before=" + JSON.stringify(before))
	print("[PerformanceRuntimeProbe] after=" + JSON.stringify(after))
	if level.has_method("_set_benchmark_mode_enabled"):
		level.call("_set_benchmark_mode_enabled", false)
	level.queue_free()
	await process_frame
	_finish()


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _script_path(node: Node) -> String:
	if node == null:
		return ""
	var script_resource: Variant = node.get_script()
	if script_resource is Resource:
		return (script_resource as Resource).resource_path
	return ""


func _filtered_methods(node: Node) -> Array[String]:
	var names: Array[String] = []
	if node == null:
		return names
	for raw_method in node.get_method_list():
		var method: Dictionary = raw_method as Dictionary
		var method_name: String = str(method.get("name", ""))
		if method_name.contains("benchmark") or method_name.contains("settings"):
			names.append(method_name)
	return names


func _settings_tab_rows(menu: Node) -> Dictionary:
	var result: Dictionary = {}
	if menu == null:
		_fail("Settings menu should exist before checking tabs")
		return result
	if not menu.has_method("_set_settings_active_tab"):
		_fail("Settings menu should expose active tab switching")
		return result
	for tab_id in ["general", "video", "render", "gameplay"]:
		menu.call("_set_settings_active_tab", tab_id)
		await _wait_frames(12)
		result[tab_id] = _settings_row_names(menu)
	return result


func _settings_row_names(menu: Node) -> Array[String]:
	var names: Array[String] = []
	var content: Node = menu.get_node_or_null("SettingsPanel/SettingsCanvas/SettingsScroll/SettingsRows")
	if content == null:
		return names
	for child in content.get_children():
		var child_name := String(child.name)
		if child_name.ends_with("SettingRow"):
			names.append(child_name)
	return names


func _expect_rows(rows: Array, required: Array, forbidden: Array, tab_id: String) -> void:
	for row in required:
		_expect(rows.has(str(row)), "Settings %s tab should include %s" % [tab_id, str(row)])
	for row in forbidden:
		_expect(not rows.has(str(row)), "Settings %s tab should not include %s" % [tab_id, str(row)])


func _metrics(level: Node) -> Dictionary:
	var raw: Dictionary = {}
	if level != null and level.has_method("get_benchmark_metrics"):
		raw = level.call("get_benchmark_metrics") as Dictionary
	return {
		"enabled": bool(raw.get("enabled", false)),
		"fps": int(raw.get("fps", 0)),
		"max_fps": int(raw.get("max_fps", -1)),
		"menu_background_suspended": bool(raw.get("menu_background_suspended", false)),
		"draw_calls": int(raw.get("draw_calls", -1)),
		"render_objects": int(raw.get("render_objects", -1)),
		"primitives": int(raw.get("primitives", -1)),
		"memory_static_mib": float(raw.get("memory_static_mib", -1.0)),
		"vsync_mode": int(raw.get("vsync_mode", -1)),
		"window_mode": int(raw.get("window_mode", -1)),
		"window_size": str(raw.get("window_size", "")),
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	failures.append(message)
	push_error("[PerformanceRuntimeProbe] " + message)


func _finish() -> void:
	if failures.is_empty():
		print("[PerformanceRuntimeProbe] PASS")
		quit(0)
		return
	quit(1)
