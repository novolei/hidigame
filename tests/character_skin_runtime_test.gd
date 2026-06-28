extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_default_skin_uses_basic_humanoid_visual()
	await _test_default_hunter_uses_hunter_shooter_visual()
	await _test_prep_tint_preserves_custom_skin_textures()
	await _test_prep_tint_skips_empty_mesh_surfaces()
	await _test_remote_custom_skin_animates_from_network_motion()
	await _test_remote_default_skins_animate_from_netfox_velocity()
	await _test_remote_party_monster_variants_animate_from_netfox_velocity()
	await _test_remote_party_monster_visual_state_recovers_fall_pose()
	await _test_remote_party_monster_visual_state_forces_stale_reaction_recovery()
	await _test_remote_party_monster_visual_state_uses_directional_locomotion()
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


func _test_prep_tint_skips_empty_mesh_surfaces() -> void:
	Network.players = {
		6: _player("EmptyMeshProbe", Network.Role.HUNTER, CharacterSkinCatalog.DEFAULT_ID),
	}
	var player := _spawn_player("6")
	await get_tree().process_frame
	await get_tree().process_frame

	var empty_mesh := MeshInstance3D.new()
	empty_mesh.name = "EmptySurfaceTintProbe"
	empty_mesh.mesh = ArrayMesh.new()
	player.add_child(empty_mesh)
	_expect(player._get_mesh_surface_count(empty_mesh) == 0, "Empty mesh instances should expose zero tintable surfaces")
	_expect(player._get_mesh_surface_material(empty_mesh, 0) == null, "Empty mesh material lookup should not touch missing override slots")
	player.set_prep_locked(true)

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
	var robot_animation := player.get_node_or_null("3DGodotRobot/AnimationPlayer") as AnimationPlayer
	_expect(robot_animation == null or not robot_animation.active, "Hidden built-in 3DGodotRobot AnimationPlayer should be inactive when Hunter shooter skin is active")
	var skin_animation := _find_animation_player(skin)
	_expect(skin_animation == null or skin_animation.active, "Visible custom skin AnimationPlayer should remain active")

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


func _test_remote_default_skins_animate_from_netfox_velocity() -> void:
	var cases := [
		{"peer_id": 8, "nick": "RemoteBasic", "role": Network.Role.CHAMELEON, "model_id": CharacterSkinCatalog.DEFAULT_ID, "expected": "Run"},
		{"peer_id": 9, "nick": "RemoteHunter", "role": Network.Role.HUNTER, "model_id": CharacterSkinCatalog.DEFAULT_ID, "expected": "2HandSprint"},
	]
	for test_case in cases:
		var peer_id := int(test_case.get("peer_id", 0))
		Network.players = {
			peer_id: _player(str(test_case.get("nick", "Remote")), int(test_case.get("role", Network.Role.CHAMELEON)), str(test_case.get("model_id", CharacterSkinCatalog.DEFAULT_ID))),
		}
		var player := _spawn_player(str(peer_id))
		await get_tree().process_frame
		await get_tree().process_frame

		player._animate_remote_skin_from_network_motion(0.1)
		_set_fresh_netfox_visual_velocity(player, Vector3(Character.RUN_SPEED, 0.0, 0.0))
		player._animate_remote_skin_from_network_motion(0.1)
		await get_tree().process_frame

		var current_animation := _active_skin_current_animation(player)
		var expected := str(test_case.get("expected", ""))
		_expect(current_animation == expected, "Remote default skin should use netfox velocity for run animation; expected=" + expected + " current=" + current_animation)
		player.queue_free()
		await get_tree().process_frame


