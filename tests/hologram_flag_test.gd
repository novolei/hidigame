extends Node3D

const HologramFlagScene := preload("res://scenes/effects/hologram_flag.tscn")
const LevelScript := preload("res://scripts/level.gd")
const TARGET_PLAYER_HEIGHT := 2.0
const EXPECTED_HOLOGRAM_HEIGHT := TARGET_PLAYER_HEIGHT * 0.3
const EXPECTED_VISUAL_HEIGHT_MULTIPLIER := 2.55
const EXPECTED_HOLOGRAM_VISUAL_HEIGHT := EXPECTED_HOLOGRAM_HEIGHT * EXPECTED_VISUAL_HEIGHT_MULTIPLIER

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_hologram_flag_avatar_scales_and_uses_shader()
	await _test_level_replaces_one_flag_per_owner()
	await _test_hologram_flag_syncs_full_appearance_state()
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
	_expect(visual_height >= EXPECTED_HOLOGRAM_VISUAL_HEIGHT * 0.9 and visual_height <= EXPECTED_HOLOGRAM_VISUAL_HEIGHT * 1.1, "Hologram avatar visual height should be enlarged beyond the 0.3x base target; got %.3f" % visual_height)
	var base_gap: float = flag.get_avatar_base_gap_for_test()
	_expect(base_gap >= 0.0 and base_gap <= 0.03, "Hologram avatar should sit close to the projector base; gap %.3f" % base_gap)
	_expect(flag.get_hologram_material_count_for_test() > 0, "Hologram avatar should replace inherited skin meshes with shader materials")
	_expect(flag.get_hologram_outline_material_count_for_test() > 0, "Hologram avatar should add an outline pass so the miniature player silhouette stays readable")
	_expect(flag.get_projection_beam_material_count_for_test() == 0, "Hologram flag should not create a conical projection beam material")

	var palette: Dictionary = flag.get_hologram_palette_for_test()
	var body_color: Color = _color_from_dictionary(palette, "body_color")
	var accent_color: Color = _color_from_dictionary(palette, "accent_color")
	var glow_color: Color = _color_from_dictionary(palette, "glow_color")
	var solid_fill_color: Color = _color_from_dictionary(palette, "solid_fill_color")
	var expected_skin_color := Color(0.36, 1.0, 0.48, 1.0)
	_expect(_color_distance(body_color, expected_skin_color) < 0.001, "Hologram body color should use the synced player skin_color directly")
	_expect(_color_distance(accent_color, expected_skin_color) < 0.001, "Hologram scan edge color should stay aligned with the player skin_color")
	_expect(_color_distance(glow_color, expected_skin_color) < 0.001, "Hologram glow color should stay aligned with the player skin_color")
	_expect(_color_distance(solid_fill_color, expected_skin_color) < 0.001, "Hologram solid fill should use the synced player skin_color")
	_expect(_color_distance(flag.get_first_hologram_shader_color_for_test("scan_color"), expected_skin_color) < 0.001, "Hologram scan lines should use the synced player skin_color")
	_expect(_color_distance(flag.get_first_hologram_shader_color_for_test("scan_edge_color"), expected_skin_color) < 0.001, "Hologram scan edge should use the synced player skin_color")
	_expect(_color_distance(flag.get_first_hologram_shader_color_for_test("scan_glow_color"), expected_skin_color) < 0.001, "Hologram scan glow should use the synced player skin_color")
	_expect(_color_distance(flag.get_first_hologram_shader_color_for_test("solid_fill_color"), expected_skin_color) < 0.001, "Hologram fill color should use the synced player skin_color")
	_expect(absf(flag.get_first_hologram_shader_float_for_test("solid_fill_alpha") - 0.22) < 0.001, "Hologram mesh fill alpha should be raised to 0.22")
	_expect(_color_distance(flag.get_first_hologram_shader_color_for_test("sweep_highlight_color_a"), Color(0.78, 0.96, 1.0, 1.0)) < 0.001, "First sweep highlight should keep the electric-white color")
	_expect(_color_distance(flag.get_first_hologram_shader_color_for_test("sweep_highlight_color_b"), Color(0.22, 0.82, 1.0, 1.0)) < 0.001, "Second sweep highlight should keep the electric-blue lightning color")

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
	var model_id: String = CharacterSkinCatalog.party_monster_default_id()
	return {
		"owner_peer_id": owner_id,
		"transform": flag_transform,
		"character_model_id": model_id,
		"party_monster_accessories": PartyMonsterAccessoryCatalog.sanitize_loadout({}, model_id),
		"skin_color": Network.SKIN_GREEN,
		"player_height": TARGET_PLAYER_HEIGHT,
	}


