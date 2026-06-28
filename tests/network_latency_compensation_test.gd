extends Node

var failures: Array[String] = []


class RemoteAuthorityProbe:
	extends Node

	func _is_local_authority() -> bool:
		return false


class SemanticActionProbe:
	extends Node

	var events: Array[Dictionary] = []

	func apply_network_action_event(event: Dictionary) -> void:
		events.append(event.duplicate(true))


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_netfox_tick_loop_aligned_to_physics()
	_test_player_input_state_sequence_and_fresh_sample()
	await _test_player_input_state_consumes_frame_buffer()
	await _test_remote_runtime_processing_is_suppressed()
	_test_player_action_bus_sanitizes_semantic_events()
	await _test_player_action_bus_applies_remote_semantic_events_once()
	await _test_player_movement_motor_rolls_minimal_state()
	await _test_player_movement_motor_can_drive_player_root()
	await _test_rewind_history_hits_previous_player_position()
	await _test_rewind_history_excludes_owner_peer()
	await _test_rewind_history_queries_cone_and_radius()
	_test_map_prop_impact_uses_rewind_query_tick()
	_test_core_rewind_gameplay_paths_use_input_ticks()
	await _test_chameleon_paint_event_stream_is_replayable()

	if failures.is_empty():
		print("[NetworkLatencyCompensationTest] PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("[NetworkLatencyCompensationTest] " + failure)
		get_tree().quit(1)


func _test_netfox_tick_loop_aligned_to_physics() -> void:
	_expect(ProjectSettings.get_setting("netfox/time/sync_to_physics", false) == true, "NetFox NetworkTime should run inside physics ticks for movement rollback")
	_expect(int(ProjectSettings.get_setting("netfox/time/tickrate", 0)) == int(Engine.physics_ticks_per_second), "NetFox tickrate should match the physics tick rate")
	_expect(float(ProjectSettings.get_setting("netfox/time/sync_interval", 0.25)) <= 0.11, "NetFox time sync interval should stay tuned for low-latency party-game feedback")
	_expect(int(ProjectSettings.get_setting("netfox/time/sync_samples", 8)) <= 6, "NetFox time sync should not wait on an overly large sample window")
	_expect(int(ProjectSettings.get_setting("netfox/time/sync_adjust_steps", 8)) <= 4, "NetFox clock correction should converge quickly on LAN/low-jitter links")
	_expect(float(ProjectSettings.get_setting("netfox/time/recalibrate_threshold", 8.0)) <= 1.1, "NetFox should quickly recalibrate large clock offsets instead of hiding them as input delay")


func _test_player_input_state_sequence_and_fresh_sample() -> void:
	var input_state: PlayerInputState = PlayerInputState.new()
	input_state.capture_only_when_authority = false
	add_child(input_state)
	input_state.sample_now(NetworkTime.tick)
	_expect(input_state.tick == NetworkTime.tick, "PlayerInputState should store the sampled netfox tick")
	_expect(input_state.sequence == 1, "PlayerInputState should increment its sample sequence")
	_expect(input_state.has_fresh_sample(), "PlayerInputState should treat the current tick as fresh")
	var first_intent: int = input_state.allocate_intent_sequence()
	var second_intent: int = input_state.allocate_intent_sequence()
	_expect(second_intent == first_intent + 1, "PlayerInputState should allocate monotonic intent sequences")
	input_state.queue_free()


func _test_player_input_state_consumes_frame_buffer() -> void:
	var input_state: PlayerInputState = PlayerInputState.new()
	input_state.capture_only_when_authority = false
	add_child(input_state)
	await get_tree().process_frame
	input_state.set("_move_axis_buffer", Vector2(0.0, -2.0))
	input_state.set("_move_axis_sample_count", 2)
	input_state.set("_jump_pressed_buffer", true)
	input_state.set("_paint_pressed_buffer", true)
	input_state.sample_now(222)
	_expect(input_state.tick == 222, "PlayerInputState should keep explicit sampled ticks when consuming buffered input")
	_expect(input_state.move_axis.distance_to(Vector2(0.0, -1.0)) < 0.001, "PlayerInputState should average buffered movement input at tick time")
	_expect(input_state.jump_pressed, "PlayerInputState should preserve one-shot jump input until the next tick")
	_expect(input_state.paint_pressed, "PlayerInputState should preserve one-shot paint input until the next tick")
	_expect(not bool(input_state.get("_jump_pressed_buffer")), "PlayerInputState should consume one-shot buffers after sampling")
	_expect(int(input_state.get("_move_axis_sample_count")) == 0, "PlayerInputState should clear continuous movement buffers after sampling")
	input_state.queue_free()
	await get_tree().process_frame


func _test_remote_runtime_processing_is_suppressed() -> void:
	var remote_probe: RemoteAuthorityProbe = RemoteAuthorityProbe.new()
	remote_probe.name = "2"
	add_child(remote_probe)
	var input_state: PlayerInputState = PlayerInputState.new()
	input_state.name = "PlayerInputState"
	remote_probe.add_child(input_state)
	var motor: PlayerMovementMotor = PlayerMovementMotor.new()
	motor.name = "MovementMotor"
	motor.mirror_player_physics_state = false
	remote_probe.add_child(motor)
	await get_tree().process_frame
	_expect(not input_state.is_processing(), "Remote PlayerInputState should not poll local Input every frame")
	_expect(not NetworkTime.before_tick_loop.is_connected(input_state._before_tick_loop), "Remote PlayerInputState should not stay connected to the netfox tick input sampler")
	_expect(not motor.is_processing(), "MovementMotor should never run frame process")
	_expect(not motor.is_physics_processing(), "MovementMotor should respect mirror_player_physics_state=false after ready/export setup")
	remote_probe.queue_free()
	await get_tree().process_frame


func _test_player_action_bus_sanitizes_semantic_events() -> void:
	var action_bus: PlayerActionBus = PlayerActionBus.new()
	add_child(action_bus)
	var raw_event: Dictionary = {
		"source_peer_id": 2,
		"tick": 55,
		"sequence": 9,
		"action": "Jump Now!",
		"payload": {
			"jump_type": "Jump2",
			"direction": Vector3.RIGHT,
			"unsupported_array": [1, 2, 3],
		},
	}
	var event: Dictionary = action_bus.sanitize_action_event(raw_event, 7)
	_expect(int(event.get("source_peer_id", 0)) == 7, "PlayerActionBus should allow server-forced source peer ids")
	_expect(str(event.get("action", "")) == "jump_now", "PlayerActionBus should normalize action names")
	var payload: Dictionary = event.get("payload", {})
	_expect(payload.get("jump_type", "") == "Jump2", "PlayerActionBus should preserve string payload values")
	_expect(payload.get("direction", Vector3.ZERO) == Vector3.RIGHT, "PlayerActionBus should preserve Vector3 payload values")
	_expect(not payload.has("unsupported_array"), "PlayerActionBus should drop unsupported payload values")
	action_bus.queue_free()


func _test_player_action_bus_applies_remote_semantic_events_once() -> void:
	var player: SemanticActionProbe = SemanticActionProbe.new()
	player.name = "SemanticActionProbe"
	add_child(player)
	var action_bus: PlayerActionBus = PlayerActionBus.new()
	action_bus.name = "PlayerActionBus"
	player.add_child(action_bus)
	await get_tree().process_frame

	var event: Dictionary = action_bus.sanitize_action_event({
		"source_peer_id": 2,
		"tick": 144,
		"sequence": 21,
		"action": "skin_performance",
		"payload": {"action": "dance"},
	}, 2)
	_expect(action_bus.apply_action_event(event), "PlayerActionBus should apply a valid remote semantic action event")
	_expect(player.events.size() == 1, "PlayerActionBus should route remote semantic actions to the owning player")
	_expect(not action_bus.apply_action_event(event), "PlayerActionBus should reject duplicate semantic events by source/tick/sequence/action")
	_expect(player.events.size() == 1, "Duplicate semantic events should not replay local animation or action state")

	var next_event: Dictionary = event.duplicate(true)
	next_event["sequence"] = 22
	next_event["payload"] = {"action": "victory"}
	_expect(action_bus.apply_action_event(next_event), "PlayerActionBus should accept a new semantic action sequence")
	_expect(player.events.size() == 2, "PlayerActionBus should keep later remote semantic actions responsive")

	player.queue_free()
	await get_tree().process_frame


func _test_player_movement_motor_rolls_minimal_state() -> void:
	var player: CharacterBody3D = CharacterBody3D.new()
	player.name = "MotorProbe"
	add_child(player)
	var input_state: PlayerInputState = PlayerInputState.new()
	input_state.name = "PlayerInputState"
	input_state.capture_only_when_authority = false
	player.add_child(input_state)
	var motor: PlayerMovementMotor = PlayerMovementMotor.new()
	motor.name = "MovementMotor"
	player.add_child(motor)
	await get_tree().process_frame

	input_state.tick = NetworkTime.tick
	input_state.sequence = 1
	input_state.move_axis = Vector2(0.0, -1.0)
	input_state.sprint_held = true
	input_state.jump_pressed = false
	motor.capture_from_player()
	motor.simulated_grounded = true
	motor.simulated_position = Vector3.ZERO
	motor.simulated_velocity = Vector3.ZERO
	var state_properties: Array[String] = motor._get_rollback_state_properties()
	_expect(state_properties.has("simulated_position"), "MovementMotor should declare simulated position as rollback state")
	_expect(state_properties.has("simulated_velocity"), "MovementMotor should declare simulated velocity as rollback state")
	_expect(state_properties.has("simulated_can_double_jump"), "MovementMotor should declare double-jump availability as rollback state")
	_expect(state_properties.has("simulated_has_double_jumped"), "MovementMotor should declare double-jump consumption as rollback state")
	_expect(motor._get_interpolated_properties().has("simulated_position"), "MovementMotor should expose position for TickInterpolator smoothing")
	motor._rollback_tick(1.0 / 60.0, 123, true)
	_expect(motor.rollback_ticks_processed == 1, "MovementMotor should process a rollback tick")
	_expect(motor.last_simulated_tick == 123, "MovementMotor should record the last simulated tick")
	_expect(motor.last_input_sequence == 1, "MovementMotor should keep the input sequence that drove simulation")
	_expect(motor.simulated_current_speed > 0.0, "MovementMotor should accelerate from tick input")
	_expect(motor.simulated_position.z < -0.001, "MovementMotor should advance forward in camera-relative space")

	input_state.sequence = 2
	input_state.move_axis = Vector2.ZERO
	input_state.jump_pressed = true
	motor.simulated_grounded = true
	motor.simulated_velocity = Vector3.ZERO
	motor._rollback_tick(1.0 / 60.0, 124, true)
	_expect(motor.simulated_velocity.y > 0.0, "MovementMotor should apply jump input during rollback simulation")
	_expect(not motor.simulated_grounded, "MovementMotor should leave grounded state after jump simulation")
	_expect(motor.simulated_can_double_jump, "MovementMotor should keep double-jump availability after the first jump")
	_expect(not motor.simulated_has_double_jumped, "MovementMotor should not consume double jump on the first jump")

	input_state.sequence = 3
	input_state.jump_pressed = true
	motor.simulated_grounded = false
	motor.simulated_can_double_jump = true
	motor.simulated_has_double_jumped = false
	motor.simulated_velocity = Vector3.ZERO
	motor._rollback_tick(1.0 / 60.0, 125, true)
	_expect(motor.simulated_velocity.y > 0.0, "MovementMotor should apply double-jump input during rollback simulation")
	_expect(motor.simulated_has_double_jumped, "MovementMotor should consume double-jump state during rollback simulation")
	_expect(not motor.simulated_can_double_jump, "MovementMotor should clear double-jump availability after consuming it")

	player.queue_free()
	await get_tree().process_frame


func _test_player_movement_motor_can_drive_player_root() -> void:
	var player: CharacterBody3D = CharacterBody3D.new()
	player.name = "RootMotorProbe"
	add_child(player)
	var input_state: PlayerInputState = PlayerInputState.new()
	input_state.name = "PlayerInputState"
	input_state.capture_only_when_authority = false
	player.add_child(input_state)
	var motor: PlayerMovementMotor = PlayerMovementMotor.new()
	motor.name = "MovementMotor"
	motor.mirror_player_physics_state = false
	motor.apply_simulation_to_player_root = true
	motor.use_character_body_collision = true
	player.add_child(motor)
	await get_tree().process_frame

	input_state.tick = NetworkTime.tick
	input_state.sequence = 11
	input_state.move_axis = Vector2(0.0, -1.0)
	input_state.sprint_held = true
	input_state.jump_pressed = false
	motor.simulated_grounded = true
	motor.simulated_position = Vector3.ZERO
	motor.simulated_velocity = Vector3.ZERO
	motor._rollback_tick(1.0 / 60.0, 130, true)

	_expect(motor.rollback_ticks_processed == 1, "Root-driving MovementMotor should still process rollback ticks")
	_expect(player.global_position.distance_to(motor.simulated_position) < 0.001, "Root-driving MovementMotor should copy rollback state back from the player root")
	_expect(player.global_position.z < -0.001, "Root-driving MovementMotor should move the CharacterBody3D root")
	_expect(player.velocity.distance_to(motor.simulated_velocity) < 0.001, "Root-driving MovementMotor should keep player velocity reconciled with simulated velocity")

	player.queue_free()
	await get_tree().process_frame


func _test_rewind_history_hits_previous_player_position() -> void:
	var history: NetworkRewindHistory = NetworkRewindHistory.new()
	history.max_query_tick_delta = 12
	add_child(history)
	var player: Node3D = _make_player_probe(2, Vector3(5.0, 0.0, 0.0))
	add_child(player)
	await get_tree().process_frame
	history.record_history(100)
	player.global_position = Vector3(8.0, 0.0, 0.0)
	var hit: Dictionary = history.find_player_hit_on_segment(Vector3(0.0, 0.95, 0.0), Vector3.RIGHT, 10.0, 100, 1)
	_expect(not hit.is_empty(), "Rewind history should hit the stored player position")
	_expect(int(hit.get("peer_id", 0)) == 2, "Rewind history should report the hit peer")
	_expect(hit.get("target", null) == player, "Rewind history should preserve the target node reference")
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	_expect(hit_position.x > 4.0 and hit_position.x < 5.5, "Rewind history should use the old position, not the moved position")
	player.queue_free()
	history.queue_free()
	await get_tree().process_frame


func _test_rewind_history_excludes_owner_peer() -> void:
	var history: NetworkRewindHistory = NetworkRewindHistory.new()
	add_child(history)
	var player: Node3D = _make_player_probe(2, Vector3(5.0, 0.0, 0.0))
	add_child(player)
	await get_tree().process_frame
	history.record_history(120)
	var hit: Dictionary = history.find_player_hit_on_segment(Vector3(0.0, 0.95, 0.0), Vector3.RIGHT, 10.0, 120, 2)
	_expect(hit.is_empty(), "Rewind history should not hit the excluded owner peer")
	player.queue_free()
	history.queue_free()
	await get_tree().process_frame


func _test_rewind_history_queries_cone_and_radius() -> void:
	var history: NetworkRewindHistory = NetworkRewindHistory.new()
	history.max_query_tick_delta = 12
	add_child(history)
	var front_player: Node3D = _make_player_probe(2, Vector3(5.0, 0.0, 0.0))
	var side_player: Node3D = _make_player_probe(3, Vector3(0.0, 0.0, 5.0))
	add_child(front_player)
	add_child(side_player)
	await get_tree().process_frame
	history.record_history(140)
	front_player.global_position = Vector3(9.0, 0.0, 0.0)
	var cone_hits: Array[Dictionary] = history.find_players_in_cone(Vector3.ZERO, Vector3.RIGHT, 8.0, 20.0, 140, 1)
	_expect(cone_hits.size() == 1, "Rewind history cone query should select only players inside the historical cone")
	if not cone_hits.is_empty():
		_expect(int(cone_hits[0].get("peer_id", 0)) == 2, "Rewind history cone query should return the historical front player")
	var state: Dictionary = history.get_player_state_at_tick(2, 140)
	_expect(not state.is_empty(), "Rewind history should expose a historical state by peer id")
	_expect((state.get("position", Vector3.ZERO) as Vector3).x < 6.0, "Rewind history state should use the old position")
	_expect(history.player_was_in_radius(2, Vector3(5.0, 0.0, 0.0), 1.0, 140), "Rewind history radius query should accept a historical pickup/impact overlap")
	_expect(not history.player_was_in_radius(3, Vector3(5.0, 0.0, 0.0), 1.0, 140), "Rewind history radius query should reject players outside the historical radius")
	front_player.queue_free()
	side_player.queue_free()
	history.queue_free()
	await get_tree().process_frame


func _test_map_prop_impact_uses_rewind_query_tick() -> void:
	var player_source: String = FileAccess.get_file_as_string("res://scripts/player.gd").replace("\r\n", "\n")
	var fruit_source: String = FileAccess.get_file_as_string("res://scripts/fruit_prop.gd").replace("\r\n", "\n")
	var level_source: String = FileAccess.get_file_as_string("res://scripts/level.gd").replace("\r\n", "\n")
	_expect(player_source.contains("node.apply_player_impact(impact_velocity, prop_position, normal, _is_prop_disguised, get_network_input_tick())"), "Party Monster/map-prop nearby impacts should carry the owner input tick")
	_expect(player_source.contains("collider.apply_player_impact(impact_velocity, collision.get_position(), collision.get_normal(), _is_prop_disguised, get_network_input_tick())"), "Party Monster/map-prop slide impacts should carry the owner input tick")
	_expect(fruit_source.contains("NetworkRewindHistory.find_in_tree(get_tree())") and fruit_source.contains("history.player_was_in_radius(sender_id, check_position, PLAYER_IMPACT_SERVER_MAX_DISTANCE, query_tick)"), "FruitProp authoritative impact validation should use rewind radius checks")
	_expect(level_source.contains("func _server_player_was_near_map_prop_impact") and level_source.contains("history.player_was_in_radius(sender_id, check_position, MAP_PROP_IMPACT_MAX_DISTANCE, query_tick)"), "Level map-prop impact relay should validate client impacts against rewind history")


func _test_core_rewind_gameplay_paths_use_input_ticks() -> void:
	var weapon_source: String = FileAccess.get_file_as_string("res://scripts/weapon_system.gd").replace("\r\n", "\n")
	var flashlight_source: String = FileAccess.get_file_as_string("res://scripts/hunter_flashlight_system.gd").replace("\r\n", "\n")
	var grapple_source: String = FileAccess.get_file_as_string("res://scripts/stalker_grapple_system.gd").replace("\r\n", "\n")
	var ammo_source: String = FileAccess.get_file_as_string("res://scripts/ammo_pickup.gd").replace("\r\n", "\n")
	var accessory_source: String = FileAccess.get_file_as_string("res://scripts/party_monster_accessory_pickup.gd").replace("\r\n", "\n")
	var player_source: String = FileAccess.get_file_as_string("res://scripts/player.gd").replace("\r\n", "\n")
	_expect(weapon_source.contains("var fire_tick: int = _get_fire_tick()"), "Weapon fire requests should capture the owner input tick")
	_expect(weapon_source.contains("_request_fire_rpc.rpc_id(1, aim_dir, shooter_pos, fire_tick, fire_sequence)"), "Weapon fire RPCs should carry the owner input tick and sequence")
	_expect(weapon_source.contains("history.find_player_hit_on_segment(shooter_pos, aim_dir, max_distance, fire_tick, sender_id)"), "Weapon hit validation should use rewind history at the fire tick")
	_expect(flashlight_source.contains("var query_tick: int = _flashlight_query_tick()"), "Flashlight pose and toggle requests should capture the owner input tick")
	_expect(flashlight_source.contains("history.find_players_in_cone(origin, direction, RANGE, SPOT_ANGLE * 0.5, query_tick, sender_id)"), "Flashlight reveal should query rewind history at the owner input tick")
	_expect(flashlight_source.contains("target.call(\"apply_network_action_event\""), "Flashlight reveal should arrive as a semantic network action on the exposed target")
	_expect(grapple_source.contains("var query_tick: int = _grapple_query_tick()"), "Stalker grapple requests should capture the owner input tick")
	_expect(grapple_source.contains("history.find_player_hit_on_segment(origin, clean_direction, RANGE, query_tick, excluded_peer_id)"), "Stalker grapple target validation should use rewind history")
	_expect(ammo_source.contains("_request_pickup_rpc.rpc_id(1, _pickup_query_tick_for_body(body))"), "Ammo pickup client requests should carry the owner input tick")
	_expect(ammo_source.contains("history.player_was_in_radius(pid, global_position, PICKUP_RANGE, query_tick)"), "Ammo pickup validation should use rewind history radius checks")
	_expect(accessory_source.contains("_request_pickup_rpc.rpc_id(1, query_tick)"), "Party Monster accessory pickup requests should carry the owner input tick")
	_expect(accessory_source.contains("history.player_was_in_radius(peer_id, global_position, PICKUP_RANGE + 0.9, query_tick)"), "Party Monster accessory pickup validation should use rewind history radius checks")
	_expect(player_source.contains("_request_party_monster_trip_reaction_rpc.rpc_id(1, clean_direction, clean_contact_point, clean_query_tick)"), "Party Monster trip requests should carry contact point and owner input tick")
	_expect(player_source.contains("func _server_party_monster_trip_contact_is_valid") and player_source.contains("history.player_was_in_radius(sender_id, check_position, PARTY_MONSTER_TRIP_REWIND_RADIUS, query_tick)"), "Party Monster trip validation should use rewind history radius checks")


func _test_chameleon_paint_event_stream_is_replayable() -> void:
	var player_scene: PackedScene = load("res://scenes/level/player.tscn") as PackedScene
	var player: Character = player_scene.instantiate() as Character
	player.name = "1"
	add_child(player)
	await get_tree().process_frame
	player.clear_camouflage_paint_event_log()
	player._start_camouflage_brush_visual(Color(0.16, 0.24, 0.36, 1.0), 2, 76)
	var start_events: Array[Dictionary] = player.get_camouflage_paint_event_log()
	_expect(start_events.size() == 1, "Chameleon paint should record brush start/base color as a replayable event")
	if not start_events.is_empty():
		var start_event: Dictionary = start_events[0]
		_expect(str(start_event.get("type", "")) == "start", "Chameleon paint start event should preserve its event type")
		_expect(int(start_event.get("chunk_index", 0)) == -1, "Chameleon paint start event should keep a distinct chunk index")
		var start_payload: Dictionary = start_event.get("payload", {})
		_expect(start_payload.get("base_color", Color.WHITE) == Color(0.16, 0.24, 0.36, 1.0), "Chameleon paint start event should preserve base color")
	var uvs: PackedVector2Array = PackedVector2Array([Vector2(0.25, 0.25), Vector2(0.35, 0.3)])
	var world_positions: PackedVector3Array = PackedVector3Array([Vector3(0.0, 1.0, 0.0), Vector3(0.1, 1.0, 0.0)])
	var brush_radii: PackedFloat32Array = PackedFloat32Array([0.035, 0.04])
	player._apply_camouflage_brush_stroke_batch(
		uvs,
		Color(0.2, 0.85, 0.45, 1.0),
		0.045,
		0.0,
		world_positions,
		Vector3.UP,
		"",
		0,
		brush_radii,
		PackedVector2Array(),
		PackedInt32Array(),
		PackedFloat32Array(),
		0.4,
		0.05,
		0.6,
		2,
		77,
		0
	)
	var events: Array[Dictionary] = player.get_camouflage_paint_event_log()
	_expect(events.size() == 2, "Chameleon paint should record start plus the first replicated batch as replayable events")
	if events.size() >= 2:
		var event: Dictionary = events[1]
		_expect(str(event.get("type", "")) == "stroke_batch", "Chameleon paint event should preserve the batch event type")
		_expect(int(event.get("source_peer_id", 0)) == 2, "Chameleon paint event should preserve source peer id")
		_expect(int(event.get("paint_sequence", 0)) == 77, "Chameleon paint event should preserve paint sequence")
		var payload: Dictionary = event.get("payload", {})
		var logged_uvs: PackedVector2Array = payload.get("uvs", PackedVector2Array())
		_expect(logged_uvs.size() == 2, "Chameleon paint event should keep the compact stroke payload")
	player._apply_camouflage_brush_stroke_batch(
		uvs,
		Color(0.2, 0.85, 0.45, 1.0),
		0.045,
		0.0,
		world_positions,
		Vector3.UP,
		"",
		0,
		brush_radii,
		PackedVector2Array(),
		PackedInt32Array(),
		PackedFloat32Array(),
		0.4,
		0.05,
		0.6,
		2,
		77,
		0
	)
	_expect(player.get_camouflage_paint_event_log().size() == 2, "Chameleon paint event stream should dedupe server echoes by source/sequence/chunk")
	var replayed_count: int = player.replay_camouflage_paint_event_log(true)
	_expect(replayed_count == 2, "Chameleon paint event stream should replay logged start and paint batches")
	_expect(player.get_camouflage_paint_event_log().size() == 2, "Replaying Chameleon paint should not append duplicate events")
	player.queue_free()
	await get_tree().process_frame


func _make_player_probe(peer_id: int, next_position: Vector3) -> Node3D:
	var player: Node3D = Node3D.new()
	player.name = str(peer_id)
	player.add_to_group("players")
	player.position = next_position
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.0
	collision.shape = capsule
	player.add_child(collision)
	return player


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
