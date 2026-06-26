extends Node

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	I18n.set_language_setting("en")
	_reset_network_state()
	_test_lobby_id_password()
	_test_host_room_metadata()
	_test_public_room_server_uses_empty_lobby_id()
	_test_public_room_detached_launch_helpers()
	_test_public_room_redirect_waits_for_room_sync()
	_test_host_port_fallback_when_default_is_busy()
	_test_join_address_port_parsing()
	await _test_lobby_ui_state()
	await _test_landing_join_form()
	await _test_public_lobby_room_list_ui()
	await _test_public_room_wrong_password_hud_alert()
	await _test_client_join_waits_for_full_sync_before_lobby()
	await _test_player_replication_budget()
	await _test_level_start_match_path()
	await _test_hunter_preparation_slots_are_separated()
	await _test_preparation_room_legacy_colliders_stay_disabled()
	await _test_preparation_room_hides_after_prep_phase()
	await _test_client_full_sync_waits_until_prep_to_spawn_player_nodes()
	await _test_room_events_enter_chat_history()
	await _test_single_player_character_test_start()
	_test_auto_balance_preserves_selected_stalker_in_two_player_lobby()
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
		Network._close_current_peer()
	Network.server_port = Network.SERVER_PORT
	Network.players.clear()
	Network.public_rooms.clear()
	Network.peer_rooms.clear()
	Network.active_public_room_id = ""
	Network.card_drafts.clear()
	Network.card_loadouts.clear()
	Network.set("_card_draft_active", false)
	Network.set("_card_timer_sync_remaining", 0.0)
	Network.set("_redirecting_to_public_room", false)
	Network.lobby_config = {
		"max_players": 24,
		"lobby_id": "",
		"room_name": "Private Match",
		"steam_lobby_id": "",
		"host_port": Network.SERVER_PORT,
		"map": "Warehouse",
		"variant": "Default",
		"condition": "Normal",
		"game_show": "None",
		"gravity_mps2": 9.8,
		"low_gravity_events": true,
		"match_duration_sec": 600,
		"prep_duration_sec": 30,
		"host_hunter_count": -1,
		"host_stalker_count": -1,
		"stalker_glass_alpha_max": 0.125,
		"stalker_glass_material": "classic",
		"auto_balance": true,
		"public_server": false,
		"public_lobby": false,
		"public_room_id": "",
		"public_address": "",
		"host_peer_id": 1,
		"host_peer_name": "",
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
	var host_error = Network.start_host("Bili", "blue", Network.Role.CHAMELEON, "Bili Room", "ab-12", "gdbot")
	_expect(host_error == OK, "Host should start with room metadata")
	if host_error != OK:
		return
	_expect(str(Network.lobby_config.get("room_name", "")) == "Bili Room", "Host should store room name")
	_expect(str(Network.lobby_config.get("lobby_id", "")) == "AB12", "Host should normalize lobby password")
	_expect(str(Network.player_info.get("character_model", "")) == "gdbot", "Host should store selected character model")
	_expect(Network.is_room_name_valid("bili room"), "Room name should be case-insensitive")
	_expect(not Network.is_room_name_valid("Other Room"), "Wrong room name should be rejected")
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT


func _test_public_room_server_uses_empty_lobby_id() -> void:
	_reset_network_state()
	var host_error = Network.start_public_room_server("Public Room", "", 19109, "public-room")
	_expect(host_error == OK, "Public room server should start without a lobby password")
	_expect(str(Network.lobby_config.get("lobby_id", "")) == "", "Public room server should keep an empty lobby id for optional-password rooms")
	_expect(bool(Network.lobby_config.get("public_server", false)), "Public room server should mark the room as public-server backed")
	_expect(not bool(Network.lobby_config.get("public_lobby", true)), "Public room server should not mark itself as the public lobby")
	_expect(str(Network.lobby_config.get("public_room_id", "")) == "public-room", "Public room server should store the room id")
	_expect(int(Network.lobby_config.get("host_port", -1)) == 19109, "Public room server should publish its assigned port")
	_expect(int(Network.lobby_config.get("host_peer_id", -1)) == 0, "Public room server should wait for the first joining player to become room host")
	var status_path := Network._public_room_status_path("public-room")
	var starting_status = JSON.parse_string(FileAccess.get_file_as_string(status_path))
	_expect(starting_status is Dictionary and not bool((starting_status as Dictionary).get("ready", true)), "Public room should not advertise ready until the level runtime finishes setup")
	Network.mark_public_room_runtime_ready()
	var ready_status = JSON.parse_string(FileAccess.get_file_as_string(status_path))
	_expect(ready_status is Dictionary and bool((ready_status as Dictionary).get("ready", false)), "Public room should advertise ready after the level runtime marks it joinable")
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT


func _test_public_room_detached_launch_helpers() -> void:
	_reset_network_state()
	var previous_launch_mode := OS.get_environment(Network.PUBLIC_ROOM_LAUNCH_MODE_ENV)
	OS.set_environment(Network.PUBLIC_ROOM_LAUNCH_MODE_ENV, Network.PUBLIC_ROOM_LAUNCH_MODE_CHILD)
	_expect(Network._public_lobby_room_launch_mode() == Network.PUBLIC_ROOM_LAUNCH_MODE_CHILD, "Explicit child launch mode should use direct create_process spawning")
	OS.set_environment(Network.PUBLIC_ROOM_LAUNCH_MODE_ENV, Network.PUBLIC_ROOM_LAUNCH_MODE_DETACHED)
	var expected_detached_mode := Network.PUBLIC_ROOM_LAUNCH_MODE_DETACHED if Network._public_lobby_can_use_unix_shell() else Network.PUBLIC_ROOM_LAUNCH_MODE_CHILD
	_expect(Network._public_lobby_room_launch_mode() == expected_detached_mode, "Detached launch mode should only activate when a Unix shell is available")
	_expect(Network._shell_quote_argument("Alpha's Room") == "'Alpha'\"'\"'s Room'", "Shell quoting should preserve single quotes safely")
	var args := Network._public_lobby_room_process_args("alpha-room", "Alpha Room", "LOCK", 18081)
	_expect(args.has("--maomao-room-server"), "Room process args should launch a public room server")
	_expect(args.has("--room-id") and args[args.find("--room-id") + 1] == "alpha-room", "Room process args should include the room id")
	_expect(args.has("--room-name") and args[args.find("--room-name") + 1] == "Alpha Room", "Room process args should include the human room name")
	_expect(args.has("--lobby-password") and args[args.find("--lobby-password") + 1] == "LOCK", "Room process args should include the optional room password")
	_expect(args.has("--port") and args[args.find("--port") + 1] == "18081", "Room process args should include the allocated room port")
	if previous_launch_mode.is_empty():
		OS.unset_environment(Network.PUBLIC_ROOM_LAUNCH_MODE_ENV)
	else:
		OS.set_environment(Network.PUBLIC_ROOM_LAUNCH_MODE_ENV, previous_launch_mode)


func _test_public_room_redirect_waits_for_room_sync() -> void:
	_reset_network_state()
	Network.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Network.set("_redirecting_to_public_room", true)
	Network._on_server_disconnected()
	_expect(Network.is_redirecting_to_public_room(), "A stale public-lobby disconnect should not cancel an in-flight public room redirect")

	var room_config := Network.lobby_config.duplicate(true)
	room_config.merge({
		"public_server": true,
		"public_lobby": false,
		"public_room_id": "alpha-room",
		"room_name": "Alpha Room",
		"lobby_id": "",
	}, true)
	Network._broadcast_full_sync({
		2: _player("Client", Network.Role.HUNTER),
	}, room_config)
	_expect(not Network.is_redirecting_to_public_room(), "A public room full sync should mark the redirect as complete")
	Network.multiplayer.multiplayer_peer = null


func _test_host_port_fallback_when_default_is_busy() -> void:
	_reset_network_state()
	var blocker := ENetMultiplayerPeer.new()
	var blocked_port := 19100
	var block_error := blocker.create_server(blocked_port, Network.MAX_PLAYERS)
	_expect(block_error == OK, "Fallback test should reserve the first host port")
	if block_error != OK:
		return
	Network.server_port = blocked_port
	var host_error = Network.start_host("FallbackHost", "blue", Network.Role.CHAMELEON, "Fallback Room", "fp-01", "gdbot")
	_expect(host_error == OK, "Host should start on a fallback port when the requested port is busy")
	_expect(Network.server_port == blocked_port + 1, "Host should advance to the next available fallback port")
	_expect(int(Network.lobby_config.get("host_port", -1)) == Network.server_port, "Lobby config should publish the actual host port")
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	blocker.close()
	Network.server_port = Network.SERVER_PORT


func _test_join_address_port_parsing() -> void:
	_reset_network_state()
	var port := 19102
	var endpoint := Network._normalize_join_endpoint("127.0.0.1:%d" % port)
	_expect(str(endpoint.get("address", "")) == "127.0.0.1", "Join should strip the port from the ENet host address")
	_expect(int(endpoint.get("port", -1)) == port, "Join should parse host:port addresses")
	var ipv6_endpoint := Network._normalize_join_endpoint("[::1]:19103")
	_expect(str(ipv6_endpoint.get("address", "")) == "::1", "Join should support bracketed IPv6 host:port addresses")
	_expect(int(ipv6_endpoint.get("port", -1)) == 19103, "Join should parse bracketed IPv6 ports")
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
		"stalker_glass_alpha_max": 0.16,
		"stalker_glass_material": "liquid_glass",
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
	_expect(absf(float(_selected_value(ui.stalker_glass_option)) - 0.16) < 0.001, "Stalker invisibility dropdown should follow lobby config")
	_expect(str(_selected_value(ui.stalker_glass_material_option)) == "liquid_glass", "Stalker cloak dropdown should follow lobby config")
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
	ui.stalker_glass_option.select(2)
	ui.stalker_glass_material_option.select(0)
	_expect(absf(float(ui.get_host_config().get("stalker_glass_alpha_max", 0.0)) - 0.125) < 0.001, "Host config should publish Stalker invisibility strength")
	_expect(str(ui.get_host_config().get("stalker_glass_material", "")) == "classic", "Host config should publish Stalker cloak material mode")

	I18n.set_language_setting("zh")
	await get_tree().process_frame
	_expect(ui.players_hint_label.text == I18n.t("single_player_test_ready"), "Language setting should relabel active solo-test lobby UI")
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
		"character_model": "",
	}
	var public_result := {
		"count": 0,
		"character_model": "",
	}
	if ui.character_option:
		for index in range(ui.character_option.item_count):
			if str(ui.character_option.get_item_metadata(index)) == "sophia":
				ui.character_option.select(index)
				break
	ui.join_pressed.connect(func(_nickname, _skin, address, lobby_id, _role, room_name, character_model):
		join_result["count"] = int(join_result["count"]) + 1
		join_result["address"] = address
		join_result["lobby_id"] = lobby_id
		join_result["room_name"] = room_name
		join_result["character_model"] = character_model
	)
	ui.public_server_pressed.connect(func(_nickname, _skin, _role, character_model):
		public_result["count"] = int(public_result["count"]) + 1
		public_result["character_model"] = character_model
	)

	ui.address_input.text = "Bili Room"
	ui.join_lobby_input.text = ""
	ui._on_join_pressed()
	_expect(int(join_result["count"]) == 1, "Join should allow an empty optional Lobby ID/password")
	_expect(str(join_result["lobby_id"]) == "", "Join should pass an empty optional Lobby ID/password")
	ui.join_lobby_input.text = "abcd"
	ui._on_lobby_password_text_changed(ui.join_lobby_input.text)
	_expect(ui.get_join_target() == "Bili Room", "Join target field should keep room name")
	_expect(ui.get_lobby_password() == "ABCD", "Join password getter should normalize text")
	_expect(ui._validate_join_request(), "Join validation should pass with room name and optional password")
	ui._on_join_pressed()
	_expect(int(join_result["count"]) == 2, "Join should emit when target and password are present")
	_expect(str(join_result["address"]) == Network.SERVER_ADDRESS, "Room-name joins should fall back to localhost before Steam lookup")
	_expect(str(join_result["lobby_id"]) == "ABCD", "Join should normalize Lobby ID/password")
	_expect(str(join_result["room_name"]) == "Bili Room", "Join should pass room name separately")
	_expect(str(join_result["character_model"]) == "sophia", "Join should pass selected character model")

	ui.room_name_input.text = "Public Room"
	ui.join_lobby_input.text = "lock"
	ui._on_lobby_password_text_changed(ui.join_lobby_input.text)
	ui._on_public_server_pressed()
	_expect(int(join_result["count"]) == 2, "Public server button should not emit a direct join request")
	_expect(int(public_result["count"]) == 1, "Public server button should emit a public lobby request")
	_expect(str(public_result["character_model"]) == "sophia", "Public lobby request should keep selected character model")
	_expect(ui.address_input.text == MainMenuUI.PUBLIC_SERVER_TARGET, "Public server should display the configured public address")

	ui.queue_free()
	await get_tree().process_frame


