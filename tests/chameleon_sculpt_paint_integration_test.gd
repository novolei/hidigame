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
		_test_paint_rpc_batch_chunking(player as Character)
		_test_dedicated_server_paint_render_skip_contract()
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
		var max_paint_seconds: float = float(camouflage.call("get_paint_session_max_seconds"))
		var start_remaining: float = float(camouflage.call("get_paint_session_remaining"))
		_expect(start_remaining > max_paint_seconds - 0.5 and start_remaining <= max_paint_seconds, "Spray Self should start a bounded paint session")
		camouflage.call("_process", max_paint_seconds + 0.1)
		_expect(not bool(camouflage.get("skill_active")), "Spray Self paint session should auto-stop after the maximum duration")
		_expect(float(camouflage.call("get_paint_session_remaining")) <= 0.0, "Expired paint session should clear its remaining time")
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


func _test_paint_rpc_batch_chunking(player: Character) -> void:
	if player == null:
		failures.append("Paint RPC chunk test needs a live Character")
		return
	var uvs: PackedVector2Array = PackedVector2Array()
	var world_positions: PackedVector3Array = PackedVector3Array()
	var brush_radii: PackedFloat32Array = PackedFloat32Array()
	for index in range(17):
		uvs.append(Vector2(float(index) / 16.0, 0.5))
		world_positions.append(Vector3(float(index) * 0.01, 1.0, 0.0))
		brush_radii.append(24.0 + float(index % 3))
	var chunks: Array[Dictionary] = player._make_camouflage_paint_batch_chunks(
		uvs,
		world_positions,
		brush_radii,
		PackedVector2Array(),
		PackedInt32Array(),
		PackedFloat32Array()
	)
	_expect(chunks.size() == 2, "Paint batch chunking should split 17 stamps into 16/1 RPC chunks")
	var total_stamps: int = 0
	for raw_chunk in chunks:
		var chunk: Dictionary = raw_chunk
		var chunk_uvs: PackedVector2Array = chunk.get("uvs", PackedVector2Array())
		total_stamps += chunk_uvs.size()
		_expect(chunk_uvs.size() <= Character.CAMOUFLAGE_PAINT_RPC_MAX_STAMPS, "Each paint RPC chunk should stay under the stamp budget")
	_expect(total_stamps == uvs.size(), "Paint RPC chunking should preserve every UV stamp")

	var clip_uvs: PackedVector2Array = PackedVector2Array()
	var clip_counts: PackedInt32Array = PackedInt32Array()
	var clip_stamp_count: int = 9
	var clip_triangles_per_stamp: int = CamouflageSystem.BRUSH_UV_CLIP_MAX_TRIANGLES
	for stamp_index in range(clip_stamp_count):
		clip_counts.append(clip_triangles_per_stamp)
		for corner_index in range(clip_triangles_per_stamp * 3):
			var u: float = float((stamp_index + corner_index) % 7) / 7.0
			clip_uvs.append(Vector2(u, 1.0 - u))
	var clip_chunks: Array[Dictionary] = player._make_camouflage_paint_batch_chunks(
		uvs.slice(0, clip_stamp_count),
		world_positions.slice(0, clip_stamp_count),
		brush_radii.slice(0, clip_stamp_count),
		clip_uvs,
		clip_counts,
		PackedFloat32Array()
	)
	_expect(clip_chunks.size() > 1, "Paint RPC chunking should split heavy UV clip payloads by byte budget")
	var total_clip_counts: int = 0
	for raw_clip_chunk in clip_chunks:
		var clip_chunk: Dictionary = raw_clip_chunk
		var chunk_uvs: PackedVector2Array = clip_chunk.get("uvs", PackedVector2Array())
		var chunk_world_positions: PackedVector3Array = clip_chunk.get("world_positions", PackedVector3Array())
		var chunk_clip_triangles: PackedVector2Array = clip_chunk.get("uv_clip_triangles", PackedVector2Array())
		var chunk_clip_counts: PackedInt32Array = clip_chunk.get("uv_clip_triangle_counts", PackedInt32Array())
		var chunk_metrics: PackedFloat32Array = clip_chunk.get("uv_footprint_metrics", PackedFloat32Array())
		var chunk_bytes: int = player._camouflage_paint_batch_approx_bytes(chunk_uvs.size(), chunk_world_positions.size(), chunk_clip_triangles.size(), chunk_metrics.size())
		for count_value in chunk_clip_counts:
			total_clip_counts += int(count_value)
		_expect(chunk_bytes <= Character.CAMOUFLAGE_PAINT_RPC_MAX_BYTES, "Heavy paint RPC chunks should stay under the byte budget")
	_expect(total_clip_counts == clip_stamp_count * clip_triangles_per_stamp, "Paint RPC chunking should preserve UV clip triangle counts")


func _test_dedicated_server_paint_render_skip_contract() -> void:
	var player_source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	_expect(player_source.contains("func _should_skip_camouflage_paint_rendering"), "Player should declare a dedicated-server paint rendering guard")
	_expect(player_source.contains("return _is_dedicated_public_server_runtime()"), "Dedicated public room servers should skip local paint rendering")
	_expect(player_source.contains("func _clear_camouflage_paint_render_cache"), "Player should clear paint render caches when local paint rendering is disabled")
	_expect(player_source.contains("_camouflage_paint_texture = null"), "Paint render cache cleanup should release the global paint texture reference")
	_expect(player_source.contains("if _should_skip_camouflage_paint_rendering():"), "Paint start/stroke handlers should guard dedicated public server rendering")
	_expect(player_source.contains("@rpc(\"any_peer\", \"call_local\", \"unreliable_ordered\")\nfunc _apply_camouflage_brush_stroke_batch"), "Paint batch transport should remain unreliable ordered visual sync")


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
