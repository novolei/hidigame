extends Node

const CardDatabaseScript := preload("res://scripts/card_database.gd")
const PlayerCardEffectControllerScript := preload("res://scripts/player_card_effect_controller.gd")

var failures: Array[String] = []


class CardEffectOwnerProbe:
	extends Node

	var _is_dead: bool = false
	var calls: Array[String] = []
	var args_by_method: Dictionary = {}

	func _record(method_name: String, args: Array = []) -> void:
		calls.append(method_name)
		args_by_method[method_name] = args.duplicate()

	func mark_dead_for_test() -> void:
		_is_dead = true

	func is_dead_for_test() -> bool:
		return _is_dead

	func _card_apply_stealth(duration: float) -> void:
		_record("_card_apply_stealth", [duration])

	func _card_apply_emergency_conceal(duration: float) -> void:
		_record("_card_apply_emergency_conceal", [duration])

	func _card_apply_vision_impairment_to_role(target_role: int, radius: float, duration: float, label: String) -> void:
		_record("_card_apply_vision_impairment_to_role", [target_role, radius, duration, label])

	func _card_feedback_to_owner(text: String, color: Color, duration: float) -> void:
		_record("_card_feedback_to_owner", [text, color, duration])


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	_test_role_pools()
	_test_card_i18n_text()
	_test_two_pick_draft_is_unique()
	_test_pick_timeout_auto_selects_card()
	_test_manual_card_use_consumes_slot()
	_test_reactive_card_consumes_once()
	_test_card_effect_controller_routes_player_calls()
	await _test_card_hud_layout()

	if failures.is_empty():
		print("[CardSystemTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[CardSystemTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.players.clear()
	Network.card_drafts.clear()
	Network.card_loadouts.clear()
	Network.set("_card_draft_active", false)
	Network.set("_card_timer_sync_remaining", 0.0)


func _test_role_pools() -> void:
	var prop_pool := CardDatabaseScript.get_pool_for_role(Network.Role.CHAMELEON)
	var stalker_pool := CardDatabaseScript.get_pool_for_role(Network.Role.STALKER)
	var hunter_pool := CardDatabaseScript.get_pool_for_role(Network.Role.HUNTER)
	_expect(prop_pool.size() >= 15, "Prop pool should include the complete first design set")
	_expect(stalker_pool == prop_pool, "Stalker should draw from the shared Prop pool")
	_expect(hunter_pool.size() >= 10, "Hunter pool should include brainstormed counterplay cards")
	for card_id in prop_pool:
		_expect(str(CardDatabaseScript.get_card(card_id).get("team", "")) == CardDatabaseScript.TEAM_PROP, "Prop pool should contain only Prop cards")
	for card_id in hunter_pool:
		_expect(str(CardDatabaseScript.get_card(card_id).get("team", "")) == CardDatabaseScript.TEAM_HUNTER, "Hunter pool should contain only Hunter cards")


func _test_card_i18n_text() -> void:
	_expect(CardDatabaseScript.display_name_for_locale("prop_flashbang", "en") == "Flashbang", "Card English name should resolve from localization table")
	_expect(CardDatabaseScript.display_name_for_locale("prop_flashbang", "zh") == "闪光弹", "Card Chinese name should resolve from localization table")
	_expect(CardDatabaseScript.description_for_locale("hunter_pulse_scan", "en").contains("Reveals"), "Card English description should resolve from localization table")
	_expect(CardDatabaseScript.description_for_locale("hunter_pulse_scan", "zh").contains("侦测"), "Card Chinese description should resolve from localization table")


func _test_two_pick_draft_is_unique() -> void:
	_reset_network_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19220, Network.MAX_PLAYERS)
	_expect(error == OK, "Draft test server peer should start")
	if error != OK:
		return
	Network.multiplayer.multiplayer_peer = peer
	Network.players = {
		1: _player(Network.Role.HUNTER),
		2: _player(Network.Role.CHAMELEON),
	}
	Network.server_start_card_drafts_for_match()
	var first_state := Network.card_drafts.get(1, {}) as Dictionary
	_expect((first_state.get("choices", []) as Array).size() == 3, "First draft should offer 3 cards")
	var first_choice := str((first_state.get("choices", []) as Array)[0])
	Network._server_keep_card(1, first_choice)
	var partial_loadout := Network.card_loadouts.get(1, []) as Array
	_expect(partial_loadout.size() == 1, "First kept card should immediately appear in the card slot loadout")
	var second_state := Network.card_drafts.get(1, {}) as Dictionary
	var second_choices := second_state.get("choices", []) as Array
	_expect(second_choices.size() == 3, "Second draft should offer 3 cards")
	_expect(not second_choices.has(first_choice), "Second draft should exclude the first kept card")
	Network._server_keep_card(1, str(second_choices[0]))
	var final_state := Network.card_drafts.get(1, {}) as Dictionary
	var loadout := Network.card_loadouts.get(1, []) as Array
	_expect(bool(final_state.get("complete", false)), "Draft should complete after two picks")
	_expect(loadout.size() == 2, "Final loadout should contain 2 cards")
	_expect(str((loadout[0] as Dictionary).get("id", "")) != str((loadout[1] as Dictionary).get("id", "")), "Final loadout cards should be different")
	peer.close()
	Network.multiplayer.multiplayer_peer = null


