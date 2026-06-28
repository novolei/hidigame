extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_ammo_availability_state_controls_visibility_and_collision()
	await _test_ammo_pickup_uses_lightweight_visuals_and_sized_collision()
	_test_map_prop_sync_budget_coalesces_motion()
	_test_map_prop_sync_budget_caps_flush_size()
	_test_map_prop_sync_budget_defaults_are_play_safe()
	_test_map_prop_sync_budget_batches_rest_states()
	await _test_map_prop_network_state_application()
	_test_map_prop_runtime_visual_policy_limits_mesh_cost()
	await _test_map_prop_non_sleeping_state_requires_meaningful_delta()
	_test_level_applies_map_prop_state_by_name()
	_test_level_map_prop_motion_relevance_filters_far_players()
	_test_level_map_prop_motion_payload_slices_far_states()
	_test_level_map_prop_motion_sync_uses_targeted_rpc()
	await _test_map_prop_impact_server_throttle()
	await _test_map_prop_authoritative_rest_freezes_until_impact()
	await _test_map_prop_authoritative_impact_wakes_body()
	await _test_map_prop_low_motion_rest_forces_sleep()
	_shutdown_network_state()

	if failures.is_empty():
		print("[WorldObjectSyncTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[WorldObjectSyncTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19097, 4)
	_expect(error == OK, "Test multiplayer peer should start")
	if error == OK:
		Network.multiplayer.multiplayer_peer = peer
	Network.players.clear()


func _shutdown_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null


func _test_ammo_availability_state_controls_visibility_and_collision() -> void:
	var ammo := AmmoPickup.new()
	ammo.name = "AmmoProbe"

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = BoxMesh.new()
	mesh.set_surface_override_material(0, StandardMaterial3D.new())
	ammo.add_child(mesh)

	var label := Label3D.new()
	label.name = "Label"
	ammo.add_child(label)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = SphereShape3D.new()
	ammo.add_child(collision)

	add_child(ammo)
	await get_tree().process_frame

	ammo.set_match_active(false)
	await get_tree().process_frame
	_expect(not ammo.visible, "Inactive prep-spawned ammo should be hidden")
	_expect(not ammo.monitoring, "Inactive prep-spawned ammo should stop monitoring")
	_expect(not ammo.monitorable, "Inactive prep-spawned ammo should stop being monitorable")
	_expect(collision.disabled, "Inactive prep-spawned ammo should disable collision")

	ammo.set_match_active(true)
	await get_tree().process_frame
	_expect(ammo.visible, "Activated ammo should become visible before pickup")
	_expect(ammo.monitoring, "Activated ammo should resume monitoring")
	_expect(ammo.monitorable, "Activated ammo should resume being monitorable")
	_expect(not collision.disabled, "Activated ammo should re-enable collision")

	ammo._set_available(false, 12.5)
	await get_tree().process_frame
	_expect(not ammo.visible, "Consumed ammo should be hidden on every peer")
	_expect(not ammo.monitoring, "Consumed ammo should stop monitoring pickups")
	_expect(not ammo.monitorable, "Consumed ammo should stop being monitorable")
	_expect(collision.disabled, "Consumed ammo should disable its collision shape")
	_expect(ammo.respawn_timer > 12.0 and ammo.respawn_timer <= 12.5, "Consumed ammo should keep the server-provided respawn timer")

	ammo._set_available(true, 0.0)
	await get_tree().process_frame
	_expect(ammo.visible, "Respawned ammo should become visible")
	_expect(ammo.monitoring, "Respawned ammo should monitor pickups again")
	_expect(ammo.monitorable, "Respawned ammo should be monitorable again")
	_expect(not collision.disabled, "Respawned ammo should re-enable its collision shape")

	ammo.queue_free()
	await get_tree().process_frame


func _test_ammo_pickup_uses_lightweight_visuals_and_sized_collision() -> void:
	var level: Node = preload("res://scripts/level.gd").new()
	var container: Node3D = Node3D.new()
	container.name = "AmmoPackContainer"
	level.add_child(container)
	var ammo_script: Script = preload("res://scripts/ammo_pickup.gd")
	var probe_types: Array[int] = [AmmoPickup.AmmoType.SMALL, AmmoPickup.AmmoType.MEDIUM, AmmoPickup.AmmoType.LARGE]

	for ammo_type_value: int in probe_types:
		var ammo_name: String = "AmmoLightweightProbe_%d" % ammo_type_value
		var data: Dictionary = {"name": ammo_name, "position": Vector3.ZERO, "type": ammo_type_value}
		level.call("_spawn_one_ammo", container, ammo_script, data)
		var ammo: Area3D = container.get_node_or_null(ammo_name) as Area3D
		_expect(ammo != null, "Level ammo spawn should create an Area3D for type %d" % ammo_type_value)
		if ammo == null:
			continue
		var visual: MeshInstance3D = ammo.get_node_or_null("Mesh") as MeshInstance3D
		_expect(visual != null, "Ammo pickup should use a lightweight runtime mesh for type %d" % ammo_type_value)
		if visual != null:
			_expect(visual.mesh is BoxMesh or visual.mesh is CylinderMesh, "Ammo runtime visual should be a primitive low-poly mesh")
			_expect(visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Ammo runtime visual should not cast active-play shadows")
			_expect(visual.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "Ammo runtime visual should disable GI")
			_expect(visual.visibility_range_end <= 42.0, "Ammo runtime visual should have a local cull range")
		var label: Label3D = ammo.get_node_or_null("Label") as Label3D
		_expect(label != null, "Ammo pickup should keep its floating label")
		if label != null:
			_expect(absf(label.position.y - 0.8) < 0.001, "Ammo label height should match the 0.8m pickup size")
		var collision: CollisionShape3D = ammo.get_node_or_null("PickupTrigger") as CollisionShape3D
		_expect(collision != null, "Ammo pickup should create a named pickup trigger")
		if collision != null and collision.shape is SphereShape3D:
			var sphere: SphereShape3D = collision.shape as SphereShape3D
			var expected_radius: float = AmmoPickup.collision_radius_for_type(ammo_type_value)
			_expect(absf(sphere.radius - expected_radius) < 0.001, "Ammo trigger radius should match type sizing")
			_expect(absf(sphere.radius - 0.8) < 0.001, "Ammo trigger radius should preserve the original pickup marker radius")

	level.free()
	await get_tree().process_frame


func _test_map_prop_sync_budget_coalesces_motion() -> void:
	var budget: MapPropSyncBudget = MapPropSyncBudget.new()
	var first_transform := Transform3D(Basis.IDENTITY, Vector3(1.0, 0.0, 0.0))
	var latest_transform := Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 0.0))
	budget.queue_motion("MapProp_A", first_transform, Vector3(0.1, 0.0, 0.0), Vector3.ZERO, false)
	budget.queue_motion("MapProp_A", latest_transform, Vector3(0.2, 0.0, 0.0), Vector3.UP, false)

	var early_flush: Array[Dictionary] = budget.tick(MapPropSyncBudget.DEFAULT_MOTION_FLUSH_INTERVAL * 0.5)
	_expect(early_flush.is_empty(), "Map prop motion budget should wait for its flush interval")
	_expect(budget.pending_count() == 1, "Map prop motion budget should coalesce repeated prop updates")

	var flushed: Array[Dictionary] = budget.tick(MapPropSyncBudget.DEFAULT_MOTION_FLUSH_INTERVAL)
	_expect(flushed.size() == 1, "Map prop motion budget should flush one coalesced update")
	if flushed.size() == 1:
		var state: Dictionary = flushed[0]
		var synced_transform: Transform3D = state.get("transform", Transform3D.IDENTITY)
		var synced_linear_velocity: Vector3 = state.get("linear_velocity", Vector3.ZERO)
		var synced_angular_velocity: Vector3 = state.get("angular_velocity", Vector3.ZERO)
		_expect(str(state.get("prop_name", "")) == "MapProp_A", "Map prop motion budget should preserve stable prop name")
		_expect(synced_transform.origin.distance_to(latest_transform.origin) < 0.001, "Map prop motion budget should keep the newest transform")
		_expect(synced_linear_velocity.distance_to(Vector3(0.2, 0.0, 0.0)) < 0.001, "Map prop motion budget should keep the newest linear velocity")
		_expect(synced_angular_velocity.distance_to(Vector3.UP) < 0.001, "Map prop motion budget should keep the newest angular velocity")
	_expect(not budget.has_pending(), "Map prop motion budget should clear pending states after flush")

	budget.queue_motion("MapProp_A", latest_transform, Vector3.ZERO, Vector3.ZERO, false)
	budget.clear_motion("MapProp_A")
	_expect(budget.drain().is_empty(), "Reliable rest sync should be able to clear pending motion updates")


