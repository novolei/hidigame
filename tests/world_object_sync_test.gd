extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_ammo_availability_state_controls_visibility_and_collision()
	await _test_map_prop_network_state_application()
	await _test_level_applies_map_prop_state_by_name()
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
