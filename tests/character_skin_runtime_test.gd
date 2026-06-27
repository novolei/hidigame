extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_default_skin_uses_basic_humanoid_visual()
	await _test_default_hunter_uses_hunter_shooter_visual()
	await _test_prep_tint_preserves_custom_skin_textures()
	await _test_remote_custom_skin_animates_from_network_motion()
	await _test_public_server_skips_remote_skin_animation()
	await _test_player_position_sync_budget()
	_test_netfox_remote_motion_bot_smoke()

	if failures.is_empty():
		print("[CharacterSkinRuntimeTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[CharacterSkinRuntimeTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19096, 4)
	_expect(error == OK, "Test multiplayer peer should start")
	if error == OK:
		Network.multiplayer.multiplayer_peer = peer
	Network.players.clear()


func _test_prep_tint_preserves_custom_skin_textures() -> void:
	Network.players = {
		2: _player("SophiaHunter", Network.Role.HUNTER, "sophia"),
	}
	var player := _spawn_player("2")
	await get_tree().process_frame
	await get_tree().process_frame

	var textured_before := _count_textured_skin_surfaces(player)
	player.set_prep_locked(true)
	var textured_after := _count_textured_skin_surfaces(player)
	_expect(textured_before > 0, "Sophia skin should expose textured materials before prep tint")
	_expect(textured_after >= textured_before, "Prep tint should preserve Sophia textures instead of replacing them with blank materials")

	player.queue_free()
	await get_tree().process_frame


func _test_default_skin_uses_basic_humanoid_visual() -> void:
	Network.players = {
		4: _player("DefaultHider", Network.Role.CHAMELEON, CharacterSkinCatalog.DEFAULT_ID),
	}
	var player := _spawn_player("4")
	await get_tree().process_frame
	await get_tree().process_frame

	var skin = player.get("_active_skin_node") as Node3D
	var robot := player.get_node_or_null("3DGodotRobot/RobotArmature") as Node3D
	_expect(skin != null, "Default character should instantiate the Basic humanoid skin instead of using the built-in robot")
	_expect(skin and skin.has_node("BasicHumanoidVisual"), "Default character should load BasicHumanoidVisual from BaseModel.fbx")
	_expect(robot == null or not robot.visible, "Built-in 3DGodotRobot should be hidden when Basic humanoid skin is active")

	player.queue_free()
	await get_tree().process_frame


func _test_default_hunter_uses_hunter_shooter_visual() -> void:
	Network.players = {
		5: _player("DefaultHunter", Network.Role.HUNTER, CharacterSkinCatalog.DEFAULT_ID),
	}
	var player := _spawn_player("5")
	await get_tree().process_frame
	await get_tree().process_frame

	var skin = player.get("_active_skin_node") as Node3D
	var robot := player.get_node_or_null("3DGodotRobot/RobotArmature") as Node3D
	_expect(skin != null, "Default Hunter should instantiate the Hunter shooter skin")
	_expect(skin and skin.has_node("HunterShooterVisual"), "Default Hunter should load HunterShooterVisual from the provided GLB")
	_expect(skin and _has_descendant_named(skin, "Rifle"), "Default Hunter shooter skin should include the integrated Rifle")
	_expect(robot == null or not robot.visible, "Built-in 3DGodotRobot should be hidden when Hunter shooter skin is active")

	player.queue_free()
	await get_tree().process_frame


func _test_remote_custom_skin_animates_from_network_motion() -> void:
	Network.players = {
		3: _player("RemoteSophia", Network.Role.CHAMELEON, "sophia"),
	}
	var player := _spawn_player("3")
	await get_tree().process_frame
	await get_tree().process_frame

	player._animate_remote_skin_from_network_motion(0.1)
	player.global_position += Vector3(1.0, 0.0, 0.0)
	player._animate_remote_skin_from_network_motion(0.1)
	await get_tree().process_frame

	var current_animation_node := _custom_skin_current_animation_node(player)
	_expect(current_animation_node == "Run", "Remote Sophia skin should play Run when network position changes; current=" + current_animation_node)
	_expect(_remote_visual_policy_applied(player), "Remote custom skins should render without expensive shadow/GI contribution")

	player.queue_free()
	await get_tree().process_frame


func _test_public_server_skips_remote_skin_animation() -> void:
	var had_public_server_key := Network.lobby_config.has("public_server")
	var previous_public_server: Variant = Network.lobby_config.get("public_server", false)
	Network.lobby_config["public_server"] = true
	Network.players = {
		7: _player("RemotePublicServerSophia", Network.Role.CHAMELEON, "sophia"),
	}
	var player := _spawn_player("7")
	await get_tree().process_frame
	await get_tree().process_frame

	player._play_skin_action("idle")
	await get_tree().process_frame
	var before_animation_node := _custom_skin_current_animation_node(player)
	player._process(0.1)
	player.global_position += Vector3(1.0, 0.0, 0.0)
	player._process(0.1)
	await get_tree().process_frame

	var after_animation_node := _custom_skin_current_animation_node(player)
	_expect(after_animation_node == before_animation_node, "Dedicated public server should skip remote skin motion animation; before=" + before_animation_node + " after=" + after_animation_node)

	player.queue_free()
	if had_public_server_key:
		Network.lobby_config["public_server"] = previous_public_server
	else:
		Network.lobby_config.erase("public_server")
	await get_tree().process_frame


func _test_player_position_sync_budget() -> void:
	var player := _spawn_player("6")
	await get_tree().process_frame
	var old_synchronizer := player.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	_expect(old_synchronizer == null, "Player scene should no longer use MultiplayerSynchronizer for high-frequency position sync")
	var transform_sync := player.get_node_or_null("NetfoxTransformSync") as NetfoxPlayerTransformSync
	_expect(transform_sync != null, "Player scene should use NetfoxTransformSync for network tick snapshots")
	if transform_sync:
		_expect(transform_sync.send_every_ticks == 1, "Moving player transform snapshots should still be allowed every network tick")
		_expect(transform_sync.idle_send_every_ticks > transform_sync.send_every_ticks, "Idle player transform snapshots should use a lower-rate budget")
		_expect(transform_sync.force_send_every_ticks >= transform_sync.idle_send_every_ticks, "Idle player transform snapshots should keep a bounded forced refresh")
		_expect(transform_sync.min_position_delta > 0.0, "Transform sync should suppress tiny idle position jitter")
		_expect(transform_sync.min_velocity_delta > 0.0, "Transform sync should suppress tiny idle velocity jitter")
		_expect(transform_sync.interpolation_delay_ticks == 4, "Remote transform sync should keep a public-internet interpolation buffer")
		_expect(transform_sync.max_extrapolation_ticks == 3, "Remote transform sync should cap short extrapolation")
		_expect(transform_sync.render_lerp_speed >= 20.0, "Remote transform sync should smooth render samples")
		_expect(transform_sync.max_velocity_mps <= 80.0, "Remote transform sync should clamp extreme velocities")
		_expect(NetfoxPlayerTransformSync.TRANSFORM_SNAPSHOT_APPROX_BYTES > 0, "Transform sync should expose a telemetry byte budget")
		_expect(bool(transform_sync.call("_should_submit_current_transform", 0)), "Transform sync should always submit its first owner snapshot")
		transform_sync.set("_last_sent_tick", 0)
		transform_sync.set("_has_last_submitted_transform", true)
		transform_sync.set("_last_submitted_position", player.global_position)
		transform_sync.set("_last_submitted_velocity", Vector3.ZERO)
		player.velocity = Vector3.ZERO
		_expect(not bool(transform_sync.call("_should_submit_current_transform", 1)), "Idle transform sync should skip the next unchanged tick")
		_expect(bool(transform_sync.call("_should_submit_current_transform", transform_sync.force_send_every_ticks)), "Idle transform sync should force a bounded refresh")
		var transform_sync_source := FileAccess.get_file_as_string("res://scripts/network/netfox_player_transform_sync.gd")
		_expect(transform_sync_source.contains("player_transform.owner_idle_skip"), "Transform sync telemetry should record idle-owner skipped snapshots")
		_expect(transform_sync_source.contains("player_transform.remote_sample_"), "Transform sync telemetry should record remote interpolation sample modes")
		_expect(transform_sync_source.contains("extrapolate_clamped"), "Transform sync telemetry should expose clamped extrapolation as a stutter signal")
	player.queue_free()
	await get_tree().process_frame


func _test_netfox_remote_motion_bot_smoke() -> void:
	var previous_perf_log: String = OS.get_environment("MAOMAO_PERF_LOG")
	OS.set_environment("MAOMAO_PERF_LOG", "1")
	Network._reset_performance_telemetry_window()
	var bot_counts: Array[int] = [2, 4, 8, 16]
	for bot_count: int in bot_counts:
		var roots: Array[CharacterBody3D] = []
		for index: int in range(bot_count):
			var root: CharacterBody3D = CharacterBody3D.new()
			root.name = "SyntheticRemote" + str(bot_count) + "_" + str(index)
			root.set_multiplayer_authority(100 + index)
			add_child(root)
			var transform_sync: NetfoxPlayerTransformSync = NetfoxPlayerTransformSync.new()
			transform_sync.name = "NetfoxTransformSync"
			root.add_child(transform_sync)
			transform_sync.call("_resolve_root")
			for sample_index: int in range(24):
				var sample_position: Vector3 = Vector3(float(index), 0.0, float(sample_index) * 0.2)
				var sample_velocity: Vector3 = Vector3(0.0, 0.0, 2.0)
				transform_sync.call("_record_snapshot", sample_index, sample_position, sample_velocity)
			var snapshots: Array = transform_sync.get("_snapshots") as Array
			_expect(snapshots.size() <= transform_sync.max_snapshots, "Synthetic remote bot snapshots should stay bounded for " + str(bot_count) + " bots")
			var interpolated: Dictionary = transform_sync.call("_sample_state", 10.5) as Dictionary
			_expect(str(interpolated.get("mode", "")) == "interpolate", "Synthetic remote bot should interpolate mid-buffer samples for " + str(bot_count) + " bots")
			var extrapolated: Dictionary = transform_sync.call("_sample_state", 99.0) as Dictionary
			_expect(str(extrapolated.get("mode", "")) == "extrapolate_clamped", "Synthetic remote bot should clamp stale extrapolation for " + str(bot_count) + " bots")
			roots.append(root)
		for root: CharacterBody3D in roots:
			root.free()
	var summary: String = Network._format_performance_telemetry_events()
	_expect(summary.contains("player_transform.snapshot_overflow"), "Synthetic 2/4/8/16 remote bot smoke should record snapshot overflow telemetry")
	Network._reset_performance_telemetry_window()
	if previous_perf_log.is_empty():
		OS.unset_environment("MAOMAO_PERF_LOG")
	else:
		OS.set_environment("MAOMAO_PERF_LOG", previous_perf_log)


func _spawn_player(peer_id: String) -> Node:
	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var player = player_scene.instantiate()
	player.name = peer_id
	add_child(player)
	return player


func _player(nick: String, role: int, model_id: String) -> Dictionary:
	return {
		"nick": nick,
		"skin": 0,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
		"character_model": model_id,
	}


func _count_textured_skin_surfaces(player: Node) -> int:
	var count := 0
	for mesh in player._get_stalker_visual_meshes():
		var mesh_instance := mesh as MeshInstance3D
		for surface in range(player._get_mesh_surface_count(mesh_instance)):
			var material: Material = player._get_mesh_surface_material(mesh_instance, surface)
			if _material_has_texture(material):
				count += 1
	return count


func _material_has_texture(material: Material) -> bool:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture != null
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		for parameter_name in ["base_texture", "albedo_texture", "texture_albedo"]:
			if shader_material.get_shader_parameter(parameter_name) is Texture2D:
				return true
	return false


func _custom_skin_current_animation_node(player: Node) -> String:
	var skin = player.get("_active_skin_node") as Node
	if not skin:
		return ""
	var tree := _find_animation_tree(skin)
	if not tree:
		return ""
	var playback = tree.get("parameters/playback")
	if playback is AnimationNodeStateMachinePlayback:
		return str((playback as AnimationNodeStateMachinePlayback).get_current_node())
	return ""


func _find_animation_tree(node: Node) -> AnimationTree:
	if node is AnimationTree:
		return node as AnimationTree
	for child in node.get_children():
		var found := _find_animation_tree(child)
		if found:
			return found
	return null


func _remote_visual_policy_applied(player: Node) -> bool:
	var skin = player.get("_active_skin_node") as Node
	if not skin:
		return false
	var stats := {"geometry_count": 0, "shadow_off": 0, "gi_disabled": 0, "lod_limited": 0}
	_collect_remote_visual_policy_stats(skin, stats)
	var geometry_count := int(stats.get("geometry_count", 0))
	return geometry_count > 0 \
		and int(stats.get("shadow_off", 0)) == geometry_count \
		and int(stats.get("gi_disabled", 0)) == geometry_count \
		and int(stats.get("lod_limited", 0)) == geometry_count


func _collect_remote_visual_policy_stats(node: Node, stats: Dictionary) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		stats["geometry_count"] = int(stats.get("geometry_count", 0)) + 1
		if geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			stats["shadow_off"] = int(stats.get("shadow_off", 0)) + 1
		if geometry.gi_mode == GeometryInstance3D.GI_MODE_DISABLED:
			stats["gi_disabled"] = int(stats.get("gi_disabled", 0)) + 1
		if geometry.lod_bias <= 0.651:
			stats["lod_limited"] = int(stats.get("lod_limited", 0)) + 1
	for child in node.get_children():
		if child is Node:
			_collect_remote_visual_policy_stats(child as Node, stats)


func _has_descendant_named(node: Node, node_name: String) -> bool:
	if node.name == node_name:
		return true
	for child in node.get_children():
		if _has_descendant_named(child, node_name):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