func _test_public_lobby_room_list_ui() -> void:
	_reset_network_state()
	var ui_scene: PackedScene = load("res://scenes/ui/main_menu_ui.tscn")
	var ui: MainMenuUI = ui_scene.instantiate()
	get_tree().root.add_child(ui)
	await get_tree().process_frame

	var create_result := {"count": 0, "room_name": "", "password": ""}
	var join_result := {"count": 0, "room_id": "", "password": ""}
	ui.public_room_create_pressed.connect(func(room_name, password):
		create_result["count"] = int(create_result["count"]) + 1
		create_result["room_name"] = room_name
		create_result["password"] = password
	)
	ui.public_room_join_pressed.connect(func(room_id, password):
		join_result["count"] = int(join_result["count"]) + 1
		join_result["room_id"] = room_id
		join_result["password"] = password
	)

	var rooms := [{
		"room_id": "alpha-room",
		"room_name": "Alpha Room",
		"locked": true,
		"player_count": 1,
		"max_players": 24,
		"host_peer_name": "HostA",
		"ready": true,
	}]
	ui.show_public_lobby(rooms, I18n.t("public_lobby.connected"))
	await get_tree().process_frame
	_expect(ui.is_public_lobby_visible(), "Public lobby UI should be visible after entering the public server")
	_expect(ui.public_lobby_rooms.size() == 1, "Public lobby UI should store the server room list")
	_expect(ui.public_room_join_button.disabled, "Join selected button should be disabled before selecting a room")
	var locked_row := ui.public_room_list_box.get_child(0) as Button
	_expect(locked_row != null and locked_row.icon != null, "Private public rooms should show a lock icon")

	ui._select_public_room("alpha-room")
	await get_tree().process_frame
	_expect(ui.selected_public_room_id == "alpha-room", "Public lobby should store the selected room id")
	_expect(not ui.public_room_join_button.disabled, "Join selected button should enable after selecting a room")
	var selected_row := ui.public_room_list_box.get_child(0) as Button
	var selected_style := selected_row.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(selected_style != null and selected_style.bg_color.v < 0.4, "Selected public room row should keep readable dark styling")
	ui._on_public_room_join_pressed()
	_expect(int(join_result["count"]) == 0, "Private public rooms should require a password before emitting join")
	_expect(ui.public_lobby_alert_text == I18n.t("public_lobby.password_needed"), "Empty private room password should show a public lobby HUD alert")
	ui.public_room_join_password_input.text = "lock"
	ui._on_public_room_join_pressed()
	_expect(int(join_result["count"]) == 1, "Joining a selected public room should emit a room join request")
	_expect(ui.public_lobby_loading_text == I18n.t("join_status.connecting_room"), "Joining a public room should show the centered loading panel")
	_expect(str(join_result["room_id"]) == "alpha-room", "Public room join should pass the selected room id")
	_expect(str(join_result["password"]) == "LOCK", "Public room join password should normalize to uppercase")
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	ui._on_public_room_row_gui_input(double_click, "alpha-room")
	await get_tree().process_frame
	_expect(int(join_result["count"]) == 1, "Double-clicking while join is pending should not emit another join request")
	ui.hide_public_lobby_loading()
	ui._on_public_room_row_gui_input(double_click, "alpha-room")
	await get_tree().process_frame
	_expect(int(join_result["count"]) == 2, "Double-clicking a public room row should join it when the lobby is idle")
	ui.hide_public_lobby_loading()

	ui.public_room_create_name_input.text = "Beta Room"
	ui.public_room_create_password_input.text = "key"
	ui._on_public_room_create_pressed()
	_expect(int(create_result["count"]) == 1, "Creating a public room should emit a create request")
	_expect(ui.public_lobby_loading_text == I18n.t("public_lobby.creating"), "Creating a public room should show the centered loading panel")
	ui._on_public_room_create_pressed()
	_expect(int(create_result["count"]) == 1, "Creating while a public room request is pending should not emit another create request")
	_expect(str(create_result["room_name"]) == "Beta Room", "Public room create should pass the requested room name")
	_expect(str(create_result["password"]) == "KEY", "Public room create password should normalize to uppercase")

	ui.queue_free()
	await get_tree().process_frame