func _test_map_prop_sync_budget_caps_flush_size() -> void:
	var budget: MapPropSyncBudget = MapPropSyncBudget.new(MapPropSyncBudget.DEFAULT_MOTION_FLUSH_INTERVAL, 2)
	for index: int in range(5):
		var transform_value: Transform3D = Transform3D(Basis.IDENTITY, Vector3(float(index), 0.0, 0.0))
		budget.queue_motion("MapProp_%d" % index, transform_value, Vector3.RIGHT, Vector3.UP, false)

	var first_flush: Array[Dictionary] = budget.tick(MapPropSyncBudget.DEFAULT_MOTION_FLUSH_INTERVAL)
	_expect(first_flush.size() == 2, "Map prop budget should cap one flush to the configured max state count")
	_expect(budget.pending_count() == 3, "Map prop budget should keep overflow motion states for later ticks")

	var second_flush: Array[Dictionary] = budget.tick(MapPropSyncBudget.DEFAULT_MOTION_FLUSH_INTERVAL)
	_expect(second_flush.size() == 2, "Map prop budget should continue draining overflow states on the next tick")
	_expect(budget.pending_count() == 1, "Map prop budget should keep only undrained overflow states")

	var final_flush: Array[Dictionary] = budget.tick(MapPropSyncBudget.DEFAULT_MOTION_FLUSH_INTERVAL)
	_expect(final_flush.size() == 1, "Map prop budget should eventually drain the final overflow state")
	_expect(not budget.has_pending(), "Map prop budget should be empty after all capped flushes drain")


