extends Node

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud = preload("res://scripts/match_status_hud.gd").new()
	add_child(hud)
	await get_tree().process_frame

	hud.set_match_state(3, 4, 2, 3, 147.0, "Search Time")
	await get_tree().process_frame
	_expect(hud.visible, "MatchStatusHUD should become visible when team state is assigned")
	var counts: Dictionary = hud.get_icon_counts_for_test()
	_expect(int(counts.get("props_total", 0)) == 4, "HUD should track total prop icons")
	_expect(int(counts.get("props_alive", 0)) == 3, "HUD should track alive prop icons")
	_expect(int(counts.get("hunters_total", 0)) == 3, "HUD should track total hunter icons")
	_expect(int(counts.get("hunters_alive", 0)) == 2, "HUD should track alive hunter icons")
	_expect(hud._get_panel_rect(Vector2(1920.0, 1080.0)).position.x > 400.0, "HUD panel should be centered near the top of a 1080p viewport")
	var icon_paths: Dictionary = hud.get_state_icon_paths_for_test()
	_expect(str(icon_paths.get("alive", "")) == "res://addons/at-icons/node/heart.svg", "Alive players should use the white heart icon")
	_expect(str(icon_paths.get("dead", "")) == "res://addons/at-icons/node3d/ghost.svg", "Dead players should use the red ghost icon")
	_expect(str(icon_paths.get("timer", "")) == "res://addons/at-icons/node/stopwatch.svg", "Timer should use the stopwatch icon")
	_expect(hud.has_state_icon_texture_for_test(true), "HUD should generate a tinted alive icon texture")
	_expect(hud.has_state_icon_texture_for_test(false), "HUD should generate a tinted dead icon texture")
	_expect(hud.has_timer_icon_texture_for_test(), "HUD should generate a tinted stopwatch icon texture")
	var panel_1080p: Rect2 = hud._get_panel_rect(Vector2(1920.0, 1080.0))
	var panel_4k: Rect2 = hud._get_panel_rect(Vector2(3840.0, 2160.0))
	_expect(panel_1080p.size.y <= 96.0, "HUD panel should stay compact at 1080p")
	_expect(panel_4k.size.y > panel_1080p.size.y, "HUD panel should still scale up on higher resolutions")

	hud.clear()
	await get_tree().process_frame
	_expect(not hud.visible, "MatchStatusHUD should hide when cleared")

	hud.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[MatchStatusHUDTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[MatchStatusHUDTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
