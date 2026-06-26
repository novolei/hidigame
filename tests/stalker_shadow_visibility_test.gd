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
		_expect(player.get_stalker_visual_mode() == "ghost", "Chameleon viewers should see the hidden Stalker as a ghost model in classic mode")
		_expect(_meshes_do_not_cast_shadows(player._get_stalker_visual_meshes()), "Classic hidden Stalker should not cast visible shadows")
		_expect(bool(_stalker_outer_shell_summary(player).get("ok", false)), "Classic Prop-side hidden Stalker should render as a single-sided feature-free shell: " + str(_stalker_outer_shell_summary(player)))

		player.set_multiplayer_authority(1)
		player._refresh_stalker_visibility_view(true)
		_expect(player.get_stalker_visual_mode() == "ghost", "The hidden Stalker should see a classic self shimmer when liquid glass is disabled")
		var self_classic_summary: Dictionary = _ghost_material_summary(player)
		_expect(bool(self_classic_summary.get("classic_self_ok", false)), "Self classic shimmer should be dim, low-blue, and airy: " + str(self_classic_summary))
		_expect(_meshes_do_not_cast_shadows(player._get_stalker_visual_meshes()), "Self classic hidden Stalker should not cast visible shadows")
		_expect(bool(_stalker_outer_shell_summary(player).get("ok", false)), "Self classic hidden Stalker should render as a single-sided feature-free shell: " + str(_stalker_outer_shell_summary(player)))
		player._restore_stalker_materials()
		_expect(bool(_stalker_features_restored_summary(player).get("ok", false)), "Restoring Stalker materials should restore face/eye/mouth feature meshes: " + str(_stalker_features_restored_summary(player)))
		player._refresh_stalker_visibility_view(true)
		player.set_multiplayer_authority(10)

		Network.lobby_config["stalker_glass_material"] = "liquid_glass"
		player._refresh_stalker_visibility_view(true)
		_expect(player.get_stalker_visual_mode() == "glass", "Chameleon viewers should see hidden Stalkers with stronger liquid glass when enabled")
		var prop_liquid_summary: Dictionary = _glass_material_summary(player)
		_expect(bool(prop_liquid_summary.get("liquid_prop_ok", false)), "Prop-side liquid glass should be stronger than hunter cloak: " + str(prop_liquid_summary))
		_expect(_meshes_do_not_cast_shadows(player._get_stalker_visual_meshes()), "Prop-side liquid hidden Stalker should not cast visible shadows")
		_expect(bool(_stalker_outer_shell_summary(player).get("ok", false)), "Prop-side liquid hidden Stalker should render as a single-sided feature-free shell: " + str(_stalker_outer_shell_summary(player)))

		player.set_multiplayer_authority(1)
		player._refresh_stalker_visibility_view(true)
		_expect(player.get_stalker_visual_mode() == "glass", "The hidden Stalker should see their own liquid glass body when enabled")
		var self_liquid_summary: Dictionary = _glass_material_summary(player)
		_expect(bool(self_liquid_summary.get("liquid_self_ok", false)), "Self liquid glass should be visible but subtler than prop-side cloak: " + str(self_liquid_summary))
		_expect(float(prop_liquid_summary.get("refracted_mix", 0.0)) > float(self_liquid_summary.get("refracted_mix", 0.0)), "Prop-side liquid glass should use fully direct refraction while self view keeps a tiny tint contribution")
		_expect(_meshes_do_not_cast_shadows(player._get_stalker_visual_meshes()), "Self liquid hidden Stalker should not cast visible shadows")
		_expect(bool(_stalker_outer_shell_summary(player).get("ok", false)), "Self liquid hidden Stalker should render as a single-sided feature-free shell: " + str(_stalker_outer_shell_summary(player)))
		player.set_multiplayer_authority(10)

		Network.players[1]["role"] = Network.Role.HUNTER
		Network.lobby_config["stalker_glass_material"] = "classic"
		player._refresh_stalker_visibility_view(true)
		_expect(player.get_stalker_visual_mode() == "glass", "Hunter viewers should see hidden Stalkers as glass distortion")
		_expect(not player.nickname.visible, "Hunter view should hide the hidden Stalker's nameplate")
		var glass_summary: Dictionary = _glass_material_summary(player)
		_expect(bool(glass_summary.get("classic_ok", false)), "Hunter classic glass view should stay available for A/B comparison: " + str(glass_summary))
		_expect(_meshes_do_not_cast_shadows(player._get_stalker_visual_meshes()), "Hunter classic shimmer hidden Stalker should not cast visible shadows")
		_expect(bool(_stalker_outer_shell_summary(player).get("ok", false)), "Hunter classic hidden Stalker should render as a single-sided feature-free shell: " + str(_stalker_outer_shell_summary(player)))
		Network.lobby_config["stalker_glass_material"] = "liquid_glass"
		player._refresh_stalker_visibility_view(true)
		var liquid_summary: Dictionary = _glass_material_summary(player)
		_expect(bool(liquid_summary.get("liquid_hunter_ok", false)), "Hunter liquid glass view should use subtle screen refraction, Fresnel tint, and lobby strength: " + str(liquid_summary))
		_expect(_meshes_do_not_cast_shadows(player._get_stalker_visual_meshes()), "Hunter liquid hidden Stalker should not cast visible shadows")
		_expect(bool(_stalker_outer_shell_summary(player).get("ok", false)), "Hunter liquid hidden Stalker should render as a single-sided feature-free shell: " + str(_stalker_outer_shell_summary(player)))
		Network.lobby_config["stalker_glass_material"] = "classic"

		Network.players[1]["role"] = Network.Role.CHAMELEON
		for model in CharacterSkinCatalog.all():
			var model_id := str(model.get("id", CharacterSkinCatalog.DEFAULT_ID))
			player.set_character_model(model_id)
			await get_tree().process_frame
			player._refresh_stalker_visibility_view(true)
			var skin_meshes: Array[MeshInstance3D] = player._get_stalker_visual_meshes()
			_expect(not skin_meshes.is_empty(), "Stalker skin should expose visible meshes for shadow visuals: " + model_id)
			_expect(_meshes_have_shader_override(skin_meshes), "Stalker invisibility should apply to all visible meshes for skin: " + model_id)
			_expect(_meshes_do_not_cast_shadows(skin_meshes), "Hidden Stalker skin should not cast visible shadows: " + model_id)
		player.set_character_model(CharacterSkinCatalog.DEFAULT_ID)
		await get_tree().process_frame
		Network.players[1]["role"] = Network.Role.HUNTER
		player._refresh_stalker_visibility_view(true)

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
		_expect(_meshes_do_not_cast_shadows(player._get_stalker_visual_meshes()), "Remote revealed Stalker should keep the lightweight remote shadow policy")
		_expect(not player.nickname.visible, "Hunter clients should not see remote Prop/Stalker nameplates even after reveal")
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

		player.global_position = Vector3(6.0, 0.0, 0.0)
		var legacy_roof := _make_world_box("LegacyLayerRoof", Vector3(4.0, 0.25, 4.0), Vector3(6.0, 3.2, 0.0), 1)
		add_child(legacy_roof)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_shadow_rays_blocked() == 5, "Legacy/default layer geometry should count as Stalker shadow cover")
		_expect(is_zero_approx(system.get_visibility_alpha()), "Legacy/default layer shadow cover should hide the Stalker")
		legacy_roof.queue_free()
		await get_tree().process_frame

		var directional_shadow_light := DirectionalLight3D.new()
		directional_shadow_light.name = "DirectionalShadowLight"
		directional_shadow_light.light_energy = 1.0
		add_child(directional_shadow_light)
		var directional_blocker := _make_world_box("DirectionalShadowBlocker", Vector3(3.0, 3.0, 0.25), Vector3(6.0, 1.0, 2.5), 1)
		add_child(directional_blocker)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_shadow_rays_blocked() == 5, "Directional light blockers should create shadow invisibility even without an overhead roof")
		_expect(is_zero_approx(system.get_visibility_alpha()), "Directional cast shadow should hide the Stalker")
		directional_shadow_light.queue_free()
		directional_blocker.queue_free()
		player.global_position = Vector3.ZERO
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

		var hunter_visual := Node3D.new()
		hunter_visual.name = "HunterVisualRevealDecoy"
		hunter_visual.add_to_group("players")
		hunter_visual.position = Vector3(0.0, 1.2, 1.3)
		add_child(hunter_visual)
		var carried_light := OmniLight3D.new()
		carried_light.name = "PlayerCarriedLight"
		carried_light.omni_range = 6.0
		carried_light.light_energy = 2.0
		hunter_visual.add_child(carried_light)
		var player_emissive_mesh := MeshInstance3D.new()
		player_emissive_mesh.name = "PlayerEmissiveSkin"
		var player_emissive_box := BoxMesh.new()
		player_emissive_box.size = Vector3(0.4, 0.8, 0.4)
		player_emissive_mesh.mesh = player_emissive_box
		player_emissive_mesh.material_override = emissive_mat
		hunter_visual.add_child(player_emissive_mesh)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(is_zero_approx(system.get_visibility_alpha()), "Player-carried lights and emissive skin materials should not reveal a covered Stalker by proximity")
		hunter_visual.queue_free()
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

		var hunter_flashlight := preload("res://scripts/hunter_flashlight_system.gd").new()
		hunter_flashlight.name = "HunterFlashlightProbe"
		add_child(hunter_flashlight)
		await get_tree().process_frame
		var flashlight_origin: Vector3 = player.global_position + Vector3(0.0, 1.45, 4.5)
		var flashlight_direction: Vector3 = ((player.global_position + Vector3.UP) - flashlight_origin).normalized()
		hunter_flashlight._set_flashlight_active(true, 15.0)
		hunter_flashlight._apply_flashlight_pose(flashlight_origin, flashlight_direction)
		system.hunter_flashlight_exposure = 0.0
		for i in range(17):
			system._update_hunter_flashlight_exposure(0.2)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(is_zero_approx(system.get_visibility_alpha()), "Hunter flashlight should not reveal Stalkers before 3.5 seconds of sustained exposure")
		system._update_hunter_flashlight_exposure(0.2)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "Hunter flashlight should reveal Stalkers after 3.5 seconds of sustained exposure")
		hunter_flashlight._set_flashlight_active(false, 0.0)
		system._update_hunter_flashlight_exposure(0.2)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "Hunter flashlight reveal should disable shadow invisibility after the beam turns off")
		_expect(system.get_flashlight_reveal_lockout_remaining() > 19.0, "Hunter flashlight reveal should start a 20 second shadow-invisibility lockout")
		system._process(20.1)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(is_zero_approx(system.get_visibility_alpha()), "Stalker should be able to hide again after the flashlight lockout expires")
		hunter_flashlight.queue_free()
		await get_tree().process_frame

		var battery_flashlight := preload("res://scripts/hunter_flashlight_system.gd").new()
		battery_flashlight.name = "HunterFlashlightBatteryProbe"
		add_child(battery_flashlight)
		await get_tree().process_frame
		battery_flashlight.request_toggle()
		await get_tree().process_frame
		_expect(battery_flashlight.is_flashlight_active(), "Hunter flashlight should turn on with F/toggle input")
		_expect(battery_flashlight.get_pose_sync_interval_for_test() >= 0.10 and battery_flashlight.get_pose_sync_interval_for_test() <= 0.13, "Hunter flashlight pose sync should stay budgeted near 8Hz instead of sending every frame")
		battery_flashlight._process(4.0)
		var battery_after_first_burst: float = battery_flashlight.get_battery_remaining()
		_expect(battery_after_first_burst <= 11.1 and battery_after_first_burst >= 10.9, "Hunter flashlight battery should drain while active")
		battery_flashlight.request_toggle()
		await get_tree().process_frame
		_expect(not battery_flashlight.is_flashlight_active(), "Hunter flashlight should turn off with a second F/toggle input")
		battery_flashlight._process(3.0)
		var battery_after_recovery: float = battery_flashlight.get_battery_remaining()
		_expect(battery_after_recovery > battery_after_first_burst + 1.4 and battery_after_recovery < battery_after_first_burst + 1.6, "Hunter flashlight battery should slowly recharge while manually turned off")
		battery_flashlight.request_toggle()
		await get_tree().process_frame
		_expect(battery_flashlight.is_flashlight_active(), "Hunter flashlight should turn on again when it still has battery")
		battery_flashlight._process(battery_after_recovery + 0.2)
		_expect(not battery_flashlight.is_flashlight_active(), "Hunter flashlight should turn off automatically when total battery use reaches 15 seconds")
		_expect(is_zero_approx(battery_flashlight.get_battery_remaining()), "Hunter flashlight battery should be empty after 15 seconds of total use")
		_expect(battery_flashlight.get_cooldown_remaining() > 44.0, "Hunter flashlight should enter a 45 second cooldown after battery depletion")
		battery_flashlight.request_toggle()
		await get_tree().process_frame
		_expect(not battery_flashlight.is_flashlight_active(), "Hunter flashlight should not turn on during cooldown")
		battery_flashlight._process(45.1)
		_expect(is_equal_approx(battery_flashlight.get_battery_remaining(), 15.0), "Hunter flashlight battery should refill after cooldown")
		_expect(is_zero_approx(battery_flashlight.get_cooldown_remaining()), "Hunter flashlight cooldown should finish after 45 seconds")
		battery_flashlight.request_toggle()
		await get_tree().process_frame
		_expect(battery_flashlight.is_flashlight_active(), "Hunter flashlight should turn on after cooldown refills the battery")
		battery_flashlight.queue_free()
		await get_tree().process_frame

		system.force_reveal(0.5)
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "force_reveal should support lightning and airdrop reveal effects")

		player.global_position = Vector3(6.0, 0.0, 0.0)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_shadow_rays_blocked() <= 2, "Moving out from under the roof should become bright")
		_expect(system.get_visibility_alpha() >= 0.99, "Bright light should make the Stalker fully visible")

		await get_tree().create_timer(0.6).timeout
		var ignored_dynamic_shadow := _make_world_box("IgnoredDynamicShadowNoise", Vector3(3.0, 0.3, 3.0), Vector3(6.0, 3.2, 0.0), 2)
		ignored_dynamic_shadow.add_to_group("dynamic_shadow_noise")
		add_child(ignored_dynamic_shadow)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_shadow_rays_blocked() <= 2, "Dynamic random props and decor should not count as valid Stalker shadow cover")
		_expect(system.get_visibility_alpha() >= 0.99, "Ignored dynamic prop shadows should not hide the Stalker")
		ignored_dynamic_shadow.queue_free()
		await get_tree().process_frame

		var explicit_shadow_zone := _make_shadow_zone("StableGameplayShadowZone", Vector3(4.5, 2.2, 4.5), Vector3(6.0, 1.05, 0.0))
		add_child(explicit_shadow_zone)
		var direct_sun := DirectionalLight3D.new()
		direct_sun.name = "DirectSunOverExplicitZone"
		direct_sun.light_energy = 1.0
		add_child(direct_sun)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_shadow_rays_blocked() == 5, "Explicit fixed shadow zones should mark the whole gameplay shadow patch")
		_expect(is_zero_approx(system.get_visibility_alpha()), "Explicit fixed shadow zones should hide the Stalker even when ray sampling misses the visual ground shadow")
		direct_sun.queue_free()

		var zone_reveal_light := OmniLight3D.new()
		zone_reveal_light.name = "ExplicitZoneRevealLight"
		zone_reveal_light.omni_range = 5.0
		zone_reveal_light.light_energy = 2.0
		zone_reveal_light.position = player.global_position + Vector3(0.0, 1.6, 1.0)
		add_child(zone_reveal_light)
		system.force_shadow_check()
		await get_tree().process_frame
		_expect(system.get_visibility_alpha() >= 0.99, "Local lights should still reveal a Stalker inside explicit fixed shadow zones")
		zone_reveal_light.queue_free()
		explicit_shadow_zone.queue_free()
		await get_tree().process_frame

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
	Network.lobby_config["stalker_glass_alpha_max"] = 0.125
	Network.lobby_config["stalker_glass_material"] = "classic"
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