func _test_remote_party_monster_variants_animate_from_netfox_velocity() -> void:
	var party_monster_ids := _party_monster_model_ids()
	_expect(not party_monster_ids.is_empty(), "Party Monster catalog should expose variants for remote netfox animation coverage")
	var peer_id := 20
	for model_id in party_monster_ids:
		Network.players = {
			peer_id: _player("RemoteParty" + str(peer_id), Network.Role.CHAMELEON, model_id),
		}
		var player := _spawn_player(str(peer_id))
		await get_tree().process_frame
		await get_tree().process_frame

		player._animate_remote_skin_from_network_motion(0.1)
		_set_fresh_netfox_visual_velocity(player, Vector3(Character.RUN_SPEED, 0.0, 0.0))
		player._animate_remote_skin_from_network_motion(0.1)
		await get_tree().process_frame

		var current_action := _active_skin_current_action(player)
		_expect(current_action == "run", "Remote Party Monster variant should use netfox velocity for run action: " + model_id + " current=" + current_action)
		player.queue_free()
		await get_tree().process_frame
		peer_id += 1


func _test_remote_party_monster_visual_state_recovers_fall_pose() -> void:
	var party_monster_ids := _party_monster_model_ids()
	_expect(not party_monster_ids.is_empty(), "Party Monster catalog should expose variants for visual state recovery")
	if party_monster_ids.is_empty():
		return
	var peer_id := 70
	Network.players = {
		peer_id: _player("RemotePartyVisualState", Network.Role.CHAMELEON, party_monster_ids[0]),
	}
	var player := _spawn_player(str(peer_id))
	await get_tree().process_frame
	await get_tree().process_frame

	player._animate_remote_skin_from_network_motion(0.1)
	player._play_skin_action("fall")
	await get_tree().process_frame
	_expect(_active_skin_current_action(player) == "fall", "Remote Party Monster setup should enter fall action before recovery")
	player.apply_network_visual_state({"action": "idle", "action_seq": 11, "action_tick": 120, "yaw": 1.25, "grounded": true, "move_speed": 0.0})
	player._animate_remote_skin_from_network_motion(0.1)
	await get_tree().process_frame

	var recovered_action := _active_skin_current_action(player)
	_expect(recovered_action == "idle", "Synced visual state should recover a remote Party Monster from fall pose; current=" + recovered_action)
	var body := player.get("_body") as Node3D
	if body:
		_expect(absf(wrapf(body.rotation.y - 1.25, -PI, PI)) < 0.1, "Synced visual state should steer remote body yaw toward the owner yaw")
	player._play_skin_action("trip")
	player.set("_party_monster_trip_action_locked", true)
	player.set("_party_monster_trip_reaction_lock_remaining", 2.0)
	_expect(bool(player.get("_party_monster_trip_action_locked")), "Remote Party Monster setup should simulate a stale trip lock before visual-state recovery")
	player.apply_network_visual_state({"action": "idle", "action_seq": 12, "action_tick": 121, "yaw": 1.5, "grounded": true, "move_speed": 0.0})
	player._animate_remote_skin_from_network_motion(0.1)
	await get_tree().process_frame
	var trip_recovered_action := _active_skin_current_action(player)
	_expect(trip_recovered_action == "idle", "Synced visual state should force-recover a remote Party Monster from trip lock; current=" + trip_recovered_action)
	_expect(not bool(player.get("_party_monster_trip_action_locked")), "Synced visual state should clear stale remote trip locks")
	var visual_state: Dictionary = player.get_network_visual_state()
	_expect(visual_state.has("action") and visual_state.has("yaw") and visual_state.has("grounded"), "Player should expose a compact network visual state")
	_expect(visual_state.has("action_seq") and visual_state.has("action_tick"), "Player visual state should include action sequencing for short-action recovery")
	_expect(visual_state.has("move_x") and visual_state.has("move_z") and visual_state.has("sprinting"), "Player visual state should include movement intent for immediate remote locomotion")

	player.queue_free()
	await get_tree().process_frame


