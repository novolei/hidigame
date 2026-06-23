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

	player.queue_free()
	await get_tree().process_frame


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