func _test_public_room_wrong_password_hud_alert() -> void:
	_reset_network_state()
	Network.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	level.main_menu.show_public_lobby([{
		"room_id": "locked-room",
		"room_name": "Locked Room",
		"locked": true,
		"player_count": 1,
		"max_players": 24,
		"host_peer_name": "HostA",
		"ready": true,
	}], I18n.t("public_lobby.connected"))
	level.main_menu.show_public_lobby_loading(I18n.t("join_status.connecting_room"))
	level._on_public_room_join_failed("join_status.wrong_password")
	await get_tree().process_frame
	_expect(level.main_menu.public_lobby_loading_text.is_empty(), "Wrong password should clear the public lobby loading panel")
	_expect(level.main_menu.public_lobby_alert_text == I18n.t("public_lobby.password_problem"), "Wrong password should show a public lobby HUD alert")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	Network.multiplayer.multiplayer_peer = null


func _test_client_join_waits_for_full_sync_before_lobby() -> void:
	_reset_network_state()
	Network.server_port = 19108
	Network.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	level.main_menu.show_landing()
	level._join_lobby_direct("Client", "yellow", "127.0.0.1", "SYNC", Network.Role.HUNTER, "", CharacterSkinCatalog.DEFAULT_ID)
	await get_tree().process_frame
	_expect(not level.main_menu.lobby_visible, "Client join should wait for authoritative full sync before showing the lobby")
	_expect(bool(level.pending_direct_join_waiting_for_sync), "Client join should mark lobby sync as pending")

	var synced_config := Network.lobby_config.duplicate(true)
	synced_config["lobby_id"] = "SYNC"
	var synced_players := {
		1: _player("Host", Network.Role.CHAMELEON),
		2: _player("Client", Network.Role.HUNTER),
	}
	Network._broadcast_full_sync(synced_players, synced_config)
	await get_tree().process_frame
	_expect(level.main_menu.lobby_visible, "Client should enter lobby after receiving authoritative full sync")
	_expect(level.main_menu.current_lobby_id == "SYNC", "Client lobby should use the synced lobby id")
	_expect(not bool(level.pending_direct_join_waiting_for_sync), "Client join should clear the pending sync flag after lobby opens")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	await get_tree().process_frame


