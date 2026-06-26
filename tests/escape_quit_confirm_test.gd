extends SceneTree

const MatchIntroOverlayScript := preload("res://scripts/match_intro_overlay.gd")
const I18nScript := preload("res://scripts/i18n.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_quit_confirm_overlay()
	_test_quit_input_mapping_removed()
	_test_escape_routing_is_scene_global()

	if failures.is_empty():
		print("[EscapeQuitConfirmTest] PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[EscapeQuitConfirmTest] " + failure)
		quit(1)


func _test_quit_confirm_overlay() -> void:
	var i18n: Node = _ensure_test_i18n()
	i18n.set("current_locale", "zh")
	var overlay: MatchIntroOverlay = MatchIntroOverlayScript.new() as MatchIntroOverlay
	root.add_child(overlay)
	await process_frame

	overlay.show_countdown(3.0)
	await process_frame
	var band := overlay.get_node_or_null("MatchIntroBand") as PanelContainer
	var countdown_style := band.get_theme_stylebox("panel") as StyleBoxFlat if band else null
	var countdown_bg := countdown_style.bg_color if countdown_style else Color.TRANSPARENT
	var countdown_border := countdown_style.border_color if countdown_style else Color.TRANSPARENT

	var signal_state: Dictionary = {
		"cancel": false,
		"confirm": false,
		"return_lobby": false,
	}
	overlay.quit_cancelled.connect(func(): signal_state["cancel"] = true)
	overlay.quit_confirmed.connect(func(): signal_state["confirm"] = true)
	overlay.return_lobby_confirmed.connect(func(): signal_state["return_lobby"] = true)

	overlay.show_quit_confirm()
	await process_frame
	_expect(overlay.is_quit_confirm_visible(), "Quit confirmation should become visible")
	_expect(not overlay.is_countdown_visible(), "Quit confirmation should not report countdown visibility")
	var quit_style := band.get_theme_stylebox("panel") as StyleBoxFlat if band else null
	if quit_style:
		_expect(_colors_close(quit_style.bg_color, countdown_bg, 0.001), "Quit confirmation should reuse the countdown HUD background color")
		_expect(_colors_close(quit_style.border_color, countdown_border, 0.001), "Quit confirmation should reuse the countdown HUD border color")
	else:
		failures.append("Quit confirmation should keep the countdown HUD panel style")

	var button_texts: PackedStringArray = overlay.get_quit_confirm_button_texts_for_test()
	_expect(button_texts.size() == 2, "Quit confirmation should expose two buttons for tests")
	if button_texts.size() == 2:
		_expect(button_texts[0] == "取消", "Cancel button should use the requested copy")
		_expect(button_texts[1] == "是的，退出到桌面", "Confirm button should match the reference layout copy")

	overlay.show_quit_confirm(true)
	await process_frame
	button_texts = overlay.get_quit_confirm_button_texts_for_test()
	_expect(button_texts.size() == 3, "Public-room quit confirmation should expose return-lobby between cancel and exit")
	if button_texts.size() == 3:
		_expect(button_texts[1] == String(i18n.call("t", "quit_confirm.return_lobby")), "Return lobby button should use localized copy")

	var cancel_button := overlay.get_node_or_null("MatchIntroBand/MatchIntroContent/QuitConfirmButtonStrip/QuitConfirmButtons/CancelQuitButton") as Button
	var return_lobby_button := overlay.get_node_or_null("MatchIntroBand/MatchIntroContent/QuitConfirmButtonStrip/QuitConfirmButtons/ReturnLobbyButton") as Button
	var confirm_button := overlay.get_node_or_null("MatchIntroBand/MatchIntroContent/QuitConfirmButtonStrip/QuitConfirmButtons/ConfirmQuitButton") as Button
	_expect(cancel_button != null, "Quit confirmation should create a cancel button")
	_expect(return_lobby_button != null, "Public-room quit confirmation should create a return lobby button")
	_expect(confirm_button != null, "Quit confirmation should create a confirm button")
	if return_lobby_button:
		_expect(return_lobby_button.visible, "Return lobby button should become visible for public-room quit confirmation")
		_expect(return_lobby_button.is_connected("pressed", Callable(overlay, "_on_return_lobby_pressed")), "Return lobby button should be connected to the overlay callback")
		overlay.call("_on_return_lobby_pressed")
		await process_frame
		_expect(bool(signal_state.get("return_lobby", false)), "Return lobby callback should emit return_lobby_confirmed")
	if cancel_button:
		_expect(cancel_button.is_connected("pressed", Callable(overlay, "_on_cancel_quit_pressed")), "Cancel button should be connected to the overlay callback")
		overlay.call("_on_cancel_quit_pressed")
		await process_frame
		_expect(bool(signal_state.get("cancel", false)), "Cancel callback should emit quit_cancelled")
	if confirm_button:
		_expect(confirm_button.is_connected("pressed", Callable(overlay, "_on_confirm_quit_pressed")), "Confirm button should be connected to the overlay callback")
		overlay.call("_on_confirm_quit_pressed")
		await process_frame
		_expect(bool(signal_state.get("confirm", false)), "Confirm callback should emit quit_confirmed")

	overlay.show_countdown(3.0)
	await process_frame
	_expect(overlay.is_countdown_visible(), "Countdown mode should still work after showing quit confirmation")
	_expect(not overlay.is_quit_confirm_visible(), "Countdown mode should hide quit confirmation state")
	overlay.queue_free()
	await process_frame


func _test_quit_input_mapping_removed() -> void:
	_expect(not ProjectSettings.has_setting("input/quit"), "Project should not bind Escape to the old quit action")


func _test_escape_routing_is_scene_global() -> void:
	var level_source := FileAccess.get_file_as_string("res://scripts/level.gd")
	var start_index: int = level_source.find("func _handle_escape_pressed() -> bool:")
	var end_index: int = level_source.find("func _handle_card_hotkeys", start_index)
	_expect(start_index >= 0 and end_index > start_index, "Level should expose escape handling before card hotkeys")
	if start_index < 0 or end_index <= start_index:
		return
	var escape_body: String = level_source.substr(start_index, end_index - start_index)
	_expect(not escape_body.contains("game_state != GameState.PREP") and not escape_body.contains("game_state != GameState.PLAY"), "Escape confirmation should not be limited to active match phases")
	_expect(escape_body.contains("main_menu.settings_visible or main_menu.lobby_chat_visible"), "Escape should still defer to menu subpanels before showing quit confirmation")
	_expect(level_source.contains("show_quit_confirm(_is_public_room_client_context())"), "Escape quit prompt should expose return-lobby only in public room context")


func _ensure_test_i18n() -> Node:
	var existing := root.get_node_or_null("I18n")
	if existing:
		return existing
	var i18n := I18nScript.new()
	i18n.name = "I18n"
	root.add_child(i18n)
	return i18n


func _colors_close(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance and absf(a.a - b.a) <= tolerance


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