func _test_pick_timeout_auto_selects_card() -> void:
	_reset_network_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19224, Network.MAX_PLAYERS)
	_expect(error == OK, "Timeout draft test server peer should start")
	if error != OK:
		return
	Network.multiplayer.multiplayer_peer = peer
	Network.players = {1: _player(Network.Role.CHAMELEON)}
	Network.server_start_card_drafts_for_match()
	var state := Network.card_drafts.get(1, {}) as Dictionary
	var first_choices := (state.get("choices", []) as Array).duplicate()
	_expect(first_choices.size() == 3, "Timeout test should start with 3 choices")
	state["pick_expires_at_msec"] = Time.get_ticks_msec() - 1
	state["draft_expires_at_msec"] = Time.get_ticks_msec() + 10000
	Network.card_drafts[1] = state
	Network._server_process_card_drafts(0.3)
	var loadout := Network.card_loadouts.get(1, []) as Array
	var second_state := Network.card_drafts.get(1, {}) as Dictionary
	_expect(loadout.size() == 1, "Timed-out pick should auto-select one card into the loadout")
	if loadout.size() == 1:
		_expect(first_choices.has(str((loadout[0] as Dictionary).get("id", ""))), "Auto-selected card should come from the current choices")
	_expect(int(second_state.get("pick_index", 0)) == 2, "Timed-out first pick should advance to pick 2")
	peer.close()
	Network.multiplayer.multiplayer_peer = null


func _test_manual_card_use_consumes_slot() -> void:
	_reset_network_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19221, Network.MAX_PLAYERS)
	_expect(error == OK, "Use test server peer should start")
	if error != OK:
		return
	Network.multiplayer.multiplayer_peer = peer
	Network.players = {1: _player(Network.Role.CHAMELEON)}
	Network.card_loadouts[1] = [
		{"id": "prop_chromatic_burst", "used": false},
		{"id": "prop_silent_steps", "used": false},
	]
	var activated := []
	Network.card_activated.connect(func(peer_id: int, card_id: String, slot_index: int):
		activated.append({"peer_id": peer_id, "card_id": card_id, "slot_index": slot_index})
	, CONNECT_ONE_SHOT)
	Network._server_use_card_slot(1, 0)
	var loadout := Network.card_loadouts.get(1, []) as Array
	_expect(bool((loadout[0] as Dictionary).get("used", false)), "Manual card use should mark the slot used")
	_expect(activated.size() == 1 and str((activated[0] as Dictionary).get("card_id", "")) == "prop_chromatic_burst", "Manual card use should emit activation")
	Network._server_use_card_slot(1, 0)
	_expect(activated.size() == 1, "Used card should not activate twice")
	peer.close()
	Network.multiplayer.multiplayer_peer = null


func _test_reactive_card_consumes_once() -> void:
	_reset_network_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19222, Network.MAX_PLAYERS)
	_expect(error == OK, "Reactive test server peer should start")
	if error != OK:
		return
	Network.multiplayer.multiplayer_peer = peer
	Network.players = {1: _player(Network.Role.CHAMELEON)}
	Network.card_loadouts[1] = [
		{"id": "prop_emergency_conceal", "used": false},
		{"id": "prop_revival", "used": false},
	]
	_expect(Network.server_try_consume_reactive_card(1, "prop_emergency_conceal"), "Reactive card should consume when requested by server")
	_expect(not Network.server_try_consume_reactive_card(1, "prop_emergency_conceal"), "Reactive card should not consume twice")
	Network._server_use_card_slot(1, 1)
	var loadout := Network.card_loadouts.get(1, []) as Array
	_expect(not bool((loadout[1] as Dictionary).get("used", false)), "Manual use path should reject reactive cards")
	peer.close()
	Network.multiplayer.multiplayer_peer = null