func _test_player_replication_budget() -> void:
	_reset_network_state()
	Network.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var player: Node = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame

	var synchronizer: MultiplayerSynchronizer = player.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	_expect(synchronizer != null, "Player scene should keep a MultiplayerSynchronizer")
	if synchronizer:
		_expect(absf(synchronizer.replication_interval - 0.08) <= 0.001, "Player replication should use the 12.5Hz public-server budget")
		_expect(absf(synchronizer.delta_interval - 0.16) <= 0.001, "Player delta replication should use the 0.16s budget")
		var config: SceneReplicationConfig = synchronizer.replication_config as SceneReplicationConfig
		_expect(config != null, "Player synchronizer should keep a replication config")
		if config:
			var position_path := NodePath(".:position")
			var nickname_path := NodePath("PlayerNick/Nickname:text")
			var animation_path := NodePath("3DGodotRobot/AnimationPlayer:current_animation")
			var rotation_path := NodePath("3DGodotRobot:rotation")
			_expect(config.has_property(position_path), "Player position should remain network synchronized")
			_expect(config.property_get_sync(position_path), "Player position should sync after spawn")
			_expect(config.has_property(nickname_path), "Player nickname should remain in spawn state")
			_expect(config.property_get_spawn(nickname_path), "Player nickname should be sent on spawn")
			_expect(not config.property_get_sync(nickname_path), "Player nickname should not sync every network frame")
			_expect(not config.has_property(animation_path), "Remote player animation should be inferred locally, not synchronized every frame")
			_expect(not config.has_property(rotation_path), "Remote player facing should be inferred locally, not synchronized every frame")

	player.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null