func _make_world_box(node_name: String, size: Vector3, position: Vector3, collision_layer: int = 2) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = collision_layer
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


func _make_shadow_zone(node_name: String, size: Vector3, position: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = position
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.add_to_group("stalker_shadow_zone")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	return area


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _meshes_have_shader_override(meshes: Array[MeshInstance3D]) -> bool:
	for mesh in meshes:
		if not mesh.material_override is ShaderMaterial:
			return false
	return true


func _meshes_do_not_cast_shadows(meshes: Array[MeshInstance3D]) -> bool:
	if meshes.is_empty():
		return false
	for mesh in meshes:
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return true


func _meshes_cast_shadows(meshes: Array[MeshInstance3D]) -> bool:
	if meshes.is_empty():
		return false
	for mesh in meshes:
		if mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			return false
	return true


func _stalker_outer_shell_summary(player: Node) -> Dictionary:
	var meshes: Array[MeshInstance3D] = player._get_stalker_visual_meshes(true)
	var feature_count: int = 0
	var hidden_feature_count: int = 0
	var visible_shell_count: int = 0
	var cull_back_count: int = 0
	var visible_features: Array[String] = []
	for mesh in meshes:
		if player._is_stalker_invisibility_feature_mesh(mesh):
			feature_count += 1
			if mesh.visible:
				visible_features.append(String(mesh.name))
			else:
				hidden_feature_count += 1
			continue
		if not mesh.visible:
			continue
		visible_shell_count += 1
		var material: ShaderMaterial = mesh.material_override as ShaderMaterial
		if material and material.shader and material.shader.code.find("cull_back") != -1 and material.shader.code.find("cull_disabled") == -1:
			cull_back_count += 1
	return {
		"ok": feature_count > 0 and hidden_feature_count == feature_count and visible_shell_count > 0 and cull_back_count == visible_shell_count,
		"feature_count": feature_count,
		"hidden_feature_count": hidden_feature_count,
		"visible_shell_count": visible_shell_count,
		"cull_back_count": cull_back_count,
		"visible_features": visible_features,
	}


func _stalker_features_restored_summary(player: Node) -> Dictionary:
	var meshes: Array[MeshInstance3D] = player._get_stalker_visual_meshes(true)
	var feature_count: int = 0
	var visible_feature_count: int = 0
	var hidden_features: Array[String] = []
	for mesh in meshes:
		if not player._is_stalker_invisibility_feature_mesh(mesh):
			continue
		feature_count += 1
		if mesh.visible:
			visible_feature_count += 1
		else:
			hidden_features.append(String(mesh.name))
	return {
		"ok": feature_count > 0 and visible_feature_count == feature_count,
		"feature_count": feature_count,
		"visible_feature_count": visible_feature_count,
		"hidden_features": hidden_features,
	}


func _ghost_material_summary(player: Node) -> Dictionary:
	var meshes: Array[MeshInstance3D] = player._get_stalker_visual_meshes()
	if meshes.is_empty():
		return {"classic_self_ok": false, "reason": "no meshes"}
	var material: ShaderMaterial = meshes[0].material_override as ShaderMaterial
	if not material:
		return {"classic_self_ok": false, "reason": "missing shader material", "mesh": meshes[0].name}
	var alpha: float = _shader_float(material, "alpha", 1.0)
	var alpha_ceiling: float = _shader_float(material, "alpha_ceiling", 1.0)
	var fresnel_alpha_boost: float = _shader_float(material, "fresnel_alpha_boost", 1.0)
	var veil_strength: float = _shader_float(material, "veil_strength", 0.0)
	var veil_alpha: float = _shader_float(material, "veil_alpha", 0.0)
	var emission_strength: float = _shader_float(material, "emission_strength", 1.0)
	var tint_value: Variant = material.get_shader_parameter("tint")
	var classic_self_ok: bool = false
	if tint_value is Color:
		var tint: Color = tint_value as Color
		classic_self_ok = material.resource_name == "StalkerClassicShimmerSelf" and alpha >= 0.09 and alpha <= 0.10 and alpha_ceiling >= 0.33 and alpha_ceiling <= 0.35 and fresnel_alpha_boost >= 0.054 and fresnel_alpha_boost <= 0.056 and veil_strength >= 0.17 and veil_strength <= 0.19 and veil_alpha >= 0.017 and veil_alpha <= 0.019 and emission_strength >= 0.024 and emission_strength <= 0.026 and tint.r >= 0.41 and tint.r <= 0.43 and tint.g >= 0.49 and tint.g <= 0.51 and tint.b >= 0.45 and tint.b <= 0.47
	return {
		"classic_self_ok": classic_self_ok,
		"material": material.resource_name,
		"alpha": alpha,
		"alpha_ceiling": alpha_ceiling,
		"fresnel_alpha_boost": fresnel_alpha_boost,
		"veil_strength": veil_strength,
		"veil_alpha": veil_alpha,
		"emission_strength": emission_strength,
		"has_tint": tint_value is Color,
	}


func _glass_material_summary(player: Node) -> Dictionary:
	var meshes: Array[MeshInstance3D] = player._get_stalker_visual_meshes()
	if meshes.is_empty():
		return {"classic_ok": false, "liquid_hunter_ok": false, "liquid_self_ok": false, "liquid_prop_ok": false, "reason": "no meshes"}
	var material: ShaderMaterial = meshes[0].material_override as ShaderMaterial
	if not material:
		return {"classic_ok": false, "liquid_hunter_ok": false, "liquid_self_ok": false, "liquid_prop_ok": false, "reason": "missing shader material", "mesh": meshes[0].name}
	var alpha: float = _shader_float(material, "alpha", 1.0)
	var ceiling: float = _shader_float(material, "visibility_ceiling", 1.0)
	var refraction: float = _shader_float(material, "refraction_strength", 1.0)
	var shimmer: float = _shader_float(material, "shimmer_strength", 1.0)
	var fresnel: float = _shader_float(material, "fresnel_power", 99.0)
	var emission: float = _shader_float(material, "emission_power", 99.0)
	var screen_color_bleed: float = _shader_float(material, "screen_color_bleed", 1.0)
	var glass_highlight: float = _shader_float(material, "glass_highlight", 0.0)
	var luminance_refraction: float = _shader_float(material, "luminance_refraction", 0.0)
	var rim_alpha_boost: float = _shader_float(material, "rim_alpha_boost", 0.0)
	var refracted_mix: float = _shader_float(material, "refracted_mix", 0.0)
	var refracted_alpha_boost: float = _shader_float(material, "refracted_alpha_boost", 0.0)
	var highlight_strength: float = _shader_float(material, "highlight_strength", 0.0)
	var rim_power: float = _shader_float(material, "rim_power", 0.0)
	var edge_tint_value: Variant = material.get_shader_parameter("edge_tint")
	var tint_value: Variant = material.get_shader_parameter("tint")
	var classic_ok: bool = false
	var liquid_hunter_ok: bool = false
	var liquid_self_ok: bool = false
	var liquid_prop_ok: bool = false
	if edge_tint_value is Color:
		var edge_tint: Color = edge_tint_value as Color
		classic_ok = material.resource_name == "StalkerClassicShimmer" and alpha <= 0.03 and ceiling <= 0.125 and refraction <= 0.016 and shimmer <= 0.007 and screen_color_bleed <= 0.023 and highlight_strength >= 0.12 and highlight_strength <= 0.14 and edge_tint.b <= 0.70
	if tint_value is Color:
		var tint: Color = tint_value as Color
		liquid_hunter_ok = material.resource_name == "StalkerLiquidGlassHunter" and alpha <= 0.03 and ceiling <= 0.125 and refraction >= 0.05 and refraction <= 0.055 and fresnel <= 1.2 and emission >= 0.19 and emission <= 0.21 and screen_color_bleed <= 0.036 and glass_highlight >= 0.23 and glass_highlight <= 0.25 and luminance_refraction >= 1.04 and luminance_refraction <= 1.06 and rim_alpha_boost >= 0.034 and rim_alpha_boost <= 0.036 and refracted_mix >= 0.035 and refracted_mix <= 0.05 and rim_power >= 0.15 and tint.b >= 0.95
		liquid_self_ok = material.resource_name == "StalkerLiquidGlassSelf" and alpha >= 0.035 and alpha <= 0.10 and ceiling >= 0.14 and ceiling <= 0.15 and refraction >= 0.089 and refraction <= 0.091 and emission >= 0.119 and emission <= 0.121 and screen_color_bleed >= 0.057 and screen_color_bleed <= 0.059 and glass_highlight >= 0.199 and glass_highlight <= 0.201 and luminance_refraction >= 1.21 and luminance_refraction <= 1.23 and rim_alpha_boost >= 0.043 and rim_alpha_boost <= 0.045 and refracted_mix >= 0.94 and refracted_mix <= 0.96 and refracted_alpha_boost >= 0.017 and refracted_alpha_boost <= 0.019 and rim_power >= 0.15 and rim_power <= 0.17 and tint.r >= 0.41 and tint.r <= 0.43 and tint.g >= 0.51 and tint.g <= 0.53
		liquid_prop_ok = material.resource_name == "StalkerLiquidGlassProp" and alpha >= 0.08 and alpha <= 0.20 and ceiling >= 0.20 and ceiling <= 0.22 and refraction >= 0.066 and refraction <= 0.068 and emission >= 0.35 and emission <= 0.37 and screen_color_bleed <= 0.053 and glass_highlight >= 0.45 and glass_highlight <= 0.47 and luminance_refraction >= 1.44 and luminance_refraction <= 1.46 and rim_alpha_boost >= 0.064 and rim_alpha_boost <= 0.066 and refracted_mix >= 0.99 and refracted_mix <= 1.0 and rim_power >= 0.29 and tint.g >= 0.89
	return {
		"classic_ok": classic_ok,
		"liquid_hunter_ok": liquid_hunter_ok,
		"liquid_self_ok": liquid_self_ok,
		"liquid_prop_ok": liquid_prop_ok,
		"material": material.resource_name,
		"alpha": alpha,
		"ceiling": ceiling,
		"refraction": refraction,
		"shimmer": shimmer,
		"fresnel": fresnel,
		"emission": emission,
		"screen_color_bleed": screen_color_bleed,
		"glass_highlight": glass_highlight,
		"luminance_refraction": luminance_refraction,
		"rim_alpha_boost": rim_alpha_boost,
		"refracted_mix": refracted_mix,
		"refracted_alpha_boost": refracted_alpha_boost,
		"highlight_strength": highlight_strength,
		"rim_power": rim_power,
		"has_edge_tint": edge_tint_value is Color,
		"has_tint": tint_value is Color,
	}


func _shader_float(material: ShaderMaterial, parameter_name: String, fallback: float) -> float:
	var value = material.get_shader_parameter(parameter_name)
	if value == null:
		return fallback
	return float(value)
