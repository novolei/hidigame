extends Node3D

const PlayerScene := preload("res://scenes/level/player.tscn")
const GreenBloodImpactScript := preload("res://scripts/green_blood_impact.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_reset_network_state()
	await _test_prop_death_spawns_dissolve_and_spectator_state()
	await _test_green_blood_impact_builds_grass_green_spray()
	_shutdown_network_state()

	if failures.is_empty():
		print("[DeathDissolveSpectatorTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[DeathDissolveSpectatorTest] " + failure)
		get_tree().quit(1)


func _reset_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(19124, 4)
	_expect(error == OK, "Test multiplayer peer should start")
	if error == OK:
		Network.multiplayer.multiplayer_peer = peer
	Network.players.clear()
	Network.players = {
		1: _player("KilledProp", Network.Role.CHAMELEON),
		2: _player("Hunter", Network.Role.HUNTER),
	}


func _shutdown_network_state() -> void:
	if Network.multiplayer.multiplayer_peer:
		Network.multiplayer.multiplayer_peer.close()
		Network.multiplayer.multiplayer_peer = null
	Network.players.clear()


func _player(nick: String, role: int) -> Dictionary:
	return {
		"nick": nick,
		"skin": Network.SKIN_GREEN,
		"role": role,
		"role_locked": false,
		"join_lobby_id": "",
		"character_model": CharacterSkinCatalog.DEFAULT_ID,
		"party_monster_accessories": {},
		"alive": true,
	}


func _test_prop_death_spawns_dissolve_and_spectator_state() -> void:
	var player := PlayerScene.instantiate() as Character
	_expect(player != null, "Player scene should instantiate as Character")
	if player == null:
		return
	player.name = "1"
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.role = Network.Role.CHAMELEON

	var preset: Dictionary = ShapeShiftSystem.PRESET_LIBRARY[0]
	player.apply_prop_disguise(preset)
	await get_tree().process_frame
	_expect(player.is_disguised(), "Player should enter prop disguise before death")

	player.call("_broadcast_death", 2)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(player.is_dead(), "Player should be marked dead after death broadcast")
	_expect(bool(player.get("_dead_free_camera_active")), "Local dead player should enter free spectator camera state")
	_expect(not player.is_disguised(), "Death should clear gameplay prop disguise state")
	var collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_expect(collision != null and collision.disabled, "Dead player collision should be disabled for free spectator movement")
	var dissolve_visual := _find_first_child_named(self, "DeathDissolveVisual") as Node3D
	_expect(dissolve_visual != null, "Prop death should spawn an independent DeathDissolveVisual")
	if dissolve_visual:
		_expect(_has_death_dissolve_shader(dissolve_visual), "Death dissolve visual should use the death_dissolve shader on meshes")
		_expect(dissolve_visual.get_parent() != player, "Death dissolve visual should not remain parented to the player body")

	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	_expect(player_source.contains("_play_skin_reaction(\"die\")"), "Death broadcast should keep the existing die animation hook")
	_expect(player_source.contains("_begin_dead_observer_state()"), "Death broadcast should enter dead observer state")

	if player.has_method("_clear_death_dissolve_visual"):
		player.call("_clear_death_dissolve_visual")
	player.queue_free()
	if dissolve_visual and is_instance_valid(dissolve_visual):
		dissolve_visual.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_green_blood_impact_builds_grass_green_spray() -> void:
	var effect := GreenBloodImpactScript.spawn(self, Vector3(0.0, 1.0, 0.0), Vector3.UP, Vector3.FORWARD)
	_expect(effect != null, "Green blood impact should spawn")
	if effect == null:
		return
	await get_tree().process_frame
	var spray := effect.get_node_or_null("Spray") as GPUParticles3D
	_expect(spray != null, "Green blood impact should include a spray particle node")
	_expect(effect.get_node_or_null("ImpactSplat") != null, "Green blood impact should include an impact splat")
	_expect(_has_grass_green_material(effect), "Green blood impact materials should be grass green")
	var weapon_source := FileAccess.get_file_as_string("res://scripts/weapon_system.gd")
	_expect(weapon_source.contains("_broadcast_green_blood_impact.rpc"), "WeaponSystem should broadcast green blood impacts on player bullet hits")
	_expect(weapon_source.contains("GreenBloodImpactScript.spawn"), "WeaponSystem should instantiate GreenBloodImpact from the broadcast")
	effect.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _has_death_dissolve_shader(root: Node) -> bool:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.material_override is ShaderMaterial:
			var shader_material := mesh_instance.material_override as ShaderMaterial
			if shader_material.shader == load("res://shaders/death_dissolve.gdshader"):
				return true
	for child in root.get_children():
		if _has_death_dissolve_shader(child):
			return true
	return false


func _has_grass_green_material(root: Node) -> bool:
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		var material: Material = mesh_instance.material_override
		if material == null and mesh_instance.mesh is PrimitiveMesh:
			material = (mesh_instance.mesh as PrimitiveMesh).material
		if material is StandardMaterial3D:
			var standard := material as StandardMaterial3D
			if standard.albedo_color.g > 0.85 and standard.albedo_color.r < 0.5 and standard.albedo_color.b < 0.35:
				return true
	for child in root.get_children():
		if _has_grass_green_material(child):
			return true
	return false


func _find_first_child_named(root: Node, target_name: String) -> Node:
	if String(root.name) == target_name:
		return root
	for child in root.get_children():
		var found := _find_first_child_named(child, target_name)
		if found:
			return found
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