func _test_level_start_match_path() -> void:
	_reset_network_state()
	Network.server_port = 19092
	var host_error = Network.start_host("Host", "blue", Network.Role.CHAMELEON, "PLAY", "", CharacterSkinCatalog.party_monster_default_id())
	_expect(host_error == OK, "Level test should start a local host peer")
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
		"gravity_mps2": 14.7,
	}, true)
	Network.players = {
		1: _player("Host", Network.Role.CHAMELEON),
		2: _player("Hunter", Network.Role.HUNTER),
	}
	level.main_menu.show_lobby("PLAY", true)

	await level._on_start_match_pressed(Network.lobby_config.duplicate())
	await get_tree().process_frame

	_expect(level.game_state == level.GameState.CARD_DRAFT, "Start Match should move Level from LOBBY to card drafting")
	_expect(not level.main_menu.visible, "Start Match should hide the lobby UI")
	_expect(int(round(level.prep_remaining)) == 0, "Card drafting should not consume hide prep time")
	_expect(Network.get_hunters().size() == 1, "Start Match should keep one configured Hunter")
	_expect(Network.get_props().size() == 1, "Start Match should keep one Prop")
	_finish_all_card_drafts()
	await get_tree().process_frame
	_expect(level.game_state == level.GameState.SKIN_CONFIG, "Card draft completion should start skin configuration")
	_expect(int(ceil(level.skin_config_remaining)) == 20, "Skin configuration should start with a 20 second countdown")
	_expect(CharacterSkinCatalog.is_party_monster(str(Network.players[1].get("character_model", ""))), "Prop players should receive a Party Monster default skin")
	level._process(Network.SKIN_CONFIG_TOTAL_SECONDS + 0.1)
	await get_tree().process_frame
	_expect(level.game_state == level.GameState.MATCH_INTRO, "Skin configuration completion should start the global match intro countdown")
	_expect(int(ceil(level.match_intro_remaining)) == 3, "Match intro should start with a 3 second countdown")
	level._process(level.MATCH_INTRO_DURATION + 0.1)
	await get_tree().process_frame
	_expect(level.game_state == level.GameState.PREP, "Match intro completion should start hide prep")
	_expect(int(round(level.prep_remaining)) == 60, "Prep should start with the full configured hide time after drafting")
	level._apply_configured_gravity()
	_expect(absf(level.active_gravity_mps2 - 14.7) < 0.01, "Level should apply configured lobby gravity")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	await get_tree().process_frame