func _test_hologram_flag_syncs_full_appearance_state() -> void:
	var level: Node3D = LevelScript.new()
	_expect(level != null, "Level script should instantiate for hologram sync")
	if level == null:
		return

	var owner_id := 2
	var model_id: String = CharacterSkinCatalog.party_monster_default_id()
	var source_loadout: Dictionary = _non_empty_party_monster_loadout(model_id)
	var noisy_loadout: Dictionary = source_loadout.duplicate(true)
	noisy_loadout["invalid_slot"] = "missing_accessory"
	var expected_loadout: Dictionary = PartyMonsterAccessoryCatalog.sanitize_loadout(noisy_loadout, model_id)
	var flag_transform := Transform3D(Basis.IDENTITY.rotated(Vector3.UP, 0.25), Vector3(3.0, 0.0, -2.0))
	var sanitized_state: Dictionary = level.call("_sanitize_hologram_flag_state", owner_id, flag_transform, model_id, noisy_loadout, Network.SKIN_RED, TARGET_PLAYER_HEIGHT)

	_expect(str(sanitized_state.get("character_model_id", "")) == model_id, "Hologram sync state should preserve the owner character model")
	_expect(_dictionaries_match(sanitized_state.get("party_monster_accessories", {}) as Dictionary, expected_loadout), "Hologram sync state should broadcast a sanitized accessory loadout")
	_expect(int(sanitized_state.get("skin_color", -1)) == Network.SKIN_RED, "Hologram sync state should preserve the owner skin color")
	_expect(absf(float(sanitized_state.get("player_height", 0.0)) - TARGET_PLAYER_HEIGHT) < 0.001, "Hologram sync state should preserve the owner visual height")

	level.call("_rpc_sync_hologram_flags", [sanitized_state])
	_expect(int(level.call("get_hologram_flag_count_for_test")) == 1, "Synced hologram state should spawn a visible flag on receiving peers")
	var stored_state: Dictionary = level.call("get_hologram_flag_state_for_test", owner_id)
	_expect(_dictionaries_match(stored_state.get("party_monster_accessories", {}) as Dictionary, expected_loadout), "Receiving peers should store the same accessory loadout")
	_expect(int(stored_state.get("skin_color", -1)) == Network.SKIN_RED, "Receiving peers should store the same skin color")
	var container := level.get_node_or_null("HologramFlagContainer") as Node3D
	_expect(container != null, "Synced hologram state should create a local flag container")
	if container != null:
		var flag := container.get_node_or_null("HologramFlag_2") as HologramFlag
		_expect(flag != null, "Synced hologram state should spawn the owner's flag node")
		if flag != null:
			_expect(flag.character_model_id == model_id, "Spawned synced flag should use the owner character model")
			_expect(_dictionaries_match(flag.party_monster_accessories, expected_loadout), "Spawned synced flag should use the owner accessory loadout")
			_expect(flag.skin_color == Network.SKIN_RED, "Spawned synced flag should use the owner skin color")
	level.free()
	await get_tree().process_frame


