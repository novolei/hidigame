extends Node

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	I18n.set_language_setting("en")
	_reset_network_state()
	_test_lobby_id_password()
	_test_host_room_metadata()
	await _test_lobby_ui_state()
	await _test_landing_join_form()
	await _test_level_start_match_path()
	_test_auto_assign_by_hunter_count()

	if failures.is_empty():
		print("[LobbyFlowTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[LobbyFlowTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	Network.players.clear()
	Network.lobby_config = {
		"max_players": 24,
		"lobby_id": "",
		"room_name": "Private Match",
		"steam_lobby_id": "",
		"map": "Warehouse",
		"variant": "Default",
		"condition": "Normal",
		"game_show": "None",
		"match_duration_sec": 600,
		"prep_duration_sec": 120,
		"host_hunter_count": -1,
		"host_stalker_count": -1,
		"auto_balance": true,
		"role_locked": false,
	}


func _test_lobby_id_password() -> void:
	Network.lobby_config["lobby_id"] = "6KZ7"
	_expect(Network.is_lobby_id_valid("6kz7"), "Lobby ID should be case-insensitive")
	_expect(not Network.is_lobby_id_valid("ZZZZ"), "Wrong Lobby ID should be rejected")
	Network.lobby_config["lobby_id"] = ""
	_expect(Network.is_lobby_id_valid(""), "Empty server Lobby ID should allow test/dev joins")


func _test_host_room_metadata() -> void:
	_reset_network_state()
	Network.server_port = 19089
	var host_error = Network.start_host("Bili", "blue", Network.Role.CHAMELEON, "Bili Room", "ab-12")
	_expect(host_error == OK, "Host should start with room metadata")
	if host_error != OK:
		return
	_expect(str(Network.lobby_config.get("room_name", "")) == "Bili Room", "Host should store room name")
	_expect(str(Network.lobby_config.get("lobby_id", "")) == "AB12", "Host should normalize lobby password")
	_expect(Network.is_room_name_valid("bili room"), "Room name should be case-insensitive")
	_expect(not Network.is_room_name_valid("Other Room"), "Wrong room name should be rejected")
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT


func _test_lobby_ui_state() -> void:
	_reset_network_state()
	var ui_peer := ENetMultiplayerPeer.new()
	var peer_error := ui_peer.create_server(19090, Network.MAX_PLAYERS)
	_expect(peer_error == OK, "UI test server peer should start")
	if peer_error != OK:
		return
	Network.multiplayer.multiplayer_peer = ui_peer
	Network.lobby_config.merge({
		"lobby_id": "ABCD",
		"map": "Street Block",
		"variant": "Low Ammo",
		"condition": "Night",
		"game_show": "Chaos Show",
		"match_duration_sec": 900,
		"prep_duration_sec": 60,
		"host_hunter_count": 2,
	}, true)

	var ui_scene: PackedScene = load("res://scenes/ui/main_menu_ui.tscn")
	var ui: MainMenuUI = ui_scene.instantiate()
	get_tree().root.add_child(ui)
	await get_tree().process_frame

	Network.players = {
		1: _player("Host", Network.Role.CHAMELEON),
		2: _player("Guest", Network.Role.NONE),
	}
	ui.show_lobby("ABCD", true)
	ui.update_lobby(Network.players, Network.lobby_config)

	_expect(ui.lobby_id_input.text == "ABCD", "Lobby screen should display host Lobby ID")
	_expect(_selected_value(ui.map_option) == "Street Block", "Level dropdown should follow lobby config")
	_expect(_selected_value(ui.variant_option) == "Low Ammo", "Variant dropdown should follow lobby config")
	_expect(_selected_value(ui.condition_option) == "Night", "Condition dropdown should follow lobby config")
	_expect(_selected_value(ui.game_show_option) == "Chaos Show", "Game Show dropdown should follow lobby config")
	_expect(ui.duration_option.selected == 2, "Duration dropdown should select 15 min")
	_expect(ui.prep_option.selected == 1, "Hide Prep dropdown should select 60 sec")
	_expect(ui.hunter_count_option.selected == 2, "Hunter Count dropdown should select 2 Hunters")
	_expect(_tree_has_button_text(ui, "Host"), "Host player should be visible in player/team lists")
	_expect(_tree_has_button_text(ui, "Guest"), "Joined player should be visible in user list")
	_expect(ui.start_button.disabled, "Start should stay disabled until both Hunter and Prop teams exist")

	Network.players[2]["role"] = Network.Role.HUNTER
	ui.update_lobby(Network.players, Network.lobby_config)
	_expect(not ui.start_button.disabled, "Start should enable when at least one Hunter and one Prop exist")

	ui._select_role(Network.Role.HUNTER)
	_expect(ui.selected_role == Network.Role.HUNTER, "Clicking a team box should choose that team")
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	ui._on_team_panel_input(click_event, Network.Role.STALKER)
	_expect(ui.selected_role == Network.Role.STALKER, "Clicking a team panel should choose that team")
	ui._on_team_panel_input(click_event, Network.Role.SPECTATOR)
	_expect(ui.selected_role == Network.Role.SPECTATOR, "Clicking spectators should choose spectator mode")

	I18n.set_language_setting("zh")
	await get_tree().process_frame
	_expect(ui.players_hint_label.text == I18n.t("teams_ready"), "Language setting should relabel active lobby UI")
	I18n.set_language_setting("en")
	await get_tree().process_frame

	ui.queue_free()
	ui_peer.close()
	Network.multiplayer.multiplayer_peer = null
	await get_tree().process_frame


func _test_landing_join_form() -> void:
	_reset_network_state()
	var ui_scene: PackedScene = load("res://scenes/ui/main_menu_ui.tscn")
	var ui: MainMenuUI = ui_scene.instantiate()
	get_tree().root.add_child(ui)
	await get_tree().process_frame

	var join_result := {
		"count": 0,
		"address": "",
		"lobby_id": "",
		"room_name": "",
	}
	ui.join_pressed.connect(func(_nickname, _skin, address, lobby_id, _role, room_name):
		join_result["count"] = int(join_result["count"]) + 1
		join_result["address"] = address
		join_result["lobby_id"] = lobby_id
		join_result["room_name"] = room_name
	)

	ui.address_input.text = "Bili Room"
	ui.join_lobby_input.text = ""
	ui._on_join_pressed()
	_expect(int(join_result["count"]) == 0, "Join should require Lobby ID/password")
	ui.join_lobby_input.text = "abcd"
	ui._on_lobby_password_text_changed(ui.join_lobby_input.text)
	_expect(ui.get_join_target() == "Bili Room", "Join target field should keep room name")
	_expect(ui.get_lobby_password() == "ABCD", "Join password getter should normalize text")
	_expect(ui._validate_join_request(), "Join validation should pass with room name and password")
	ui._on_join_pressed()
	_expect(int(join_result["count"]) == 1, "Join should emit when target and password are present")
	_expect(str(join_result["address"]) == Network.SERVER_ADDRESS, "Room-name joins should fall back to localhost before Steam lookup")
	_expect(str(join_result["lobby_id"]) == "ABCD", "Join should normalize Lobby ID/password")
	_expect(str(join_result["room_name"]) == "Bili Room", "Join should pass room name separately")

	ui.queue_free()
	await get_tree().process_frame


func _test_level_start_match_path() -> void:
	_reset_network_state()
	Network.server_port = 19092
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(Network.multiplayer.is_server(), "Level test should create a local host peer")
	Network.lobby_config.merge({
		"lobby_id": "PLAY",
		"match_duration_sec": 300,
		"prep_duration_sec": 60,
		"host_hunter_count": 1,
	}, true)
	Network.players = {
		1: _player("Host", Network.Role.CHAMELEON),
		2: _player("Hunter", Network.Role.HUNTER),
	}
	level.main_menu.show_lobby("PLAY", true)

	await level._on_start_match_pressed(Network.lobby_config.duplicate())
	await get_tree().process_frame

	_expect(level.game_state == 1, "Start Match should move Level from LOBBY to PREP")
	_expect(not level.main_menu.visible, "Start Match should hide the lobby UI")
	_expect(int(round(level.prep_remaining)) == 60, "Start Match should use configured hide prep time")
	_expect(Network.get_hunters().size() == 1, "Start Match should keep one configured Hunter")
	_expect(Network.get_props().size() == 1, "Start Match should keep one Prop")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	await get_tree().process_frame


func _test_auto_assign_by_hunter_count() -> void:
	_reset_network_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19091, Network.MAX_PLAYERS)
	_expect(error == OK, "Test server peer should start for auto-assign")
	if error != OK:
		return
	Network.multiplayer.multiplayer_peer = peer
	Network.lobby_config["host_hunter_count"] = 2
	Network.players = {
		1: _player("Host", Network.Role.CHAMELEON),
		2: _player("Player2", Network.Role.HUNTER),
		3: _player("Player3", Network.Role.NONE),
		4: _player("Player4", Network.Role.NONE),
	}

	Network.server_auto_balance_roles()
	_expect(Network.get_hunters().size() == 2, "Auto assign should honor configured Hunter count")
	_expect(Network.get_props().size() == 2, "Auto assign should keep remaining players as props")
	_expect(not bool(Network.lobby_config.get("role_locked", false)), "Auto assign should keep roles editable in lobby")
	Network.request_set_role(Network.Role.STALKER)
	_expect(Network.players[1]["role"] == Network.Role.STALKER, "Manual role selection should work after auto assign")
	Network.request_set_role(Network.Role.SPECTATOR)
	_expect(Network.players[1]["role"] == Network.Role.SPECTATOR, "Spectator should be a selectable lobby role")

	peer.close()
	Network.multiplayer.multiplayer_peer = null


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": Character.SkinColor.BLUE,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
	}


func _selected_value(option: OptionButton):
	return option.get_item_metadata(option.selected)


func _tree_has_button_text(root_node: Node, needle: String) -> bool:
	if root_node is Button and (root_node as Button).text.contains(needle):
		return true
	for child in root_node.get_children():
		if _tree_has_button_text(child, needle):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
