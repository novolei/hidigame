extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	var floor := _make_world_box("Floor", Vector3(18.0, 0.2, 18.0), Vector3(0.0, -0.1, 0.0))
	var roof := _make_world_box("ShadowRoof", Vector3(4.0, 0.25, 4.0), Vector3(0.0, 3.2, 0.0))
	add_child(floor)
	add_child(roof)

	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var player = player_scene.instantiate()
	player.name = "10"
	player.position = Vector3.ZERO
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame

	var system = player.get_node_or_null("ShadowVisibilitySystem")
	_expect(system != null, "Stalker player should attach ShadowVisibilitySystem")
	if system:
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_shadow_rays_blocked() == 5, "Roof should block all five upward shadow rays")
		_expect(is_zero_approx(system.get_visibility_alpha()), "Full shadow should make the Stalker fully invisible to raw visibility")

		Network.players[1]["role"] = Network.Role.CHAMELEON
		player._refresh_stalker_visibility_view(true)
		_expect(player.get_stalker_visual_mode() == "ghost", "Chameleon viewers should see the hidden Stalker as a ghost model")

		Network.players[1]["role"] = Network.Role.HUNTER
		player._refresh_stalker_visibility_view(true)
		_expect(player.get_stalker_visual_mode() == "glass", "Hunter viewers should see hidden Stalkers as glass distortion")
		_expect(not player.nickname.visible, "Hunter view should hide the hidden Stalker's nameplate")

		var reveal_light := OmniLight3D.new()
		reveal_light.name = "RevealLight"
		reveal_light.omni_range = 6.0
		reveal_light.light_energy = 2.0
		reveal_light.position = Vector3(0.0, 1.5, 1.25)
		add_child(reveal_light)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "Clear local light should reveal a Stalker even under a roof")
		player._refresh_stalker_visibility_view(true)
		_expect(player.get_stalker_visual_mode() == "normal", "Revealed Stalker should restore normal materials")
		_expect(player.nickname.visible, "Revealed Stalker should show the nameplate again")
		reveal_light.queue_free()
		await get_tree().process_frame

		var directional_light := DirectionalLight3D.new()
		directional_light.name = "SideDirectionalReveal"
		directional_light.light_energy = 1.0
		add_child(directional_light)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "DirectionalLight line of sight should reveal a Stalker under side lighting")
		directional_light.queue_free()
		await get_tree().process_frame

		var emissive_mesh := MeshInstance3D.new()
		emissive_mesh.name = "EmissiveRevealPanel"
		var emissive_box := BoxMesh.new()
		emissive_box.size = Vector3(0.4, 0.8, 0.4)
		emissive_mesh.mesh = emissive_box
		var emissive_mat := StandardMaterial3D.new()
		emissive_mat.emission_enabled = true
		emissive_mat.emission = Color(0.6, 0.9, 1.0, 1.0)
		emissive_mat.emission_energy_multiplier = 1.0
		emissive_mesh.material_override = emissive_mat
		emissive_mesh.position = Vector3(0.0, 1.2, 1.4)
		add_child(emissive_mesh)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "Nearby emissive meshes should reveal a covered Stalker")
		emissive_mesh.queue_free()
		await get_tree().process_frame

		var reveal_zone := Node3D.new()
		reveal_zone.name = "FogRevealZone"
		reveal_zone.position = Vector3(0.0, 1.0, 1.0)
		reveal_zone.add_to_group("stalker_reveal_environment")
		add_child(reveal_zone)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "Reveal environment zones should support FogGI or airdrop light volumes")
		reveal_zone.queue_free()
		await get_tree().process_frame

		var spot_light := SpotLight3D.new()
		spot_light.name = "SpotRevealLight"
		spot_light.spot_range = 7.0
		spot_light.spot_angle = 48.0
		spot_light.light_energy = 2.0
		spot_light.position = Vector3(0.0, 1.5, 2.8)
		add_child(spot_light)
		spot_light.look_at(player.global_position + Vector3.UP, Vector3.UP)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "SpotLight flashlight cone should reveal a Stalker under cover")
		spot_light.queue_free()
		await get_tree().process_frame

		system.force_shadow_check()
		await get_tree().process_frame
		_expect(is_zero_approx(system.get_visibility_alpha()), "Removing reveal lights should return the covered Stalker to full invisibility")
		system.force_reveal(0.5)
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "force_reveal should support lightning and airdrop reveal effects")

		player.global_position = Vector3(6.0, 0.0, 0.0)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_shadow_rays_blocked() <= 2, "Moving out from under the roof should become bright")
		_expect(system.get_visibility_alpha() >= 0.99, "Bright light should make the Stalker fully visible")

	player.queue_free()
	floor.queue_free()
	roof.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[StalkerShadowVisibilityTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[StalkerShadowVisibilityTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19094, 4)
	_expect(error == OK, "Test multiplayer peer should start")
	if error == OK:
		Network.multiplayer.multiplayer_peer = peer
	Network.players.clear()
	Network.players = {
		1: _player("Viewer", Network.Role.HUNTER),
		10: _player("Stalker", Network.Role.STALKER),
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


func _make_world_box(node_name: String, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 2
	body.collision_mask = 3
	body.position = position
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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