func _test_remote_party_monster_visual_state_forces_stale_reaction_recovery() -> void:
	var party_monster_ids := _party_monster_model_ids()
	_expect(not party_monster_ids.is_empty(), "Party Monster catalog should expose variants for stale visual-state recovery")
	if party_monster_ids.is_empty():
		return
	var peer_id := 72
	Network.players = {
		peer_id: _player("RemotePartyStaleRecovery", Network.Role.CHAMELEON, party_monster_ids[0]),
	}
	var player := _spawn_player(str(peer_id))
	await get_tree().process_frame
	await get_tree().process_frame

	player._play_skin_action("trip")
	player.set("_network_visual_action_sequence", 31)
	player.set("_network_visual_applied_action_sequence", 31)
	player.apply_network_visual_state({"action": "idle", "action_seq": 31, "action_tick": 180, "yaw": 0.0, "grounded": true, "move_speed": 0.0})
	player._animate_remote_skin_from_network_motion(0.1)
	await get_tree().process_frame
	_expect(_active_skin_current_action(player) == "idle", "Synced visual state should force recovery even when the same action sequence was already seen; current=" + _active_skin_current_action(player))

	player._play_skin_action("fall")
	player.set("_network_visual_action_sequence", 32)
	player.set("_network_visual_applied_action_sequence", 32)
	player.apply_network_visual_state({"action": "run", "action_seq": 32, "action_tick": 181, "yaw": 0.0, "grounded": true, "move_speed": Character.RUN_SPEED, "move_x": 0.0, "move_z": -1.0, "sprinting": true})
	player._animate_remote_skin_from_network_motion(0.1)
	await get_tree().process_frame
	_expect(_active_skin_current_action(player).begins_with("run"), "Synced run visual state should recover stale fall pose without needing a new sequence; current=" + _active_skin_current_action(player))

	player.queue_free()
	await get_tree().process_frame