func _test_client_full_sync_waits_until_prep_to_spawn_player_nodes() -> void:
	_reset_network_state()
	Network.server_port = 19094
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var synced_players := {
		1: _player("Host", Network.Role.HUNTER),
		2: _player("StalkerClient", Network.Role.STALKER),
	}
	Network._broadcast_full_sync(synced_players, Network.lobby_config.duplicate())
	await get_tree().process_frame

	var players_container: Node = level.get_node("PlayersContainer")
	_expect(not players_container.has_node("2"), "Client full sync should not spawn player nodes while the lobby is still open")

	level.game_state = level.GameState.SKIN_CONFIG
	level._ensure_player_nodes_from_network()
	await get_tree().process_frame
	_expect(not players_container.has_node("2"), "Skin selection should not spawn player nodes before the start countdown")

	level.game_state = level.GameState.MATCH_INTRO
	level._ensure_player_nodes_from_network()
	await get_tree().process_frame
	_expect(not players_container.has_node("2"), "The 3 second match intro countdown should not spawn player nodes early")

	level._on_prep_phase_started(30.0)
	await get_tree().process_frame
	_expect(players_container.has_node("2"), "Prep start should spawn synced player nodes after skin selection and match intro")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	await get_tree().process_frame


func _test_room_events_enter_chat_history() -> void:
	_reset_network_state()
	Network.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var system_nick := I18n.t("room_event.system")
	var joined_text := I18n.tf("room_event.joined", ["Guest"])
	var left_text := I18n.tf("room_event.left", ["Guest"])
	level._handle_room_player_joined(2, _player("Guest", Network.Role.HUNTER))
	await get_tree().process_frame
	_expect(_lobby_chat_contains(level.main_menu, system_nick, joined_text), "Room join event should be recorded in the lobby chat history")
	_expect(_game_chat_contains(level.multiplayer_chat, system_nick, joined_text), "Room join event should be recorded in the in-game chat history")

	level._on_network_player_disconnected(2)
	await get_tree().process_frame
	_expect(_lobby_chat_contains(level.main_menu, system_nick, left_text), "Room leave event should be recorded in the lobby chat history")
	_expect(_game_chat_contains(level.multiplayer_chat, system_nick, left_text), "Room leave event should be recorded in the in-game chat history")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	Network.multiplayer.multiplayer_peer = null