func _non_empty_party_monster_loadout(model_id: String) -> Dictionary:
	var loadout: Dictionary = PartyMonsterAccessoryCatalog.loadout_for_model_id(model_id)
	if loadout.is_empty():
		var accessory_ids: Array = PartyMonsterAccessoryCatalog.all_accessory_ids()
		if not accessory_ids.is_empty():
			loadout = PartyMonsterAccessoryCatalog.replace_accessory({}, str(accessory_ids[0]), model_id)
	return PartyMonsterAccessoryCatalog.sanitize_loadout(loadout, model_id)


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
	_expect(_file_has("res://scripts/level.gd", "_server_sync_hologram_flags_to_peer"), "Level should sync existing hologram flags to late-joining peers")
	_expect(_file_has("res://scripts/level.gd", "_rpc_sync_hologram_flags"), "Level should rebuild replicated hologram flags from server sync state")
	_expect(_file_has("res://scripts/level.gd", "PartyMonsterAccessoryCatalogScript.sanitize_loadout(accessory_loadout"), "Level should sanitize hologram accessory state before broadcasting it")
	_expect(_file_has("res://scripts/level.gd", "HologramFlagScene"), "Level should spawn the reusable hologram flag scene")
	_expect(_file_has("res://scripts/hologram_flag.gd", "FLAG_HEIGHT_RATIO := 0.3"), "Hologram flag should define the 0.3x player-height scale")
	_expect(_file_has("res://scripts/hologram_flag.gd", "AVATAR_VISUAL_HEIGHT_MULTIPLIER := 2.55"), "Hologram avatar should use the requested 2.55 visual scale")
	_expect(_file_has("res://scripts/hologram_flag.gd", "AVATAR_BASE_CLEARANCE_RATIO"), "Hologram avatar should keep a tiny base clearance so it sits close to the projector")
	_expect(not _file_has("res://scripts/hologram_flag.gd", "PROJECTION_BEAM_SHADER"), "Hologram flag should not preload the removed projection cone shader")
	_expect(not _file_has("res://scripts/hologram_flag.gd", "ScifiShieldProjection"), "Hologram flag should not build a conical projection shield")
	_expect(not _file_has("res://scripts/hologram_flag.gd", "_make_projection_beam_material"), "Hologram flag should not keep cone beam material setup")
	_expect(_file_has("res://scripts/hologram_flag.gd", "HOLOGRAM_OUTLINE_SHADER"), "Hologram flag should assign the dedicated avatar outline shader")
	_expect(_file_has("res://scripts/hologram_flag.gd", "TorusMesh.new"), "Hologram flag scan rings should be hollow torus meshes instead of opaque discs")
	_expect(_file_has("res://scripts/hologram_flag.gd", "_make_marble_base_material"), "Hologram flag base should use a marble-like material")
	_expect(_file_has("res://scripts/hologram_flag.gd", "material.metallic = 0.0"), "Hologram flag marble base should not use a purple metallic finish")
	_expect(_file_has("res://scripts/hologram_flag.gd", "ProjectorMarbleRim"), "Hologram flag base should include a visible marble rim highlight")
	_expect(_file_has("res://scripts/hologram_flag.gd", "ProjectorGlowDisc"), "Hologram flag should keep a base glow without a cone projection")
	_expect(_file_has("res://scripts/hologram_flag.gd", "Color(1.0, 0.22, 0.86"), "Projector base glow should use a pink-purple hologram color")
	_expect(_file_has("res://scripts/hologram_flag.gd", "material.render_priority = 8"), "Hologram avatar should render above the base effects")
	_expect(_file_has("res://scripts/hologram_flag.gd", "material.render_priority = 9"), "Hologram outline should render above the avatar")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "scan_line_repetitions"), "Hologram shader should include animated scan lines")
	_expect(_file_has("res://scripts/hologram_flag.gd", "scan_line_repetitions\", 27.0"), "Hologram avatar scan lines should stay sparse while drawing clearer rings")
	_expect(_file_has("res://scripts/hologram_flag.gd", "scan_line_width\", 0.03"), "Hologram avatar scan lines should be thick enough to read clearly")
	_expect(_file_has("res://scripts/hologram_flag.gd", "_make_hologram_palette"), "Hologram avatar should build its colors from the synced player skin_color")
	_expect(_file_has("res://scripts/hologram_flag.gd", "_skin_color_tint()"), "Hologram avatar should read the player skin_color tint directly")
	_expect(_file_has("res://scripts/hologram_flag.gd", "\"accent_color\": body_color"), "Hologram avatar scan edge should use the same player skin_color")
	_expect(_file_has("res://scripts/hologram_flag.gd", "\"glow_color\": body_color"), "Hologram avatar scan glow should use the same player skin_color")
	_expect(_file_has("res://scripts/hologram_flag.gd", "\"solid_fill_color\": body_color"), "Hologram avatar solid fill should use the same player skin_color")
	_expect(_file_has("res://scripts/hologram_flag.gd", "\"surface_tint\""), "Hologram avatar should still understand Party Monster material tint parameters for source alpha")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "scan_color : source_color"), "Hologram shader should expose runtime scan line color")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "scan_glow_color : source_color"), "Hologram shader should expose runtime glow color")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "solid_fill_color : source_color"), "Hologram shader should expose runtime solid fill color")
	_expect(_file_has("res://scripts/hologram_flag.gd", "solid_fill_alpha\", 0.22"), "Hologram mesh solid fill alpha should use the requested 0.22 value")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "solid_fill_alpha : hint_range(0.0, 0.35) = 0.22"), "Hologram shader default solid fill alpha should use the requested 0.22 value")
	_expect(_file_has("res://scripts/hologram_flag.gd", "scan_glow_width\", 0.068"), "Hologram avatar scan lines should have a visible same-color halo width")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "sweep_highlight_color_a : source_color = vec4(0.78, 0.96, 1.0"), "First sweep highlight should use a cold electric-white color")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "sweep_highlight_color_b : source_color = vec4(0.22, 0.82, 1.0"), "Second sweep highlight should use an electric-blue lightning color")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "sweep_glitch_rate_a : hint_range(0.0, 20.0) = 0.72"), "First glitch sweep should scan slowly enough to read")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "sweep_glitch_rate_b : hint_range(0.0, 20.0) = 0.48"), "Second glitch sweep should scan slowly enough to read")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "depth_draw_never"), "Hologram avatar should not depth-fill the transparent mesh body")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "line_alpha"), "Hologram avatar alpha should keep scan lines dominant over the low solid fill")
	_expect(not _file_has("res://shaders/hologram_avatar.gdshader", "silhouette_fill"), "Hologram avatar should not use a glowing filled silhouette")
	_expect(not _file_has("res://shaders/hologram_avatar.gdshader", "base_alpha"), "Hologram avatar should not keep full-body alpha fill")
	_expect(not _file_has("res://shaders/hologram_avatar.gdshader", "inherited_skin_strength"), "Hologram avatar should not glow inherited skin surfaces directly")
	_expect(_file_has("res://shaders/hologram_avatar_outline.gdshader", "scan_line_repetitions : hint_range(1.0, 180.0) = 27.0"), "Hologram outline scan lines should match the avatar spacing")
	_expect(_file_has("res://shaders/hologram_avatar_outline.gdshader", "scan_glow_color : source_color"), "Hologram outline should expose runtime scan glow color")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "vertex_shift_strength"), "Hologram shader should include vertex shimmer")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "cluster_scan_lines"), "Hologram shader should select random glitch clusters from the same scan lines")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "sweep_line_count_a : hint_range(1.0, 8.0) = 4.0"), "First glitch highlight group should use about four scan lines")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "sweep_line_count_b : hint_range(1.0, 8.0) = 3.0"), "Second glitch highlight group should use about three scan lines")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "scan_core * cluster_a"), "First highlight sweep should overlap the base horizontal scan lines")
	_expect(_file_has("res://shaders/hologram_avatar.gdshader", "scan_core * cluster_b"), "Second highlight sweep should overlap the base horizontal scan lines")
	_expect(_file_has("res://shaders/hologram_avatar_outline.gdshader", "outline_width"), "Hologram outline shader should only add a very thin line-only edge pass")


func _color_from_dictionary(dictionary: Dictionary, key: String) -> Color:
	var value: Variant = dictionary.get(key, Color(0.0, 0.0, 0.0, 0.0))
	if value is Color:
		return value as Color
	return Color(0.0, 0.0, 0.0, 0.0)


func _color_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)


func _dictionaries_match(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for key in left.keys():
		if not right.has(key):
			return false
		if str(left[key]) != str(right[key]):
			return false
	return true


func _file_has(path: String, token: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return FileAccess.get_file_as_string(path).find(token) != -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