func _test_card_effect_controller_routes_player_calls() -> void:
	var probe: CardEffectOwnerProbe = CardEffectOwnerProbe.new()
	var controller: PlayerCardEffectController = PlayerCardEffectControllerScript.new() as PlayerCardEffectController
	controller.initialize(probe)

	controller.apply_card_effect("prop_chromatic_burst")
	_expect(probe.calls == ["_card_apply_stealth"], "Card effect controller should route Chromatic Burst through the player stealth hook")
	var stealth_args: Array = probe.args_by_method.get("_card_apply_stealth", []) as Array
	_expect(stealth_args.size() == 1 and float(stealth_args[0]) >= 1.0, "Card effect controller should pass a clamped stealth duration")

	probe.calls.clear()
	probe.args_by_method.clear()
	controller.apply_card_effect("prop_emergency_conceal")
	_expect(probe.calls == ["_card_apply_emergency_conceal"], "Card effect controller should keep emergency health/state logic behind the player facade")

	probe.calls.clear()
	probe.args_by_method.clear()
	controller.apply_card_effect("prop_flashbang")
	_expect(probe.calls == ["_card_apply_vision_impairment_to_role"], "Card effect controller should route role-targeted vision effects through one player hook")
	var flash_args: Array = probe.args_by_method.get("_card_apply_vision_impairment_to_role", []) as Array
	_expect(flash_args.size() == 4 and int(flash_args[0]) == Network.Role.HUNTER and str(flash_args[3]) == "FLASH", "Flashbang should target Hunters with the FLASH label")

	probe.calls.clear()
	probe.args_by_method.clear()
	probe.mark_dead_for_test()
	_expect(probe.is_dead_for_test(), "Card effect owner probe should expose the dead state used by the controller")
	controller.apply_card_effect("hunter_pulse_scan")
	_expect(probe.calls == ["_card_feedback_to_owner"], "Dead players should receive spectator feedback instead of executing card effects")
	var dead_feedback_args: Array = probe.args_by_method.get("_card_feedback_to_owner", []) as Array
	_expect(dead_feedback_args.size() >= 1 and str(dead_feedback_args[0]) == "SPECTATING", "Dead card feedback should use the spectator message")

	probe.queue_free()


func _test_card_hud_layout() -> void:
	var hud := CardHUD.new()
	hud.size = Vector2(1920.0, 1080.0)
	get_tree().root.add_child(hud)
	await get_tree().process_frame
	hud.set_draft_state({
		"role": Network.Role.CHAMELEON,
		"pick_index": 1,
		"choices": ["prop_chromatic_burst", "prop_micro_form", "prop_flashbang"],
		"kept": [],
		"complete": false,
	})
	await get_tree().process_frame
	_expect(hud.is_drafting_active(), "CardHUD should expose active drafting state")
	_expect(hud.get("_draft_cards").size() == 3, "CardHUD should create 3 draft cards")
	hud.set_loadout([
		{"id": "prop_chromatic_burst", "used": false},
		{"id": "prop_emergency_conceal", "used": false},
	])
	await get_tree().process_frame
	var slot_cards := hud.get("_slot_cards") as Array
	_expect(slot_cards.size() == 2, "CardHUD should create 2 card slots")
	if slot_cards.size() == 2:
		var first := slot_cards[0] as Control
		var second := slot_cards[1] as Control
		var canvas_size := hud.call("_get_canvas_size") as Vector2
		_expect(first.position.x < 80.0, "Card slots should live near the left edge")
		_expect(first.position.y + first.size.y > canvas_size.y - 80.0, "Card slots should live in the lower-left corner")
		_expect(second.position.y < first.position.y, "Second left-side slot should mirror SkillHUD's diagonal distribution")
		_expect(str(first.get("key_text")) == "E", "First card slot should use E as its hotkey")
		_expect(str(second.get("key_text")) == "R", "Second card slot should use R as its hotkey")
		_expect(hud.toggle_detail_panel(), "CardHUD should toggle bilingual detail panel for the loadout")
		_expect(hud.is_detail_visible(), "Card detail panel should become visible after toggling")
		_expect(hud.toggle_detail_panel(), "CardHUD should close the detail panel on second toggle")
	_expect(hud.choose_by_index(0), "CardHUD should allow choosing a draft card by index")
	hud.queue_free()
	await get_tree().process_frame


func _player(role: int) -> Dictionary:
	return {
		"nick": "Test",
		"role": role,
		"alive": true,
		"role_locked": true,
	}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
