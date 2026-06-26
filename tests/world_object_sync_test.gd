extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_ammo_availability_state_controls_visibility_and_collision()
	await _test_ammo_pickup_uses_meshy_visuals_and_sized_collision()
	_test_map_prop_sync_budget_coalesces_motion()
	await _test_map_prop_network_state_application()
	_test_level_applies_map_prop_state_by_name()
	await _test_map_prop_authoritative_impact_wakes_body()
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


func _test_ammo_pickup_uses_meshy_visuals_and_sized_collision() -> void:
	var level: Node = preload("res://scripts/level.gd").new()
	var container: Node3D = Node3D.new()
	container.name = "AmmoPackContainer"
	level.add_child(container)
	var ammo_script: Script = preload("res://scripts/ammo_pickup.gd")
	var probe_types: Array[int] = [AmmoPickup.AmmoType.SMALL, AmmoPickup.AmmoType.MEDIUM, AmmoPickup.AmmoType.LARGE]

	for ammo_type_value: int in probe_types:
		var ammo_name: String = "AmmoMeshyProbe_%d" % ammo_type_value
		var data: Dictionary = {"name": ammo_name, "position": Vector3.ZERO, "type": ammo_type_value}
		level.call("_spawn_one_ammo", container, ammo_script, data)
		var ammo: Area3D = container.get_node_or_null(ammo_name) as Area3D
		_expect(ammo != null, "Level ammo spawn should create an Area3D for type %d" % ammo_type_value)
		if ammo == null:
			continue
		var visual: Node3D = ammo.get_node_or_null("AmmoBoxVisual") as Node3D
		_expect(visual != null, "Ammo pickup should use the Meshy ammo box visual for type %d" % ammo_type_value)
		if visual != null:
			var expected_scale: Vector3 = AmmoPickup.visual_scale_for_type(ammo_type_value)
			_expect(visual.scale.distance_to(expected_scale) < 0.001, "Ammo Meshy visual scale should match type sizing")
			_expect(expected_scale.distance_to(Vector3(0.42, 0.42, 0.42)) < 0.001, "Ammo Meshy visual should stay close to the 0.8m pickup size")
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

	var early_flush: Array[Dictionary] = budget.tick(0.05)
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


func _test_map_prop_authoritative_impact_wakes_body() -> void:
	var prop := FruitProp.new()
	prop.name = "ImpactPropProbe"
	add_child(prop)
	await get_tree().process_frame

	prop.mass = 3.0
	prop.sleeping = true
	prop.apply_player_impact(Vector3(4.0, 0.0, 0.0), prop.global_position, Vector3.LEFT, false)
	await get_tree().physics_frame
	_expect(not prop.sleeping, "Authoritative player impact should wake map props for replication")

	prop.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
