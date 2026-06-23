extends Node3D

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var old_players := Network.players.duplicate(true)
	Network.players.clear()
	Network.players[1] = {
		"name": "EnvironmentBlendProbe",
		"role": Network.Role.CHAMELEON,
		"character_model": CharacterSkinCatalog.DEFAULT_ID,
	}

	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var player = player_scene.instantiate()
	player.name = "1"
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame

	var camouflage = player.get_node_or_null("CamouflageSystem")
	var blend = player.get_node_or_null("ChameleonEnvironmentBlendSystem")
	var sculpt = player.get_node_or_null("ChameleonSculptSystem")
	_expect(camouflage != null, "Chameleon player should attach CamouflageSystem")
	_expect(blend != null, "Chameleon player should attach ChameleonEnvironmentBlendSystem")
	_expect(sculpt == null, "Chameleon C-key setup should not eagerly create the old sculpt system")

	if camouflage and blend:
		_expect(blend.get_random_hand().size() == 5, "Environment blend should assign five random prop options per Chameleon")
		var options: Array = blend.get_wheel_options()
		_expect(options.size() == 7, "Environment blend wheel should expose Spray Self, five presets, and Cloud 3D")
		_expect(str((options[0] as Dictionary).get("type", "")) == "paint_self", "First wheel option should keep spray-self painting")
		_expect(str((options[options.size() - 1] as Dictionary).get("type", "")) == "cloud_3d", "Last wheel option should enter cloud 3D capture")

		var absorb_event := InputEventAction.new()
		absorb_event.action = "camouflage_absorb"
		absorb_event.pressed = true
		player._handle_chameleon_input(absorb_event)
		await get_tree().process_frame
		_expect(bool(blend.call("is_active")), "Pressing C should open the environment blend wheel")
		_expect(str(blend.call("get_state")) == "wheel", "C-key entry should start at the environment blend wheel")
		_expect(not bool(camouflage.get("skill_active")), "Opening the wheel should not immediately enter paint mode")

		blend.select_option(0)
		await get_tree().process_frame
		_expect(not bool(blend.call("is_active")), "Spray Self should close the wheel")
		_expect(bool(camouflage.get("skill_active")), "Spray Self should enter the existing self-paint brush flow")
		camouflage.deactivate_skill()
		await get_tree().process_frame
		player._handle_chameleon_input(absorb_event)
		await get_tree().process_frame

		blend.select_option(1)
		await get_tree().process_frame
		_expect(str(blend.call("get_state")) == "prop_preview", "Selecting a preset should enter the four-second original prop preview")
		var summary: Dictionary = blend.call("get_debug_summary")
		_expect(bool(summary.get("has_preview", false)), "Preset preview should spawn a visible prop mesh immediately")

		blend.call("_enter_prop_paint_mode", int(blend.get("_preview_generation")))
		await get_tree().process_frame
		_expect(str(blend.call("get_state")) == "prop_paint", "After preview, the selected prop should become a white paintable model")
		_expect(bool(camouflage.get("skill_active")), "Prop white-model phase should reuse the existing paint brush")

		var preview_root := blend.get("_preview_node") as Node3D
		var preview_mesh := _find_first_mesh(preview_root)
		var preview_relative_mesh_path := str(preview_root.get_path_to(preview_mesh)) if preview_root and preview_mesh else ""
		_expect(preview_mesh != null, "White-model prop preview should expose at least one paintable mesh")
		if preview_mesh:
			var preview_mesh_path := str(player.get_path_to(preview_mesh))
			player.submit_camouflage_brush_stroke_batch(
				PackedVector2Array([Vector2(0.5, 0.5)]),
				Color(0.24, 0.58, 0.31, 1.0),
				56.0,
				0.0,
				PackedVector3Array([preview_mesh.global_position]),
				Vector3.UP,
				preview_mesh_path,
				0
			)
			await get_tree().process_frame
			var preview_payload: Dictionary = player.capture_environment_prop_paint_payload(preview_root)
			_expect(not preview_payload.is_empty(), "Preview white-model brush strokes should be captured into a sync payload before commit")
			if not preview_payload.is_empty():
				_expect((preview_payload.get("surfaces", []) as Array).size() > 0, "Paint sync payload should include at least one painted surface")

		camouflage.set("has_sampled_color", true)
		camouflage.set("brush_color", Color(0.24, 0.58, 0.31, 1.0))
		camouflage.set("paint_roughness", 0.41)
		camouflage.set("paint_metallic", 0.08)
		blend.call("_commit_selected_prop")
		await get_tree().process_frame
		_expect(player.is_disguised(), "Committing a painted preset should transform the Chameleon into that prop")
		_expect(not player.get_disguise_name().is_empty(), "Committed prop disguise should carry a synced disguise name")
		var prop_node := player.get_node_or_null("3DGodotRobot/PropDisguise")
		_expect(prop_node != null, "Committed prop disguise should be attached under the player body")
		if prop_node and not preview_relative_mesh_path.is_empty():
			var final_mesh := prop_node.get_node_or_null(preview_relative_mesh_path) as MeshInstance3D
			_expect(final_mesh != null, "Final prop disguise should preserve preview mesh relative paths for paint sync")
			if final_mesh:
				var final_material := final_mesh.get_surface_override_material(0)
				_expect(final_material is ShaderMaterial, "Final prop disguise should restore the actual white-model paint texture as a shader layer")
				if final_material is ShaderMaterial:
					_expect(bool((final_material as ShaderMaterial).get_meta("camouflage_paint_layer", false)), "Restored prop paint material should be tagged as camouflage paint layer")
					var texture = (final_material as ShaderMaterial).get_shader_parameter("paint_texture")
					_expect(texture is Texture2D, "Restored prop paint material should carry the synced brush texture")

		player.clear_prop_disguise()
		await get_tree().process_frame
		blend.open_wheel()
		await get_tree().process_frame
		blend.select_option(options.size() - 1)
		await get_tree().process_frame
		_expect(str(blend.call("get_state")) == "cloud_capture", "Cloud 3D option should enter camera capture mode")
		blend.deactivate()

	player.queue_free()
	Network.players = old_players
	await get_tree().process_frame

	if failures.is_empty():
		print("[ChameleonEnvironmentBlendIntegrationTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ChameleonEnvironmentBlendIntegrationTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _find_first_mesh(node: Node) -> MeshInstance3D:
	if not node:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_first_mesh(child)
		if found:
			return found
	return null
