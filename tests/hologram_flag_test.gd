extends Node3D

const HologramFlagScene := preload("res://scenes/effects/hologram_flag.tscn")
const LevelScript := preload("res://scripts/level.gd")
const TARGET_PLAYER_HEIGHT := 2.0
const EXPECTED_HOLOGRAM_HEIGHT := TARGET_PLAYER_HEIGHT * 0.3

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_hologram_flag_avatar_scales_and_uses_shader()
	await _test_level_replaces_one_flag_per_owner()
	_test_input_action_is_bound_to_n()
	_test_source_tokens()
	_shutdown_network_state()

	if failures.is_empty():
		print("[HologramFlagTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[HologramFlagTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19098, 4)
	_expect(error == OK, "Test multiplayer peer should start for hologram placement")
	if error == OK:
		Network.multiplayer.multiplayer_peer = peer
	Network.players.clear()
	Network.players = {
		1: _player("Viewer", Network.Role.HUNTER),
		2: _player("HologramOwner", Network.Role.CHAMELEON),
	}


func _shutdown_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": Network.SKIN_GREEN,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
		"character_model": CharacterSkinCatalog.party_monster_default_id(),
		"party_monster_accessories": PartyMonsterAccessoryCatalog.sanitize_loadout({}, CharacterSkinCatalog.party_monster_default_id()),
		"alive": true,
	}


func _test_hologram_flag_avatar_scales_and_uses_shader() -> void:
	var flag := HologramFlagScene.instantiate() as HologramFlag
	_expect(flag != null, "Hologram flag scene should instantiate as HologramFlag")
	if flag == null:
		return
	flag.auto_build = false
	add_child(flag)
	flag.configure({
		"owner_peer_id": 2,
		"character_model_id": CharacterSkinCatalog.party_monster_default_id(),
		"party_monster_accessories": PartyMonsterAccessoryCatalog.sanitize_loadout({}, CharacterSkinCatalog.party_monster_default_id()),
		"skin_color": Network.SKIN_GREEN,
		"player_height": TARGET_PLAYER_HEIGHT,
		"transform": Transform3D.IDENTITY,
	})
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(absf(flag.get_target_avatar_height_for_test() - EXPECTED_HOLOGRAM_HEIGHT) < 0.001, "Hologram avatar target height should be 0.3x player height")
	var visual_height: float = flag.get_avatar_visual_height_for_test()
	_expect(visual_height >= EXPECTED_HOLOGRAM_HEIGHT * 0.74 and visual_height <= EXPECTED_HOLOGRAM_HEIGHT * 1.26, "Hologram avatar visual height should stay near the 0.3x target; got %.3f" % visual_height)
	_expect(flag.get_hologram_material_count_for_test() > 0, "Hologram avatar should replace inherited skin meshes with shader materials")

	var first_action: String = flag.get_current_performance_action_for_test()
	flag.force_next_hologram_action_for_test()
	var second_action: String = flag.get_current_performance_action_for_test()
	flag.force_next_hologram_action_for_test()
	var third_action: String = flag.get_current_performance_action_for_test()
	_expect(["dance", "victory"].has(first_action), "Hologram should start with a dance or victory action, got " + first_action)
	_expect(["dance", "victory"].has(second_action), "Hologram should continue with a dance or victory action, got " + second_action)
	_expect(["dance", "victory"].has(third_action), "Hologram should keep looping dance/victory actions, got " + third_action)
	_expect(second_action != third_action, "Hologram should alternate between dance and victory actions")

	flag.queue_free()
	await get_tree().process_frame


func _test_level_replaces_one_flag_per_owner() -> void:
	var level: Node3D = LevelScript.new()
	_expect(level != null, "Level script should instantiate for hologram placement")
	if level == null:
		return

	var first_transform := Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0))
	var second_transform := Transform3D(Basis.IDENTITY.rotated(Vector3.UP, 0.5), Vector3(2.0, 0.0, -1.0))
	var first_state := _flag_state(2, first_transform)
	var second_state := _flag_state(2, second_transform)
	level.call("_rpc_place_hologram_flag", 2, first_state)
	level.call("_rpc_place_hologram_flag", 2, second_state)

	_expect(int(level.call("get_hologram_flag_count_for_test")) == 1, "Level should keep one hologram flag per owner")
	var stored_state: Dictionary = level.call("get_hologram_flag_state_for_test", 2)
	var stored_transform: Transform3D = stored_state.get("transform", Transform3D.IDENTITY)
	_expect(stored_transform.origin.distance_to(second_transform.origin) < 0.001, "Replacing a hologram flag should keep the latest placement transform")
	var container := level.get_node_or_null("HologramFlagContainer") as Node3D
	_expect(container != null, "Level should create a hologram flag container")
	if container != null:
		var flag := container.get_node_or_null("HologramFlag_2") as HologramFlag
		_expect(flag != null, "Level should name each owner's hologram flag by peer id")
		if flag != null:
			_expect(flag.character_model_id == CharacterSkinCatalog.party_monster_default_id(), "Spawned hologram flag should inherit the owner character model")
	level.free()
	await get_tree().process_frame


func _flag_state(owner_id: int, flag_transform: Transform3D) -> Dictionary:
	return {
		"owner_peer_id": owner_id,
		"transform": flag_transform,
		"character_model_id": CharacterSkinCatalog.party_monster_default_id(),
		"party_monster_accessories": PartyMonsterAccessoryCatalog.sanitize_loadout({}, CharacterSkinCatalog.party_monster_default_id()),
		"skin_color": Network.SKIN_GREEN,
		"player_height": TARGET_PLAYER_HEIGHT,
	}


func _test_input_action_is_bound_to_n() -> void:
	_expect(InputMap.has_action("place_hologram_flag"), "InputMap should include place_hologram_flag")
	var has_n_key := false
	for event in InputMap.action_get_events("place_hologram_flag"):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_N or key_event.physical_keycode == KEY_N:
				has_n_key = true
	_expect(has_n_key, "place_hologram_flag should be bound to the N key")


func _test_source_tokens() -> void:
	_expect(_file_has("res://scripts/player.gd", "HOLOGRAM_FLAG_ACTION := \"place_hologram_flag\""), "Player should listen for the hologram placement input action")
	_expect(_file_has("res://scripts/player.gd", "request_place_hologram_flag"), "Player should request hologram placement through the level")
	_expect(_file_has("res://scripts/level.gd", "_request_place_hologram_flag_rpc"), "Level should accept client hologram placement requests through RPC")
	_expect(_file_has("res://scripts/level.gd", "_rpc_place_hologram_flag"), "Level should replicate placed hologram flags to peers")
	_expect(_file_has("res://scripts/level.gd", "HologramFlagScene"), "Level should spawn the reusable hologram flag scene")
	_expect(_file_has("res://scripts/hologram_flag.gd", "FLAG_HEIGHT_RATIO := 0.3"), "Hologram flag should define the 0.3x player-height scale")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "scan_line_repetitions"), "Hologram shader should include animated scan lines")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "vertex_shift_strength"), "Hologram shader should include vertex shimmer")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "inherited_skin_strength"), "Hologram shader should blend inherited skin material color or texture")


func _file_has(path: String, token: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return FileAccess.get_file_as_string(path).find(token) != -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