func _test_map_prop_sync_budget_defaults_are_play_safe() -> void:
	_expect(MapPropSyncBudget.DEFAULT_MOTION_FLUSH_INTERVAL >= 1.0 / 15.0, "Map prop motion budget should not flush faster than 15Hz by default")
	_expect(MapPropSyncBudget.DEFAULT_MAX_MOTION_STATES_PER_FLUSH <= 12, "Map prop motion budget should cap active motion burst size")
	_expect(MapPropSyncBudget.DEFAULT_REST_FLUSH_INTERVAL >= 1.0 / 20.0, "Map prop rest budget should not flush reliable rest states faster than 20Hz by default")
	_expect(MapPropSyncBudget.DEFAULT_MAX_REST_STATES_PER_FLUSH <= 24, "Map prop rest budget should cap reliable rest burst size")


func _test_map_prop_sync_budget_batches_rest_states() -> void:
	var budget: MapPropSyncBudget = MapPropSyncBudget.new()
	budget.max_rest_states_per_flush = 2
	var motion_transform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(9.0, 0.0, 0.0))
	var rest_transform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(10.0, 0.0, 0.0))
	budget.queue_motion("MapProp_0", motion_transform, Vector3.RIGHT, Vector3.UP, false)
	budget.queue_rest("MapProp_0", rest_transform, Vector3.ZERO, Vector3.ZERO, true)
	_expect(budget.pending_count() == 0, "Queued rest state should clear stale pending motion for the same prop")
	_expect(budget.pending_rest_count() == 1, "Queued rest state should be held for reliable batch flushing")

	for index: int in range(1, 4):
		var transform_value: Transform3D = Transform3D(Basis.IDENTITY, Vector3(float(index), 0.0, 0.0))
		budget.queue_rest("MapProp_%d" % index, transform_value, Vector3.ZERO, Vector3.ZERO, true)

	var early_flush: Array[Dictionary] = budget.tick_rest(0.01)
	_expect(early_flush.is_empty(), "Map prop rest budget should wait for its flush interval")
	_expect(budget.pending_rest_count() == 4, "Map prop rest budget should keep all pending rest states before flush")

	var first_flush: Array[Dictionary] = budget.tick_rest(MapPropSyncBudget.DEFAULT_REST_FLUSH_INTERVAL)
	_expect(first_flush.size() == 2, "Map prop rest budget should cap one reliable batch to the configured max state count")
	_expect(budget.pending_rest_count() == 2, "Map prop rest budget should keep overflow rest states for the next reliable batch")

	var second_flush: Array[Dictionary] = budget.tick_rest(MapPropSyncBudget.DEFAULT_REST_FLUSH_INTERVAL)
	_expect(second_flush.size() == 2, "Map prop rest budget should drain overflow rest states on the next tick")
	_expect(not budget.has_pending(), "Map prop budget should be empty after motion and rest queues drain")