func _test_remote_party_monster_visual_state_uses_directional_locomotion() -> void:
	var party_monster_ids := _party_monster_model_ids()
	_expect(not party_monster_ids.is_empty(), "Party Monster catalog should expose variants for directional locomotion")
	if party_monster_ids.is_empty():
		return
	var peer_id := 71
	Network.players = {
		peer_id: _player("RemotePartyDirectional", Network.Role.CHAMELEON, party_monster_ids[0]),
	}
	var player := _spawn_player(str(peer_id))
	await get_tree().process_frame
	await get_tree().process_frame

	player.apply_network_visual_state({
		"action": "move",
		"action_seq": 21,
		"action_tick": 140,
		"yaw": 0.0,
		"grounded": true,
		"move_speed": Character.RUN_SPEED,
		"move_x": 1.0,
		"move_z": 0.0,
		"sprinting": true,
	})
	player._animate_remote_skin_from_network_motion(0.1)
	await get_tree().process_frame
	_expect(_active_skin_current_action(player) == "run_right", "Remote Party Monster should use owner movement intent for right-run animation; current=" + _active_skin_current_action(player))

	player.apply_network_visual_state({
		"action": "move",
		"action_seq": 22,
		"action_tick": 141,
		"yaw": 0.0,
		"grounded": true,
		"move_speed": Character.WALK_SPEED,
		"move_x": 0.0,
		"move_z": 1.0,
		"sprinting": false,
	})
	player._animate_remote_skin_from_network_motion(0.1)
	await get_tree().process_frame
	_expect(_active_skin_current_action(player) == "walk_backward", "Remote Party Monster should use owner movement intent for backward-walk animation; current=" + _active_skin_current_action(player))

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
	var player := _spawn_player("1")
	await get_tree().process_frame
	var old_synchronizer := player.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	_expect(old_synchronizer == null, "Player scene should no longer use MultiplayerSynchronizer for high-frequency position sync")
	var transform_sync := player.get_node_or_null("NetfoxTransformSync") as NetfoxPlayerTransformSync
	_expect(transform_sync != null, "Player scene should use NetfoxTransformSync for network tick snapshots")
	var input_state := player.get_node_or_null("PlayerInputState") as PlayerInputState
	_expect(input_state != null and input_state.buffer_frame_input, "PlayerInputState should buffer high-FPS input before netfox ticks")
	var movement_motor := player.get_node_or_null("MovementMotor") as PlayerMovementMotor
	_expect(movement_motor != null, "Player scene should expose rollback movement state for reconciliation")
	var rollback_sync := player.get_node_or_null("RollbackSynchronizer") as RollbackSynchronizer
	_expect(rollback_sync != null, "Player scene should use RollbackSynchronizer for movement state reconciliation")
	var tick_interpolator := player.get_node_or_null("MovementTickInterpolator") as TickInterpolator
	_expect(tick_interpolator != null, "Player scene should use TickInterpolator for rollback visual smoothing")
	if movement_motor:
		_expect(not movement_motor.mirror_player_physics_state, "MovementMotor should avoid mirroring once rollback owns normal root movement")
		_expect(movement_motor.apply_simulation_to_player_root, "MovementMotor should drive the player root from rollback simulation")
		_expect(movement_motor._get_rollback_state_properties().has("simulated_position"), "MovementMotor should declare a rollback position state")
		_expect(movement_motor._get_rollback_state_properties().has("simulated_can_double_jump"), "MovementMotor should declare rollback double-jump availability")
		_expect(movement_motor._get_rollback_state_properties().has("simulated_has_double_jumped"), "MovementMotor should declare rollback double-jump consumption")
		_expect(movement_motor._get_interpolated_properties().has("simulated_position"), "MovementMotor should declare a visual interpolation position state")
	if rollback_sync:
		_expect(rollback_sync.enable_prediction, "Rollback movement should allow client-side prediction")
		_expect(rollback_sync.state_properties.has("MovementMotor:simulated_position"), "Rollback movement should reconcile simulated position")
		_expect(rollback_sync.state_properties.has("MovementMotor:simulated_can_double_jump"), "Rollback movement should reconcile double-jump availability")
		_expect(rollback_sync.state_properties.has("MovementMotor:simulated_has_double_jumped"), "Rollback movement should reconcile double-jump consumption")
		_expect(rollback_sync.input_properties.has("PlayerInputState:move_axis"), "Rollback movement should replay movement input")
		_expect(not rollback_sync.enable_input_broadcast, "Rollback movement input should not broadcast to every peer")
	if tick_interpolator:
		_expect(tick_interpolator.properties.has("MovementMotor:simulated_position"), "TickInterpolator should smooth the reconciled movement state")
	if transform_sync:
		_expect(transform_sync.send_every_ticks == 1, "Moving player transform snapshots should still be allowed every network tick")
		_expect(transform_sync.idle_send_every_ticks > transform_sync.send_every_ticks, "Idle player transform snapshots should use a lower-rate budget")
		_expect(transform_sync.force_send_every_ticks >= transform_sync.idle_send_every_ticks, "Idle player transform snapshots should keep a bounded forced refresh")
		_expect(transform_sync.min_position_delta > 0.0, "Transform sync should suppress tiny idle position jitter")
		_expect(transform_sync.min_velocity_delta > 0.0, "Transform sync should suppress tiny idle velocity jitter")
		_expect(transform_sync.interpolation_delay_ticks == 1, "Remote transform sync should keep the minimum visual interpolation buffer at 60 tps")
		_expect(transform_sync.max_extrapolation_ticks == 5, "Remote transform sync should allow bounded short dead-reckoning when reducing interpolation delay")
		_expect(transform_sync.render_lerp_speed >= 50.0, "Remote transform sync should chase sampled motion quickly enough for responsive remote visuals")
		_expect(transform_sync.adaptive_latency_extra_ticks <= 3, "Remote transform sync should cap adaptive latency so RTT does not become visible input lag")
		_expect(transform_sync.adaptive_rtt_delay_weight <= 0.35, "Remote transform sync should not buffer a full RTT for visual interpolation")
		_expect(transform_sync.adaptive_jitter_delay_weight > transform_sync.adaptive_rtt_delay_weight, "Remote transform sync should react primarily to jitter when adding visual buffer")
		_expect(transform_sync.max_velocity_mps <= 80.0, "Remote transform sync should clamp extreme velocities")
		_expect(NetfoxPlayerTransformSync.TRANSFORM_SNAPSHOT_APPROX_BYTES >= 80, "Transform sync telemetry should include the compact visual-state payload")
		_expect(player.has_method("get_network_visual_state"), "Player should expose owner visual state for NetFox snapshots")
		_expect(player.has_method("apply_network_visual_state"), "Player should accept server-forwarded visual state for remote animation")
		_expect(transform_sync.has_method("get_remote_visual_velocity"), "Transform sync should expose interpolated visual velocity for remote skin animation")
		_expect(transform_sync.has_method("has_fresh_remote_visual_sample"), "Transform sync should expose visual sample freshness for animation fallbacks")
		transform_sync.set("_last_sent_tick", -1000000)
		transform_sync.set("_has_last_submitted_transform", false)
		_expect(bool(transform_sync.call("_should_submit_current_transform", 0)), "Transform sync should always submit its first owner snapshot")
		player.velocity = Vector3.ZERO
		transform_sync.set("_last_sent_tick", 0)
		transform_sync.set("_has_last_submitted_transform", true)
		transform_sync.set("_last_submitted_position", player.global_position)
		transform_sync.set("_last_submitted_velocity", Vector3.ZERO)
		var submitted_visual_state: Dictionary = transform_sync.call("_collect_root_visual_state") as Dictionary
		transform_sync.set("_last_submitted_visual_signature", transform_sync.call("_visual_state_signature", submitted_visual_state))
		_expect(not bool(transform_sync.call("_should_submit_current_transform", 1)), "Idle transform sync should skip the next unchanged tick")
		_expect(bool(transform_sync.call("_should_submit_current_transform", transform_sync.force_send_every_ticks)), "Idle transform sync should force a bounded refresh")
		var transform_sync_source := FileAccess.get_file_as_string("res://scripts/network/netfox_player_transform_sync.gd")
		_expect(transform_sync_source.contains("_root_authority_peer_id()"), "Server-owned player transform broadcasts should use authority source ids instead of node-name parsing")
		_expect(transform_sync_source.contains("player_transform.owner_idle_skip"), "Transform sync telemetry should record idle-owner skipped snapshots")
		_expect(transform_sync_source.contains("player_transform.remote_sample_"), "Transform sync telemetry should record remote interpolation sample modes")
		_expect(transform_sync_source.contains("extrapolate_clamped"), "Transform sync telemetry should expose clamped extrapolation as a stutter signal")
		var stable_delay := int(transform_sync.call("_adaptive_remote_interpolation_delay_ticks", 0.060, 0.004, 1.0 / 60.0))
		_expect(stable_delay == transform_sync.interpolation_delay_ticks, "Stable public latency should stay on the low-latency base delay")
		var rtt_only_delay := int(transform_sync.call("_adaptive_remote_interpolation_delay_ticks", 0.200, 0.0, 1.0 / 60.0))
		_expect(rtt_only_delay <= transform_sync.interpolation_delay_ticks + 1, "High RTT alone should not be converted into a full visual buffer")
		var jitter_delay := int(transform_sync.call("_adaptive_remote_interpolation_delay_ticks", 0.120, 0.040, 1.0 / 60.0))
		_expect(jitter_delay > transform_sync.interpolation_delay_ticks and jitter_delay <= transform_sync.interpolation_delay_ticks + transform_sync.adaptive_latency_extra_ticks, "Jitter should add bounded visual delay")

	var remote_player := _spawn_player("6")
	await get_tree().process_frame
	await get_tree().process_frame
	var remote_rollback_sync := remote_player.get_node_or_null("RollbackSynchronizer") as RollbackSynchronizer
	_expect(remote_rollback_sync != null, "Remote player scene should still include RollbackSynchronizer for local peers")
	if remote_rollback_sync:
		_expect(not remote_rollback_sync.enable_prediction, "Remote player rollback should disable prediction at runtime to avoid simulating every peer")
		_expect(remote_rollback_sync.state_properties.is_empty(), "Remote player rollback should clear state properties after runtime slimming")
		_expect(remote_rollback_sync.input_properties.is_empty(), "Remote player rollback should clear input properties after runtime slimming")
	var remote_tick_interpolator := remote_player.get_node_or_null("MovementTickInterpolator") as TickInterpolator
	_expect(remote_tick_interpolator != null, "Remote player scene should still include MovementTickInterpolator for local peers")
	if remote_tick_interpolator:
		_expect(not remote_tick_interpolator.enabled, "Remote player TickInterpolator should be disabled at runtime when transform sync owns visuals")
	remote_player.queue_free()
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
			for sample_index: int in range(transform_sync.max_snapshots + 3):
				var sample_position: Vector3 = Vector3(float(index), 0.0, float(sample_index) * 0.2)
				var sample_velocity: Vector3 = Vector3(0.0, 0.0, 2.0)
				transform_sync.call("_record_snapshot", sample_index, sample_position, sample_velocity)
			var snapshots: Array = transform_sync.get("_snapshots") as Array
			_expect(snapshots.size() <= transform_sync.max_snapshots, "Synthetic remote bot snapshots should stay bounded for " + str(bot_count) + " bots")
			var interpolated: Dictionary = transform_sync.call("_sample_state", 10.5) as Dictionary
			_expect(str(interpolated.get("mode", "")) == "interpolate", "Synthetic remote bot should interpolate mid-buffer samples for " + str(bot_count) + " bots")
			_expect(str(interpolated.get("curve", "")) == "hermite", "Synthetic remote bot should use velocity-aware Hermite interpolation for " + str(bot_count) + " bots")
			var fallback: Dictionary = transform_sync.call("_interpolate_snapshot_position", Vector3.ZERO, Vector3(200.0, 0.0, 0.0), Vector3.RIGHT, Vector3(-200.0, 0.0, 0.0), 1.0, 0.5) as Dictionary
			_expect(str(fallback.get("curve", "")) == "linear_fallback", "Synthetic remote bot should fall back to linear interpolation when Hermite would overshoot")
			transform_sync.set("adaptive_latency_extra_ticks", 0)
			_expect(int(transform_sync.call("_remote_interpolation_delay_ticks")) == transform_sync.interpolation_delay_ticks, "Synthetic remote bot should keep the configured base interpolation delay when adaptive buffering is disabled")
			var extrapolated: Dictionary = transform_sync.call("_sample_state", 99.0) as Dictionary
			_expect(str(extrapolated.get("mode", "")) == "extrapolate_clamped", "Synthetic remote bot should clamp stale extrapolation for " + str(bot_count) + " bots")
			_expect((extrapolated.get("velocity", Vector3.ONE) as Vector3).is_zero_approx(), "Clamped stale extrapolation should stop feeding old velocity into remote animation")
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