func _test_hunter_preparation_slots_are_separated() -> void:
	_reset_network_state()
	Network.server_port = 19096
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	Network.players = {}
	for pid in range(2, 10):
		Network.players[pid] = _player("Hunter%d" % pid, Network.Role.HUNTER)

	var slots: Array[Marker3D] = level._get_preparation_room_hunter_slots()
	_expect(slots.size() >= 16, "Hunter preparation room should expose at least 16 spawn slots")

	var positions: Array[Vector3] = []
	for pid in range(2, 10):
		positions.append(level.get_spawn_point_for_role(Network.Role.HUNTER, pid))
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			_expect(positions[i].distance_to(positions[j]) >= 3.5, "Hunter preparation spawns should not overlap")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	await get_tree().process_frame


func _test_preparation_room_legacy_colliders_stay_disabled() -> void:
	_reset_network_state()
	Network.server_port = 19097
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var prep_room: Node3D = level.get_node("PreparationRoom") as Node3D
	var legacy_collider_paths: Array[String] = [
		"WallNorth/CollisionShape3D",
		"WallSouth/CollisionShape3D",
		"WallEast/CollisionShape3D",
		"WallWest/CollisionShape3D",
		"Gate/CollisionShape3D",
	]
	for collider_path in legacy_collider_paths:
		var shape: CollisionShape3D = prep_room.get_node(collider_path) as CollisionShape3D
		_expect(shape.disabled, "Legacy preparation collider should be disabled in the scene: %s" % collider_path)

	level._set_preparation_room_active(true)
	level._set_preparation_gate_open(false)
	await get_tree().process_frame
	for collider_path in legacy_collider_paths:
		var shape: CollisionShape3D = prep_room.get_node(collider_path) as CollisionShape3D
		_expect(shape.disabled, "Legacy preparation collider should not re-enable at runtime: %s" % collider_path)
	var fence_shape: CollisionShape3D = prep_room.get_node("HunterHomeDecor/ArenaCircularFence00/CollisionShape3D") as CollisionShape3D
	_expect(fence_shape != null and not fence_shape.disabled, "Circular arena fence collision should remain active during prep")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	await get_tree().process_frame


func _test_preparation_room_hides_after_prep_phase() -> void:
	_reset_network_state()
	Network.server_port = 19098
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	Network.players = {
		1: _player("Host", Network.Role.CHAMELEON),
		2: _player("Hunter", Network.Role.HUNTER),
	}
	var prep_room: Node3D = level.get_node("PreparationRoom") as Node3D
	level.game_state = level.GameState.PREP
	level._set_preparation_room_active(true)
	await get_tree().process_frame
	_expect(prep_room.visible, "Preparation room should be visible during prep")

	level._on_prep_phase_ended()
	await get_tree().process_frame
	_expect(not prep_room.visible, "Preparation room should hide after hide prep ends")
	var fence_shape: CollisionShape3D = prep_room.get_node("HunterHomeDecor/ArenaCircularFence00/CollisionShape3D") as CollisionShape3D
	_expect(fence_shape != null and fence_shape.disabled, "Preparation room collisions should be disabled after hide prep ends")

	level.set_process(false)
	level.queue_free()
	await get_tree().process_frame
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.server_port = Network.SERVER_PORT
	await get_tree().process_frame