func _test_map_prop_network_state_application() -> void:
	var prop := FruitProp.new()
	prop.name = "NetworkedPropProbe"
	add_child(prop)
	await get_tree().process_frame

	var next_transform := Transform3D(Basis.IDENTITY.rotated(Vector3.UP, 0.7), Vector3(3.0, 1.25, -2.0))
	var next_linear := Vector3(0.4, 0.0, -0.2)
	var next_angular := Vector3(0.0, 1.2, 0.0)
	prop._apply_network_physics_state(next_transform, next_linear, next_angular, false, true)

	_expect(prop.freeze, "Client network state application should keep map props kinematic")
	_expect(prop.global_position.distance_to(next_transform.origin) < 0.001, "Map prop should apply replicated transform")
	_expect(prop.linear_velocity.distance_to(next_linear) < 0.001, "Map prop should apply replicated linear velocity")
	_expect(prop.angular_velocity.distance_to(next_angular) < 0.001, "Map prop should apply replicated angular velocity")
	_expect(not prop.sleeping, "Map prop should apply replicated sleeping state")

	prop.queue_free()
	await get_tree().process_frame


func _test_map_prop_runtime_visual_policy_limits_mesh_cost() -> void:
	var prop: FruitProp = FruitProp.new()
	var visual_root: Node3D = Node3D.new()
	visual_root.name = "MapPropVisual"
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "NestedMesh"
	mesh.mesh = BoxMesh.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "NestedCollision"
	collision.shape = BoxShape3D.new()
	visual_root.add_child(mesh)
	visual_root.add_child(collision)

	prop._disable_nested_collisions(visual_root)

	_expect(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Runtime map prop meshes should not cast real-time shadows")
	_expect(mesh.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "Runtime map prop meshes should not contribute to expensive GI")
	_expect(absf(mesh.visibility_range_end - FruitProp.RUNTIME_VISUAL_CULL_RANGE) < 0.001, "Runtime map prop meshes should use the active-play cull range")
	_expect(mesh.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED, "Runtime map prop mesh culling should use cheap hysteresis")
	_expect(collision.disabled, "Imported nested collisions should remain disabled under the authoritative prop body")

	prop.free()
	visual_root.free()


func _test_map_prop_non_sleeping_state_requires_meaningful_delta() -> void:
	var prop: FruitProp = FruitProp.new()
	prop.name = "NonSleepingBroadcastProbe"
	add_child(prop)
	await get_tree().process_frame

	prop.sleeping = false
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop._store_synced_network_state()
	_expect(not prop._should_broadcast_network_state(), "Non-sleeping map props should not broadcast without meaningful motion deltas")

	prop.global_position += Vector3(FruitProp.NETWORK_POSITION_EPSILON * 1.5, 0.0, 0.0)
	_expect(prop._should_broadcast_network_state(), "Map props should still broadcast meaningful position deltas")

	prop.queue_free()
	await get_tree().process_frame


func _test_level_applies_map_prop_state_by_name() -> void:
	var level = preload("res://scripts/level.gd").new()
	var container := Node3D.new()
	container.name = "MapPropContainer"
	level.add_child(container)
	var prop := FruitProp.new()
	prop.name = "MapProp_Unit"
	container.add_child(prop)

	var next_transform := Transform3D(Basis.IDENTITY.rotated(Vector3.UP, -0.35), Vector3(-4.0, 0.9, 5.0))
	var next_linear := Vector3(-0.5, 0.0, 0.6)
	var next_angular := Vector3(0.0, -1.4, 0.0)
	level._apply_map_prop_network_state(prop.name, next_transform, next_linear, next_angular, false)

	_expect(prop.transform.origin.distance_to(next_transform.origin) < 0.001, "Level map prop sync should apply transform by stable prop name")
	_expect(prop.linear_velocity.distance_to(next_linear) < 0.001, "Level map prop sync should apply linear velocity by stable prop name")
	_expect(prop.angular_velocity.distance_to(next_angular) < 0.001, "Level map prop sync should apply angular velocity by stable prop name")

	level.free()


func _test_level_map_prop_motion_relevance_filters_far_players() -> void:
	var level = preload("res://scripts/level.gd").new()
	var players := Node3D.new()
	players.name = "PlayersContainer"
	level.add_child(players)
	var near_player := Node3D.new()
	near_player.name = "8"
	near_player.position = Vector3(2.0, 0.0, 0.0)
	players.add_child(near_player)
	var far_player := Node3D.new()
	far_player.name = "9"
	far_player.position = Vector3(120.0, 0.0, 0.0)
	players.add_child(far_player)
	Network.players[8] = {"role": Network.Role.HUNTER}
	Network.players[9] = {"role": Network.Role.CHAMELEON}
	var payload: Array = [["MapProp_Relevance", Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3.RIGHT, Vector3.ZERO, false]]

	_expect(level._is_peer_relevant_to_map_prop_payload(8, payload), "Nearby hunters should receive moving map prop states")
	_expect(not level._is_peer_relevant_to_map_prop_payload(9, payload), "Far gameplay peers should skip continuous map prop motion states")
	Network.players[9] = {"role": Network.Role.SPECTATOR}
	_expect(not level._is_peer_relevant_to_map_prop_payload(9, payload), "Spectators should also skip far continuous map prop motion and wait for reliable rest state")

	level.free()
	Network.players.erase(8)
	Network.players.erase(9)


func _test_level_map_prop_motion_payload_slices_far_states() -> void:
	var level = preload("res://scripts/level.gd").new()
	var players := Node3D.new()
	players.name = "PlayersContainer"
	level.add_child(players)
	var near_player := Node3D.new()
	near_player.name = "8"
	near_player.position = Vector3(2.0, 0.0, 0.0)
	players.add_child(near_player)
	Network.players[8] = {"role": Network.Role.HUNTER}
	var payload: Array = [
		["MapProp_Near", Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3.RIGHT, Vector3.ZERO, false],
		["MapProp_Far", Transform3D(Basis.IDENTITY, Vector3(120.0, 0.0, 0.0)), Vector3.RIGHT, Vector3.ZERO, false],
	]

	var near_payload: Array = level._map_prop_motion_payload_for_peer(8, payload)
	_expect(near_payload.size() == 1, "Map prop motion sync should send only peer-relevant states")
	if near_payload.size() == 1:
		_expect(str((near_payload[0] as Array)[0]) == "MapProp_Near", "Map prop motion payload should keep the nearby prop state")
	Network.players[8] = {"role": Network.Role.SPECTATOR}
	var spectator_payload: Array = level._map_prop_motion_payload_for_peer(8, payload)
	_expect(spectator_payload.size() == 1, "Spectators should use observer relevance for continuous prop motion")
	if spectator_payload.size() == 1:
		_expect(str((spectator_payload[0] as Array)[0]) == "MapProp_Near", "Spectator prop motion payload should keep only nearby states")

	level.free()
	Network.players.erase(8)


func _test_level_map_prop_motion_sync_uses_targeted_rpc() -> void:
	var level_source: String = FileAccess.get_file_as_string("res://scripts/level.gd")
	_expect(level_source.contains("_map_prop_motion_payloads_by_peer(payload)"), "Map prop motion sync should build peer-specific payloads")
	_expect(level_source.contains("_rpc_sync_map_prop_motion_states.rpc_id(peer_id, peer_payload)"), "Map prop motion sync should use targeted rpc_id fan-out")
	_expect(not level_source.contains("_rpc_sync_map_prop_motion_states.rpc(payload)"), "Map prop motion sync should not broadcast every moving prop batch to all peers")


func _test_map_prop_impact_server_throttle() -> void:
	var level = preload("res://scripts/level.gd").new()
	_expect(level._should_accept_map_prop_impact("ThrottleProp", 7), "First map prop impact should pass the server throttle")
	_expect(not level._should_accept_map_prop_impact("ThrottleProp", 7), "Repeated same-player same-prop impact should be throttled on the server")
	_expect(level._should_accept_map_prop_impact("ThrottleProp", 8), "Different players should not block each other's prop impacts")
	_expect(level._should_accept_map_prop_impact("OtherThrottleProp", 7), "One prop's impact throttle should not block another prop")
	await get_tree().create_timer((float(level.MAP_PROP_IMPACT_SERVER_MIN_INTERVAL_MSEC) + 12.0) / 1000.0).timeout
	_expect(level._should_accept_map_prop_impact("ThrottleProp", 7), "Same-player same-prop impact should pass after the server throttle window")
	level.free()


func _test_map_prop_authoritative_rest_freezes_until_impact() -> void:
	var prop := FruitProp.new()
	prop.name = "RestFreezePropProbe"
	add_child(prop)
	await get_tree().process_frame

	prop.sleeping = true
	prop._configure_multiplayer_body_authority()
	_expect(prop.freeze, "Authoritative resting map props should freeze to reduce server physics cost")
	_expect(not prop.is_physics_processing(), "Authoritative resting map props should not run per-frame physics processing")
	_expect(prop.freeze_mode == RigidBody3D.FREEZE_MODE_STATIC, "Authoritative resting map props should use static freeze mode")
	_expect(not prop.contact_monitor, "Authoritative resting map props should disable contact reporting")
	_expect(prop.max_contacts_reported == 0, "Authoritative resting map props should not report idle contacts")
	prop.apply_player_impact(Vector3(4.0, 0.0, 0.0), prop.global_position, Vector3.LEFT, false)
	await get_tree().physics_frame
	_expect(not prop.freeze, "Authoritative map prop impact should unfreeze before applying movement")
	_expect(prop.is_physics_processing(), "Authoritative map prop impact should resume physics processing while moving")
	_expect(not prop.sleeping, "Authoritative map prop impact should wake sleeping bodies")
	_expect(prop.contact_monitor, "Authoritative moving map props should enable temporary contact reporting")
	_expect(prop.max_contacts_reported == FruitProp.CONTACT_REPORT_COUNT, "Authoritative moving map props should cap reported contacts")

	prop.queue_free()
	await get_tree().process_frame


func _test_map_prop_authoritative_impact_wakes_body() -> void:
	var prop := FruitProp.new()
	prop.name = "ImpactPropProbe"
	add_child(prop)
	await get_tree().process_frame

	prop.mass = 3.0
	prop.sleeping = true
	prop._configure_multiplayer_body_authority()
	_expect(not prop.is_physics_processing(), "Resting impact probe should start with physics processing disabled")
	prop.apply_player_impact(Vector3(4.0, 0.0, 0.0), prop.global_position, Vector3.LEFT, false)
	await get_tree().physics_frame
	_expect(not prop.freeze, "Authoritative player impact should unfreeze map props before replication")
	_expect(prop.is_physics_processing(), "Authoritative player impact should re-enable physics processing")
	_expect(not prop.sleeping, "Authoritative player impact should wake map props for replication")

	prop.queue_free()
	await get_tree().process_frame


func _test_map_prop_low_motion_rest_forces_sleep() -> void:
	var prop := FruitProp.new()
	prop.name = "LowMotionRestProbe"
	add_child(prop)
	await get_tree().process_frame

	prop.sleeping = false
	prop.freeze = false
	prop.linear_velocity = Vector3(0.02, 0.01, 0.02)
	prop.angular_velocity = Vector3(0.0, 0.04, 0.0)
	prop._has_recent_floor_contact = true
	prop._configure_multiplayer_body_authority()
	prop.set_physics_process(true)
	var forced_rest: bool = prop._try_force_low_motion_rest(FruitProp.FORCE_REST_DELAY + 0.02)
	_expect(forced_rest, "Low-motion grounded map props should force a reliable rest state")
	_expect(prop.sleeping, "Low-motion map props should sleep after the forced rest window")
	_expect(prop.freeze, "Low-motion map props should freeze after forced rest")
	_expect(not prop.is_physics_processing(), "Low-motion map props should stop physics processing after forced rest")
	_expect(not prop.contact_monitor, "Low-motion rested map props should disable contact reporting again")
	_expect(prop.max_contacts_reported == 0, "Low-motion rested map props should clear reported contacts")

	prop.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