func _set_fresh_netfox_visual_velocity(player: Node, velocity: Vector3) -> void:
	var transform_sync := player.get_node_or_null("NetfoxTransformSync") as NetfoxPlayerTransformSync
	_expect(transform_sync != null, "Player should expose NetfoxTransformSync for visual velocity tests")
	if not transform_sync:
		return
	transform_sync.set("_last_visual_position", player.global_position + velocity * 0.05)
	transform_sync.set("_last_visual_velocity", velocity)
	transform_sync.set("_last_visual_sample_mode", "test")
	transform_sync.set("_last_visual_sample_tick", float(NetworkTime.tick))
	transform_sync.set("_last_visual_sample_msec", Time.get_ticks_msec())


func _party_monster_model_ids() -> Array[String]:
	var ids: Array[String] = []
	for model in CharacterSkinCatalog.all():
		var model_id := str((model as Dictionary).get("id", ""))
		if CharacterSkinCatalog.is_party_monster(model_id):
			ids.append(model_id)
	ids.sort()
	return ids


func _active_skin_current_action(player: Node) -> String:
	var skin = player.get("_active_skin_node") as Node
	if not skin:
		return ""
	if skin.has_method("get_current_animation_action"):
		return str(skin.call("get_current_animation_action"))
	return _active_skin_current_animation(player)


func _active_skin_current_animation(player: Node) -> String:
	var skin = player.get("_active_skin_node") as Node
	if not skin:
		return ""
	if skin.has_method("get_current_animation_clip"):
		return str(skin.call("get_current_animation_clip"))
	var player_node := _find_animation_player(skin)
	if player_node:
		return str(player_node.current_animation)
	return _custom_skin_current_animation_node(player)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


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