func _test_single_player_character_test_start() -> void:
	_reset_network_state()
	Network.server_port = 19093
	var host_error = Network.start_host("Solo", "blue", Network.Role.NONE, "SOLO", "", CharacterSkinCatalog.party_monster_default_id())
	_expect(host_error == OK, "Single-player character test should start a local host peer")
	var level_scene: PackedScene = load("res://scenes/level/level.tscn")
	var level = level_scene.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	Network.players = {
		1: _player("Solo", Network.Role.NONE),
	}
	level.main_menu.show_lobby("SOLO", true)
	level.main_menu.update_lobby(Network.players, Network.lobby_config)
	_expect(not level.main_menu.start_button.disabled, "Single-player character test should allow Start Match")
	_expect(level.main_menu.players_hint_label.text == I18n.t("single_player_test_ready"), "Single-player test should show explicit lobby hint")

	await level._on_start_match_pressed(Network.lobby_config.duplicate())
	await get_tree().process_frame

	_expect(level.game_state == level.GameState.CARD_DRAFT, "Single-player test should enter card drafting before PREP")
	_expect(Network.players[1]["role"] == Network.Role.CHAMELEON, "Single-player test should auto fallback to Chameleon")
	_expect(Network.get_props().size() == 1, "Single-player test should count the solo player as a prop")
	_finish_all_card_drafts()
	await get_tree().process_frame
	_expect(level.game_state == level.GameState.SKIN_CONFIG, "Single-player card draft completion should enter skin configuration")
	_expect(CharacterSkinCatalog.is_party_monster(str(Network.players[1].get("character_model", ""))), "Single-player prop should receive a Party Monster default skin")
	level._process(Network.SKIN_CONFIG_TOTAL_SECONDS + 0.1)
	await get_tree().process_frame
	_expect(level.game_state == level.GameState.MATCH_INTRO, "Single-player skin configuration should enter the match intro countdown")
	level._process(level.MATCH_INTRO_DURATION + 0.1)
	await get_tree().process_frame
	_expect(level.game_state == level.GameState.PREP, "Single-player match intro completion should enter PREP")

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


func _test_auto_balance_preserves_selected_stalker_in_two_player_lobby() -> void:
	_reset_network_state()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19095, Network.MAX_PLAYERS)
	_expect(error == OK, "Test server peer should start for selected Stalker balance")
	if error != OK:
		return
	Network.multiplayer.multiplayer_peer = peer
	Network.players = {
		1: _player("HostHunter", Network.Role.HUNTER),
		2: _player("ClientStalker", Network.Role.STALKER),
	}

	Network.server_auto_balance_roles(true)
	_expect(Network.players[2]["role"] == Network.Role.STALKER, "Start Match should preserve a client-selected Stalker in a two-player lobby")
	_expect(Network.get_hunters().size() == 1, "Two-player lobby should still keep one Hunter")
	_expect(Network.get_stalkers().size() == 1, "Two-player lobby should allow its only Prop to be Stalker")
	_expect(Network.get_chameleons().is_empty(), "Selected Stalker should not be converted to Chameleon/Hider")
	_expect(bool(Network.players[2].get("role_locked", false)), "Start Match should lock the preserved Stalker role")

	peer.close()
	Network.multiplayer.multiplayer_peer = null


func _finish_all_card_drafts() -> void:
	var safety := 0
	while safety < 12:
		safety += 1
		var advanced := false
		for pid in Network.card_drafts.keys():
			var peer_id := int(pid)
			var state := Network.card_drafts.get(peer_id, {}) as Dictionary
			if state.is_empty() or bool(state.get("complete", false)):
				continue
			var choices := state.get("choices", []) as Array
			if choices.is_empty():
				continue
			Network._server_keep_card(peer_id, str(choices[0]))
			advanced = true
		if not advanced:
			return


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": Character.SkinColor.BLUE,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
		"character_model": CharacterSkinCatalog.DEFAULT_ID,
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


func _lobby_chat_contains(ui: MainMenuUI, nick: String, text: String) -> bool:
	if ui == null:
		return false
	for item in ui.lobby_chat_messages:
		if str(item.get("nick", "")) == nick and str(item.get("text", "")) == text:
			return true
	return false


func _game_chat_contains(chat: MultiplayerChatUI, nick: String, text: String) -> bool:
	if chat == null:
		return false
	var messages: Array = chat.get("_messages")
	for item in messages:
		if str(item.get("nick", "")) == nick and str(item.get("text", "")) == text:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
