extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	var flashlight_source := FileAccess.get_file_as_string("res://scripts/hunter_flashlight_system.gd")
	_expect(flashlight_source.contains("func _sync_flashlight_pose_to_recipients"), "Hunter flashlight pose should flow through a targeted fan-out helper")
	_expect(flashlight_source.contains("NetworkInterestScript.is_peer_relevant_to_segment"), "Hunter flashlight pose should use shared segment relevance")
	_expect(flashlight_source.contains("_sync_flashlight_pose.rpc_id"), "Hunter flashlight pose should be sent with targeted rpc_id fan-out")
	_expect(not flashlight_source.contains("_sync_flashlight_pose.rpc("), "Hunter flashlight pose should not broadcast every continuous pose update to all peers")
	_expect(flashlight_source.contains("Network.record_rpc_event(\"flashlight.pose\", recipients.size(), 52)"), "Hunter flashlight pose telemetry should record actual recipient counts")
	_expect(player_source.contains("_has_hunter_prop_sense_feedback"), "Hunter prop sense feedback should reuse existing local nodes")
	_expect(player_source.contains("_clear_hunter_prop_sense_runtime_feedback_nodes"), "Dedicated public servers should clear only local Hunter sense feedback nodes")
	_expect(player_source.contains("if not _should_render_local_feedback():\n\t\t_clear_hunter_prop_sense_runtime_feedback_nodes()\n\t\treturn"), "Dedicated public servers should keep Hunter sense state while clearing local feedback work")
	_expect(player_source.contains("LOCAL_FEEDBACK_TRANSFORM_INTERVAL"), "Hunter prop sense feedback transforms should be budgeted instead of updating every frame")
	var wall := _make_world_box("SenseOccluderWall", Vector3(0.35, 5.0, 8.0), Vector3(6.0, 2.5, 0.0))
	add_child(wall)

	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var hunter = player_scene.instantiate()
	hunter.name = "1"
	hunter.position = Vector3.ZERO
	add_child(hunter)

	var chameleon = player_scene.instantiate()
	chameleon.name = "2"
	chameleon.position = Vector3(27.5, 0.0, 0.0)
	add_child(chameleon)

	var remote_hunter = player_scene.instantiate()
	remote_hunter.name = "3"
	remote_hunter.position = Vector3(-4.0, 0.0, 0.0)
	add_child(remote_hunter)
	await get_tree().process_frame
	await get_tree().physics_frame

	var system = hunter.get_node_or_null("HunterPropSenseSystem")
	_expect(system != null, "Local Hunter should attach HunterPropSenseSystem")
	if system:
		_expect(hunter.get_node_or_null("PlayerNick/HunterPropSensePassiveIcon") == null, "Hunter passive sense icon should be drawn by SkillHUD, not as a 3D nameplate icon")
	_expect(hunter.is_hunter(), "Hunter test player should have Hunter role")
	_expect(chameleon.is_chameleon(), "Target test player should have Chameleon role")
	_expect(remote_hunter.is_hunter(), "Remote Hunter test player should have Hunter role")
	hunter._refresh_nickname_visibility()
	_expect(hunter.nickname.visible, "Local player's own nameplate should not be hidden by cross-team nameplate rules")
	chameleon._refresh_nickname_visibility()
	_expect(not chameleon.nickname.visible, "Hunter clients should not see remote Prop nameplates")
	Network.players[1]["role"] = Network.Role.CHAMELEON
	remote_hunter._refresh_nickname_visibility()
	_expect(not remote_hunter.nickname.visible, "Prop clients should not see remote Hunter nameplates")
	Network.players[1]["role"] = Network.Role.HUNTER

	chameleon.apply_prop_disguise({
		"id": "sense_test_crate",
		"name": "Sense Test Crate",
		"mesh": "box",
		"size": Vector3(1.25, 1.0, 1.25),
		"offset": Vector3(0.0, 0.52, 0.0),
		"color": Color(0.45, 0.30, 0.16, 1.0),
	})
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame

	_expect(chameleon.is_disguised(), "Chameleon should be disguised before Hunter sense checks")
	_expect(not chameleon.is_hunter_prop_sense_revealed(), "Wheel or generic Q presets should not trigger Hunter prop sense")
	_expect(chameleon.get_hunter_prop_sense_outline_count() == 0, "Generic prop disguise should not create Hunter sense outlines")

	chameleon.apply_prop_disguise({
		"id": "sense_test_scene_crate",
		"name": "Sense Test Scene Crate",
		"mesh": "box",
		"size": Vector3(1.25, 1.0, 1.25),
		"offset": Vector3(0.0, 0.52, 0.0),
		"color": Color(0.45, 0.30, 0.16, 1.0),
		"q_scene_prop_replica": true,
		"disguise_source": "nearby_scene_prop_q",
	})
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame

	_expect(chameleon.is_hunter_prop_sense_revealed(), "Disguised Chameleon inside 28m should start directional audio sensing")
	_expect(chameleon.has_hunter_prop_sense_audio(), "Audio-only prop sense should create a 3D beep source")
	_expect(chameleon.get_hunter_prop_sense_audio_volume_db() > -9.0, "Far directional beep should be deliberately audible for Hunters")
	_expect(chameleon.has_hunter_prop_sense_ping_marker(), "Entering audio sense should create a one-shot airborne sound-source ping")
	var ping_position: Vector3 = chameleon.get_hunter_prop_sense_ping_marker_position()
	_expect(absf(ping_position.x - chameleon.global_position.x) < 0.05, "Sound-source ping should use the Chameleon's real world X coordinate")
	_expect(absf(ping_position.z - chameleon.global_position.z) < 0.05, "Sound-source ping should use the Chameleon's real world Z coordinate")
	_expect(absf(ping_position.y - chameleon.get_hunter_prop_sense_ping_marker_bottom_y()) < 0.05, "Sound-source lattice should start from its bottom world position")
	_expect(chameleon.get_hunter_prop_sense_ping_marker_top_y() > chameleon.global_position.y + 2.0, "Sound-source lattice should extend above the disguised Chameleon")
	_expect(chameleon.get_hunter_prop_sense_ping_ring_count() >= 4, "Sound-source ping should be a discontinuous vertical cylinder lattice made of multiple rings")
	_expect(is_equal_approx(chameleon.get_hunter_prop_sense_ping_expansion_multiplier(), 2.5), "Sound-source lattice expansion should be 2.5x the previous radius")
	_expect(not chameleon.is_hunter_prop_sense_visual_active(), "Disguised Chameleon outside 18m should not get full visual sensing yet")
	_expect(chameleon.get_hunter_prop_sense_outline_count() == 0, "Audio-only prop sense should not create red outline shells")
	if system:
		_expect(system.is_passive_active(), "First valid prop detection should activate Hunter passive sense for 10 seconds")
		_expect(system.get_passive_active_remaining() > 9.0, "Hunter passive active duration should start near 10 seconds")
		_expect(system.get_sensed_target_count() == 1, "Hunter sense system should track one sensed target")
		_expect(system.is_target_sensed(chameleon), "Hunter sense system should remember the Chameleon target")
		_expect(system.get_visual_target_count() == 0, "Hunter sense should not track visual targets outside 18m")

	chameleon.global_position = Vector3(17.5, 0.0, 0.0)
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame
	_expect(chameleon.is_hunter_prop_sense_visual_active(), "Hunter entering 18m should upgrade to full visual and audio sensing")
	_expect(chameleon.get_hunter_prop_sense_outline_count() > 0, "Full prop sense should create red outline shells")
	_expect(_has_depth_disabled_outline(chameleon), "Hunter sense outline shader should render through occluders")
	_expect(_has_distance_scaled_outline_alpha(chameleon), "Hunter sense outline should scale transparency by distance intensity")
	if system:
		_expect(system.get_visual_target_count() == 1, "Hunter sense should track one visual target inside 18m")

	chameleon.global_position = Vector3(19.3, 0.0, 0.0)
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame
	_expect(chameleon.is_hunter_prop_sense_visual_active(), "Hunter visual sense should use 20m exit hysteresis to avoid flicker")

	chameleon.global_position = Vector3(21.0, 0.0, 0.0)
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame
	_expect(chameleon.is_hunter_prop_sense_revealed(), "Hunter should keep directional audio after visual sense drops outside 20m")
	_expect(not chameleon.is_hunter_prop_sense_visual_active(), "Disguised Chameleon past 20m should stop full visual sensing")
	_expect(chameleon.get_hunter_prop_sense_outline_count() == 0, "Hunter visual outlines should clear after leaving 20m")

	chameleon.global_position = Vector3(28.8, 0.0, 0.0)
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame
	_expect(not chameleon.is_hunter_prop_sense_revealed(), "Disguised Chameleon past 28m should stop audio sensing")

	chameleon.global_position = Vector3(5.0, 0.0, 0.0)
	chameleon.apply_prop_disguise({
		"id": "sense_test_barrel",
		"name": "Sense Test Barrel",
		"mesh": "cylinder",
		"size": Vector3(0.95, 1.35, 0.95),
		"offset": Vector3(0.0, 0.68, 0.0),
		"color": Color(0.24, 0.28, 0.32, 1.0),
		"q_scene_prop_replica": true,
		"disguise_source": "nearby_scene_prop_q",
	})
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame
	_expect(chameleon.is_hunter_prop_sense_revealed(), "Re-entering range with a new disguise should sense the new prop")
	if system:
		system._process(10.2)
	await get_tree().process_frame
	if system:
		_expect(not system.is_passive_active(), "Hunter passive should stop after 10 seconds")
		_expect(system.get_passive_cooldown_remaining() > 44.0, "Hunter passive should enter a 45 second cooldown after active time expires")
		_expect(system.get_sensed_target_count() == 0, "Hunter passive cooldown should clear sensed targets")
	_expect(not chameleon.is_hunter_prop_sense_revealed(), "Hunter passive cooldown should remove active target feedback")
	chameleon.clear_prop_disguise()
	await get_tree().process_frame
	if system:
		system.force_scan()
	await get_tree().process_frame
	_expect(not chameleon.is_hunter_prop_sense_revealed(), "Clearing Q disguise should remove Hunter sense state")
	_expect(chameleon.get_hunter_prop_sense_outline_count() == 0, "Clearing Q disguise should remove all Hunter sense outlines")

	hunter.queue_free()
	chameleon.queue_free()
	remote_hunter.queue_free()
	wall.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if failures.is_empty():
		print("[HunterPropSenseTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[HunterPropSenseTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Network.players.clear()
	Network.players = {
		1: _player("Hunter", Network.Role.HUNTER),
		2: _player("Chameleon", Network.Role.CHAMELEON),
		3: _player("RemoteHunter", Network.Role.HUNTER),
	}


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": 0,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
		"character_model": "godot_robot",
	}


func _make_world_box(node_name: String, size: Vector3, world_position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 3
	body.position = world_position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	body.add_child(visual)
	return body


func _has_depth_disabled_outline(player: Node) -> bool:
	var outlines := []
	_collect_outline_nodes(player, outlines)
	for outline in outlines:
		if not outline is MeshInstance3D:
			continue
		var material := (outline as MeshInstance3D).material_override
		if material is ShaderMaterial:
			var shader := (material as ShaderMaterial).shader
			if shader and shader.code.find("depth_test_disabled") >= 0:
				return true
	return false


func _has_distance_scaled_outline_alpha(player: Node) -> bool:
	var outlines := []
	_collect_outline_nodes(player, outlines)
	for outline in outlines:
		if not outline is MeshInstance3D:
			continue
		var material := (outline as MeshInstance3D).material_override
		if material is ShaderMaterial:
			var shader := (material as ShaderMaterial).shader
			if shader and shader.code.find("alpha_multiplier") >= 0:
				return true
	return false


func _collect_outline_nodes(node: Node, result: Array) -> void:
	if node.name == "HunterPropSenseOutline":
		result.append(node)
	for child in node.get_children():
		_collect_outline_nodes(child, result)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
