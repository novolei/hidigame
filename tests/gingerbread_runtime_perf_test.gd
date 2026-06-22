extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var started := Time.get_ticks_msec()
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var player_scene := load("res://scenes/level/player.tscn") as PackedScene
	if not player_scene:
		push_error("[GingerbreadRuntimePerfTest] Player scene did not load")
		get_tree().quit(1)
		return

	var player := player_scene.instantiate()
	player.name = "1"
	add_child(player)
	await get_tree().process_frame

	var t_model_start := Time.get_ticks_msec()
	player.set_character_model("gingerbread")
	await get_tree().process_frame
	await get_tree().process_frame
	var t_model_done := Time.get_ticks_msec()

	var ginger_root := player.get_node_or_null("3DGodotRobot/CustomCharacterSkin")
	var ginger_mesh := _find_first_mesh(ginger_root)
	if not ginger_mesh:
		failures.append("Rigged 6K Meshy gingerbread should expose a runtime paintable mesh")
	else:
		var tri_count := _count_triangles(ginger_mesh)
		if tri_count <= 0 or tri_count > 8000:
			failures.append("Rigged 6K Meshy gingerbread triangle count should stay near the 6K target; got %d" % tri_count)

		var aabb := ginger_mesh.get_aabb()
		var center := ginger_mesh.global_transform * (aabb.position + aabb.size * 0.5)
		var extent := maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
		var camera_axes := _camera_view_axes_for_mesh(ginger_mesh)
		var camera := Camera3D.new()
		camera.name = "ProbeCamera"
		camera.fov = 45.0
		add_child(camera)
		camera.global_position = center + (camera_axes.get("view_axis", Vector3.FORWARD) as Vector3) * maxf(extent * 2.35, 2.0)
		camera.look_at(center, camera_axes.get("up_axis", Vector3.UP) as Vector3)
		camera.current = true
		await get_tree().process_frame

		var system := CamouflageSystem.new()
		system.camouflage_owner = player
		system.camera = camera
		system.brush_radius = 48.0
		var t_activate_start := Time.get_ticks_msec()
		system.activate_skill()
		system.has_sampled_color = false
		system.call("_process", 0.016)
		system.deactivate_skill()
		var t_activate_done := Time.get_ticks_msec()
		var mesh_path := str(player.get_path_to(ginger_mesh))
		system.activate_skill()
		var screen_point := camera.unproject_position(center)
		var t_project_start := Time.get_ticks_msec()
		var hit := system.call("_project_screen_to_body_surface", screen_point, false, mesh_path, 0) as Dictionary
		var t_project_done := Time.get_ticks_msec()
		if hit.is_empty():
			failures.append("Rigged 6K Meshy gingerbread should produce an exact brush projection hit")
		else:
			var texture_key := "%s:%d" % [mesh_path, 0]
			system.has_sampled_color = true
			system.brush_color = Color(0.95, 0.18, 0.08, 1.0)
			system._surface_lock.clear()
			system._surface_lock_mouse_position = Vector2(-INF, -INF)
			var click_surface := system.call("_get_surface_lock", true, screen_point) as Dictionary
			var click_texture_key := "%s:%d" % [str(click_surface.get("mesh_path", mesh_path)), int(click_surface.get("surface", 0))]
			var preview_texture_delta := 0.0
			var t_paint_start := Time.get_ticks_msec()
			if click_surface.is_empty():
				failures.append("Rigged 6K Meshy gingerbread screen click should resolve a visible brush surface")
			else:
				system.call("_update_surface_preview", click_surface)
				var surface_preview := player.get_node_or_null("CamouflageSurfacePreview") as MeshInstance3D
				var click_position: Vector3 = click_surface.get("position", Vector3.ZERO)
				var click_normal: Vector3 = click_surface.get("normal", Vector3.UP).normalized()
				if not surface_preview or not surface_preview.visible:
					failures.append("Rigged 6K Meshy brush preview should be visible on the current clicked surface")
				elif surface_preview.global_position.distance_to(click_position + click_normal * CamouflageSystem.SURFACE_PREVIEW_OFFSET) > 0.002:
					failures.append("Rigged 6K Meshy brush preview should stay snapped to the exact clicked surface point")
				elif click_surface.has("world_v0") and click_surface.has("world_v1") and click_surface.has("world_v2"):
					var preview_world_radius := surface_preview.global_transform.basis.x.length()
					var preview_texture_radius := CamouflageSystem._estimate_texture_radius_from_triangle(
						preview_world_radius,
						click_surface.get("world_v0", Vector3.ZERO),
						click_surface.get("world_v1", Vector3.ZERO),
						click_surface.get("world_v2", Vector3.ZERO),
						click_surface.get("face_uv0", Vector2.ZERO),
						click_surface.get("face_uv1", Vector2.ZERO),
						click_surface.get("face_uv2", Vector2.ZERO)
					)
					var click_texture_radius := float(click_surface.get("texture_radius", 0.0))
					preview_texture_delta = absf(preview_texture_radius - click_texture_radius)
					if preview_texture_delta > maxf(2.0, click_texture_radius * 0.08):
						failures.append("Rigged 6K Meshy brush preview radius should match the actual painted texture radius preview=%.3f painted=%.3f" % [preview_texture_radius, click_texture_radius])
				_reset_target_canvas(player, click_texture_key)
			system.call("_paint_at_mouse", true, screen_point)
			await get_tree().process_frame
			var t_paint_done := Time.get_ticks_msec()
			var painted := player._camouflage_paint_textures.get(click_texture_key) as Texture2D
			var image := painted.get_image() if painted else null
			var hit_pixel := CamouflageSystem._brush_uv_to_pixel_center_float(click_surface.get("uv", hit.get("uv", Vector2.ZERO)))
			var click_area := _painted_pixel_count(image, hit_pixel, 12, 0.08)
			if click_area < 250:
				failures.append("Rigged 6K Meshy gingerbread brush click should paint a continuous visible area count=%d" % click_area)
			var paint_material := ginger_mesh.get_surface_override_material(0)
			if not paint_material is ShaderMaterial:
				failures.append("Rigged 6K Meshy gingerbread brush click should bind the paint-layer shader to the clicked mesh surface")
			else:
				var shader_material := paint_material as ShaderMaterial
				if not bool(shader_material.get_meta("camouflage_paint_layer", false)):
					failures.append("Rigged 6K Meshy gingerbread paint-layer material should be tagged for reuse")
				if shader_material.get_shader_parameter("paint_texture") != painted:
					failures.append("Rigged 6K Meshy gingerbread paint-layer material should display the exact texture written by the brush")
				if bool(shader_material.get_shader_parameter("use_base_texture")) and not shader_material.get_shader_parameter("base_texture") is Texture2D:
					failures.append("Rigged 6K Meshy gingerbread paint-layer material should preserve the original base texture when enabled")
			var center_alpha := _max_alpha_near(image, hit_pixel, 1)
			var click_centroid := _paint_alpha_centroid(image, hit_pixel, 96)
			var click_centroid_distance := click_centroid.distance_to(hit_pixel) if click_centroid.x < INF else INF
			if center_alpha < 0.80:
				failures.append("Rigged 6K Meshy gingerbread brush click should color the exact projected UV center alpha=%.3f" % center_alpha)
			elif click_centroid.x >= INF or click_centroid_distance > 2.0:
				failures.append("Rigged 6K Meshy gingerbread brush click should stay centered on the projected UV hit centroid=%s hit=%s distance=%.3f" % [str(click_centroid), str(hit_pixel), click_centroid_distance])
			var metrics := system.get_performance_metrics()
			var submitted_stamps := int(metrics.get("brush_stamps_submitted", 0))
			if submitted_stamps <= 1:
				failures.append("Rigged 6K Meshy gingerbread brush click should use bounded precision samples for accurate single-click placement")
			elif submitted_stamps > CamouflageSystem.BRUSH_PRECISION_DAB_MAX_SAMPLES:
				failures.append("Rigged 6K Meshy gingerbread brush click should keep precision samples bounded for performance; got %d" % submitted_stamps)
			if t_paint_done - t_paint_start > 120:
				failures.append("Rigged 6K Meshy gingerbread precision brush click should stay performant on the CPU fallback path; got %dms" % [t_paint_done - t_paint_start])
			var cold_click_elapsed := -1
			var cold_click_was_queued := false
			var cold_click_alpha := 0.0
			var cold_click_area := 0
			var cold_system := CamouflageSystem.new()
			cold_system.camouflage_owner = player
			cold_system.camera = camera
			cold_system.brush_radius = system.brush_radius
			cold_system.activate_skill()
			cold_system.has_sampled_color = true
			cold_system.brush_color = Color(0.22, 0.86, 0.42, 1.0)
			_reset_target_canvas(player, click_texture_key)
			cold_system.call("_request_paintable_mesh_cache_warmup")
			var cold_had_pending_jobs := bool(cold_system.call("_has_pending_mesh_hit_jobs"))
			var cold_click_start := Time.get_ticks_msec()
			cold_system.call("_paint_at_mouse", true, screen_point)
			cold_click_was_queued = cold_system._pending_forced_paint
			if cold_had_pending_jobs:
				if not cold_click_was_queued:
					failures.append("Rigged 6K Meshy cold first brush click should queue while exact hit cache is preparing")
				elif cold_system._pending_forced_paint_screen_position.distance_to(screen_point) > 0.001:
					failures.append("Rigged 6K Meshy cold first brush click should preserve the original screen point while queued")
			for _cold_attempt in range(30):
				cold_system.call("_finalize_mesh_hit_cache_jobs")
				if not bool(cold_system.call("_has_pending_mesh_hit_jobs")) and not cold_system._pending_forced_paint:
					break
				await get_tree().process_frame
			await get_tree().process_frame
			cold_click_elapsed = Time.get_ticks_msec() - cold_click_start
			if cold_system._pending_forced_paint:
				failures.append("Rigged 6K Meshy cold first brush click should flush automatically after hit cache preparation")
			var cold_surface := cold_system._surface_lock
			var cold_hit_pixel := hit_pixel
			if cold_surface.is_empty():
				failures.append("Rigged 6K Meshy cold first brush click should resolve a surface after async cache flush")
			else:
				var cold_screen: Vector2 = cold_surface.get("screen", Vector2(-INF, -INF))
				if cold_screen.distance_to(screen_point) > 0.001:
					failures.append("Rigged 6K Meshy cold first brush click should flush at the original screen point screen=%s expected=%s" % [str(cold_screen), str(screen_point)])
				cold_hit_pixel = CamouflageSystem._brush_uv_to_pixel_center_float(cold_surface.get("uv", click_surface.get("uv", Vector2.ZERO)))
			var cold_texture := player._camouflage_paint_textures.get(click_texture_key) as Texture2D
			var cold_image := cold_texture.get_image() if cold_texture else null
			cold_click_alpha = _max_alpha_near(cold_image, cold_hit_pixel, 1)
			cold_click_area = _painted_pixel_count(cold_image, cold_hit_pixel, 12, 0.08)
			var cold_centroid := _paint_alpha_centroid(cold_image, cold_hit_pixel, 96)
			var cold_centroid_distance := cold_centroid.distance_to(cold_hit_pixel) if cold_centroid.x < INF else INF
			if cold_click_alpha < 0.80:
				failures.append("Rigged 6K Meshy cold first brush click should paint the original projected UV center alpha=%.3f queued=%s" % [cold_click_alpha, str(cold_click_was_queued)])
			elif cold_click_area < 250:
				failures.append("Rigged 6K Meshy cold first brush click should paint a continuous area count=%d queued=%s" % [cold_click_area, str(cold_click_was_queued)])
			elif cold_centroid.x >= INF or cold_centroid_distance > 2.0:
				failures.append("Rigged 6K Meshy cold first brush click should stay centered after async cache flush centroid=%s hit=%s distance=%.3f" % [str(cold_centroid), str(cold_hit_pixel), cold_centroid_distance])
			if cold_click_elapsed > 220:
				failures.append("Rigged 6K Meshy cold first brush click should remain responsive through async cache flush; got %dms" % cold_click_elapsed)
			cold_system.free()
			var sample_hits := _collect_visible_sample_hits(system, camera, ginger_mesh, mesh_path, false)
			if sample_hits.size() < 4:
				failures.append("Rigged 6K Meshy gingerbread should provide several visible brushable screen points; got %d" % sample_hits.size())
			var multi_total_paint_ms := 0
			var multi_worst_paint_ms := 0
			var multi_average_ms := 0.0
			var multi_min_center_alpha := INF
			var multi_max_centroid_distance := 0.0
			var multi_min_area := INF
			var drag_elapsed := -1
			var drag_warmup_elapsed := -1
			for sample_hit in sample_hits:
				var sample_screen: Vector2 = sample_hit.get("screen", camera.unproject_position(sample_hit.get("position", Vector3.ZERO)))
				var expected_sample_hit := sample_hit
				system._surface_lock = expected_sample_hit
				system._surface_lock_mouse_position = sample_screen
				system._stroke_wait = 0.0
				var sample_texture_key := "%s:%d" % [str(expected_sample_hit.get("mesh_path", mesh_path)), int(expected_sample_hit.get("surface", 0))]
				_reset_target_canvas(player, sample_texture_key)
				var sample_start := Time.get_ticks_msec()
				system.call("_paint_at_mouse", true, sample_screen)
				await get_tree().process_frame
				var sample_elapsed := Time.get_ticks_msec() - sample_start
				multi_total_paint_ms += sample_elapsed
				multi_worst_paint_ms = maxi(multi_worst_paint_ms, sample_elapsed)
				var sample_texture := player._camouflage_paint_textures.get(sample_texture_key) as Texture2D
				var sample_image := sample_texture.get_image() if sample_texture else null
				var sample_pixel := CamouflageSystem._brush_uv_to_pixel_center_float(expected_sample_hit.get("uv", Vector2.ZERO))
				var sample_alpha := _max_alpha_near(sample_image, sample_pixel, 1)
				var sample_centroid := _paint_alpha_centroid(sample_image, sample_pixel, 96)
				var sample_centroid_distance := sample_centroid.distance_to(sample_pixel) if sample_centroid.x < INF else INF
				var sample_area := _painted_pixel_count(sample_image, sample_pixel, 12, 0.08)
				multi_min_center_alpha = minf(multi_min_center_alpha, sample_alpha)
				multi_max_centroid_distance = maxf(multi_max_centroid_distance, sample_centroid_distance)
				multi_min_area = minf(multi_min_area, float(sample_area))
				if sample_alpha < 0.80:
					failures.append("Rigged 6K Meshy multi-point brush click should color the exact projected UV center alpha=%.3f uv=%s" % [sample_alpha, str(sample_hit.get("uv", Vector2.ZERO))])
				elif sample_centroid.x >= INF or sample_centroid_distance > 2.0:
					failures.append("Rigged 6K Meshy multi-point brush click should keep paint centered on the projected UV centroid=%s hit=%s distance=%.3f" % [str(sample_centroid), str(sample_pixel), sample_centroid_distance])
				elif sample_area < 250:
					failures.append("Rigged 6K Meshy multi-point brush click should paint a visible continuous area count=%d" % sample_area)
			if not sample_hits.is_empty():
				multi_average_ms = float(multi_total_paint_ms) / float(sample_hits.size())
				if multi_average_ms > 80.0 or multi_worst_paint_ms > 120:
					failures.append("Rigged 6K Meshy multi-point brush clicks should stay performant avg=%.2fms worst=%dms" % [multi_average_ms, multi_worst_paint_ms])
			if sample_hits.size() >= 2:
				_reset_target_canvas(player, texture_key)
				var drag_brush_radius := 24.0
				var min_interpolated_drag_distance := drag_brush_radius * CamouflageSystem.BRUSH_SCREEN_STAMP_SPACING_FACTOR + 1.0
				var drag_sample_hits := _collect_visible_sample_hits(system, camera, ginger_mesh, mesh_path, true)
				var drag_path := _find_continuous_drag_path(system, drag_sample_hits, mesh_path, -1, 4, min_interpolated_drag_distance)
				var drag_system := CamouflageSystem.new()
				drag_system.camouflage_owner = player
				drag_system.camera = camera
				drag_system.brush_radius = drag_brush_radius
				drag_system.activate_skill()
				drag_system.has_sampled_color = true
				drag_system.brush_color = Color(0.18, 0.62, 0.95, 1.0)
				var drag_warmup_start_ms := Time.get_ticks_msec()
				drag_system.call("_request_paintable_mesh_cache_warmup")
				for _warmup_attempt in range(20):
					drag_system.call("_finalize_mesh_hit_cache_jobs")
					if not bool(drag_system.call("_has_pending_mesh_hit_jobs")):
						break
					await get_tree().process_frame
				drag_warmup_elapsed = Time.get_ticks_msec() - drag_warmup_start_ms
				if bool(drag_system.call("_has_pending_mesh_hit_jobs")):
					failures.append("Rigged 6K Meshy brush warmup should finish skinned hit cache jobs before drag starts")
				drag_system.reset_performance_metrics()
				if drag_path.is_empty():
					failures.append("Rigged 6K Meshy drag brush should project intermediate screen path points on the same mesh surface")
				else:
					_reset_drag_path_canvases(player, mesh_path, drag_path)
					var drag_start_hit := drag_path.get("start", {}) as Dictionary
					var drag_end_hit := drag_path.get("end", {}) as Dictionary
					var drag_path_hits := drag_path.get("path_hits", []) as Array
					var drag_start_screen: Vector2 = drag_start_hit.get("screen", Vector2.ZERO)
					var drag_end_screen: Vector2 = drag_end_hit.get("screen", Vector2.ZERO)

					drag_system._surface_lock.clear()
					drag_system._surface_lock_mouse_position = Vector2(-INF, -INF)
					drag_system.call("_paint_at_mouse", false, drag_start_screen)
					var release_endpoint_event := InputEventMouseButton.new()
					release_endpoint_event.button_index = MOUSE_BUTTON_LEFT
					release_endpoint_event.pressed = false
					release_endpoint_event.position = drag_end_screen
					drag_system.handle_brush_input(release_endpoint_event)
					if drag_system._pending_drag_paint:
						failures.append("Rigged 6K Meshy brush release should paint the final endpoint even without a queued drag motion")
					await get_tree().process_frame
					var release_endpoint_key := "%s:%d" % [mesh_path, int(drag_end_hit.get("surface", 0))]
					var release_endpoint_texture := player._camouflage_paint_textures.get(release_endpoint_key) as Texture2D
					var release_endpoint_image := release_endpoint_texture.get_image() if release_endpoint_texture else null
					var release_endpoint_pixel := CamouflageSystem._brush_uv_to_pixel_center_float(drag_end_hit.get("uv", Vector2.ZERO))
					var release_endpoint_alpha := _max_alpha_near(release_endpoint_image, release_endpoint_pixel, 3)
					var release_endpoint_area := _painted_pixel_count(release_endpoint_image, release_endpoint_pixel, 8, 0.04)
					if release_endpoint_alpha < 0.20 or release_endpoint_area < 8:
						failures.append("Rigged 6K Meshy release-only brush endpoint should leave visible painted coverage alpha=%.3f area=%d" % [release_endpoint_alpha, release_endpoint_area])
					_reset_drag_path_canvases(player, mesh_path, drag_path)
					drag_system.reset_performance_metrics()
					drag_system._pending_drag_paint = false
					drag_system._pending_drag_screen_position = Vector2.ZERO
					drag_system._pending_forced_paint = false
					drag_system._last_stroke_world_position = Vector3(INF, INF, INF)
					drag_system._last_stroke_uv = Vector2(-1.0, -1.0)
					drag_system._last_stroke_screen_position = Vector2(-INF, -INF)
					drag_system._last_stroke_key = ""
					drag_system._last_stroke_mesh_path = ""
					drag_system._stroke_wait = 0.0
					var drag_start_ms := Time.get_ticks_msec()
					drag_system._surface_lock.clear()
					drag_system._surface_lock_mouse_position = Vector2(-INF, -INF)
					drag_system.call("_paint_at_mouse", false, drag_start_screen)
					drag_system.call("_paint_at_mouse", false, drag_end_screen)
					if not drag_system._pending_drag_paint:
						failures.append("Rigged 6K Meshy throttled drag should queue the skipped end screen position")
					elif drag_system._pending_drag_screen_position.distance_to(drag_end_screen) > 0.001:
						failures.append("Rigged 6K Meshy throttled drag should preserve the exact skipped end screen position")
					var drag_release_event := InputEventMouseButton.new()
					drag_release_event.button_index = MOUSE_BUTTON_LEFT
					drag_release_event.pressed = false
					drag_release_event.position = drag_end_screen
					drag_system.handle_brush_input(drag_release_event)
					if drag_system._pending_drag_paint:
						failures.append("Rigged 6K Meshy brush release should flush the throttled final drag point")
					await get_tree().process_frame
					drag_elapsed = Time.get_ticks_msec() - drag_start_ms
					var weak_drag_points := 0
					for drag_path_hit in drag_path_hits:
						var drag_path_hit_dict := drag_path_hit as Dictionary
						var drag_path_key := "%s:%d" % [mesh_path, int(drag_path_hit_dict.get("surface", 0))]
						var drag_texture := player._camouflage_paint_textures.get(drag_path_key) as Texture2D
						var drag_image := drag_texture.get_image() if drag_texture else null
						var drag_path_pixel := CamouflageSystem._brush_uv_to_pixel_center_float(drag_path_hit_dict.get("uv", Vector2.ZERO))
						var drag_path_alpha := _max_alpha_near(drag_image, drag_path_pixel, 3)
						var drag_path_area := _painted_pixel_count(drag_image, drag_path_pixel, 8, 0.04)
						if drag_path_alpha < 0.20 or drag_path_area < 8:
							weak_drag_points += 1
					var drag_metrics := drag_system.get_performance_metrics()
					if weak_drag_points > 0:
						failures.append("Rigged 6K Meshy drag brush should leave continuous painted coverage along the projected screen path; weak_points=%d/%d" % [weak_drag_points, drag_path_hits.size()])
					if int(drag_metrics.get("brush_stamps_submitted", 0)) < 2:
						failures.append("Rigged 6K Meshy drag brush should submit multiple center stamps along the model surface")
					if int(drag_metrics.get("brush_precision_local_samples", 0)) <= 0:
						failures.append("Rigged 6K Meshy held drag brush should use bounded local precision samples on the final dab")
					if int(drag_metrics.get("targeted_surface_projection_calls", 0)) <= 0:
						failures.append("Rigged 6K Meshy drag brush should run targeted projection for interpolated path stamps")
					if int(drag_metrics.get("untargeted_surface_projection_calls", 0)) <= 0:
						failures.append("Rigged 6K Meshy drag brush should resolve real screen-space drag endpoints through the surface lock")
					if int(drag_metrics.get("mesh_hit_cache_hits", 0)) <= 0:
						failures.append("Rigged 6K Meshy warmed drag should use the prepared skinned hit cache")
					if int(drag_metrics.get("mesh_hit_cache_misses", 0)) > 0 or int(drag_metrics.get("mesh_hit_cache_async_jobs", 0)) > 0:
						failures.append("Rigged 6K Meshy warmed drag should not rebuild hit caches during the stroke metrics=%s" % str(drag_metrics))
					if int(drag_metrics.get("untargeted_surface_projection_calls", 0)) > 2:
						failures.append("Rigged 6K Meshy drag brush should limit full-body projection to the real screen-space drag endpoints metrics=%s" % str(drag_metrics))
					if drag_elapsed > 160:
						failures.append("Rigged 6K Meshy drag brush should stay performant; got %dms" % drag_elapsed)
				drag_system.deactivate_skill()
				drag_system.free()
			var preview_save_error := _save_brush_precision_preview(player, texture_key, system, sample_hits)
			if preview_save_error != OK:
				failures.append("Rigged 6K Meshy brush precision preview PNG should be saved for visual QA; error=%d" % preview_save_error)
			_save_model_surface_preview()
			print("[GingerbreadRuntimePerfTest] multi_points=%d multi_avg_ms=%.2f multi_worst_ms=%d drag_warmup_ms=%d drag_ms=%d" % [
				sample_hits.size(),
				multi_average_ms,
				multi_worst_paint_ms,
				drag_warmup_elapsed,
				drag_elapsed,
			])
			print("[GingerbreadRuntimePerfTest] load_ms=%d project_ms=%d paint_ms=%d tris=%d metrics=%s" % [
				t_model_done - t_model_start,
				t_project_done - t_project_start,
				t_paint_done - t_paint_start,
				_count_triangles(ginger_mesh),
				str(metrics),
			])
			print("[GingerbreadRuntimePerfTest] quality click_alpha=%.3f click_area=%d click_centroid_distance=%.3f cold_queued=%s cold_ms=%d cold_alpha=%.3f cold_area=%d multi_min_alpha=%.3f multi_min_area=%.0f multi_max_centroid_distance=%.3f preview_texture_delta=%.3f" % [
				center_alpha,
				click_area,
				click_centroid_distance,
				str(cold_click_was_queued),
				cold_click_elapsed,
				cold_click_alpha,
				cold_click_area,
				multi_min_center_alpha,
				multi_min_area,
				multi_max_centroid_distance,
				preview_texture_delta,
			])
		print("[GingerbreadRuntimePerfTest] activate_ms=%d" % [t_activate_done - t_activate_start])
		system.deactivate_skill()
		system.free()
		camera.queue_free()

	var elapsed := Time.get_ticks_msec() - started
	if failures.is_empty():
		print("[GingerbreadRuntimePerfTest] PASS elapsed_ms=%d" % elapsed)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[GingerbreadRuntimePerfTest] " + failure)
		get_tree().quit(1)


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


func _count_triangles(mesh_instance: MeshInstance3D) -> int:
	if not mesh_instance or not mesh_instance.mesh:
		return 0
	var total := 0
	for surface in range(mesh_instance.mesh.get_surface_count()):
		var arrays := mesh_instance.mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if not indices.is_empty():
			total += int(indices.size() / 3)
		else:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += int(vertices.size() / 3)
	return total


func _camera_view_axes_for_mesh(mesh_instance: MeshInstance3D) -> Dictionary:
	var aabb := mesh_instance.get_aabb()
	var basis := mesh_instance.global_transform.basis
	var axes := [
		{"axis": basis.x.normalized(), "size": absf(aabb.size.x)},
		{"axis": basis.y.normalized(), "size": absf(aabb.size.y)},
		{"axis": basis.z.normalized(), "size": absf(aabb.size.z)},
	]
	var view_index := 0
	for index in range(1, axes.size()):
		if float((axes[index] as Dictionary).get("size", 0.0)) < float((axes[view_index] as Dictionary).get("size", 0.0)):
			view_index = index
	var up_index := -1
	for index in range(axes.size()):
		if index == view_index:
			continue
		if up_index < 0 or float((axes[index] as Dictionary).get("size", 0.0)) > float((axes[up_index] as Dictionary).get("size", 0.0)):
			up_index = index
	var view_axis := (axes[view_index] as Dictionary).get("axis", Vector3.FORWARD) as Vector3
	var up_axis := (axes[up_index] as Dictionary).get("axis", Vector3.UP) as Vector3
	if absf(view_axis.normalized().dot(up_axis.normalized())) > 0.92:
		up_axis = Vector3.UP if absf(view_axis.normalized().dot(Vector3.UP)) < 0.92 else Vector3.FORWARD
	return {
		"view_axis": view_axis.normalized(),
		"up_axis": up_axis.normalized(),
	}


func _painted_pixel_count(image: Image, center: Vector2, radius: int, alpha_threshold: float) -> int:
	if not image:
		return 0
	var min_x := clampi(floori(center.x) - radius, 0, image.get_width() - 1)
	var max_x := clampi(ceili(center.x) + radius, 0, image.get_width() - 1)
	var min_y := clampi(floori(center.y) - radius, 0, image.get_height() - 1)
	var max_y := clampi(ceili(center.y) + radius, 0, image.get_height() - 1)
	var count := 0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if Vector2(float(x), float(y)).distance_to(center) > float(radius):
				continue
			if image.get_pixel(x, y).a >= alpha_threshold:
				count += 1
	return count


func _reset_target_canvas(player: Node, texture_key: String) -> void:
	var canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	player._camouflage_paint_textures[texture_key] = ImageTexture.create_from_image(canvas_image)


func _collect_visible_sample_hits(
	system: CamouflageSystem,
	camera: Camera3D,
	mesh_instance: MeshInstance3D,
	mesh_path: String,
	target_requested_mesh: bool = true
) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if not camera or not mesh_instance:
		return hits
	var max_hit_count := 16
	var aabb := mesh_instance.get_aabb()
	var local_samples := [
		aabb.position + aabb.size * Vector3(0.50, 0.50, 0.50),
		aabb.position + aabb.size * Vector3(0.50, 0.72, 0.50),
		aabb.position + aabb.size * Vector3(0.38, 0.52, 0.50),
		aabb.position + aabb.size * Vector3(0.62, 0.52, 0.50),
		aabb.position + aabb.size * Vector3(0.44, 0.34, 0.50),
		aabb.position + aabb.size * Vector3(0.56, 0.34, 0.50),
	]
	var seen_pixels := {}
	for local_point in local_samples:
		var world_point: Vector3 = mesh_instance.global_transform * local_point
		if camera.is_position_behind(world_point):
			continue
		var screen_point := camera.unproject_position(world_point)
		var hit := _project_sample_screen(system, screen_point, mesh_path, target_requested_mesh)
		_append_unique_sample_hit(hits, seen_pixels, hit)
	var screen_bounds := _screen_bounds_for_mesh_aabb(camera, mesh_instance)
	if screen_bounds.size.x > 8.0 and screen_bounds.size.y > 8.0:
		var grid_columns := 7
		var grid_rows := 7
		for y in range(grid_rows):
			for x in range(grid_columns):
				if hits.size() >= max_hit_count:
					return hits
				var screen_point := Vector2(
					lerpf(screen_bounds.position.x, screen_bounds.position.x + screen_bounds.size.x, (float(x) + 0.5) / float(grid_columns)),
					lerpf(screen_bounds.position.y, screen_bounds.position.y + screen_bounds.size.y, (float(y) + 0.5) / float(grid_rows))
				)
				var hit := _project_sample_screen(system, screen_point, mesh_path, target_requested_mesh)
				_append_unique_sample_hit(hits, seen_pixels, hit)
	return hits


func _project_sample_screen(system: CamouflageSystem, screen_point: Vector2, mesh_path: String, target_requested_mesh: bool) -> Dictionary:
	if target_requested_mesh:
		return system.call("_project_screen_to_body_surface", screen_point, false, mesh_path, 0) as Dictionary
	return system.call("_project_screen_to_body_surface", screen_point, false) as Dictionary


func _reset_drag_path_canvases(player: Node, mesh_path: String, drag_path: Dictionary) -> void:
	var surfaces := {}
	for hit_key in ["start", "end"]:
		var hit := drag_path.get(hit_key, {}) as Dictionary
		if not hit.is_empty():
			surfaces[int(hit.get("surface", 0))] = true
	for path_hit in drag_path.get("path_hits", []):
		var path_hit_dict := path_hit as Dictionary
		if not path_hit_dict.is_empty():
			surfaces[int(path_hit_dict.get("surface", 0))] = true
	for surface in surfaces.keys():
		_reset_target_canvas(player, "%s:%d" % [mesh_path, int(surface)])


func _append_unique_sample_hit(hits: Array[Dictionary], seen_pixels: Dictionary, hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var uv: Vector2 = hit.get("uv", Vector2.ZERO)
	if uv.x < 0.08 or uv.x > 0.92 or uv.y < 0.08 or uv.y > 0.92:
		return false
	var pixel := CamouflageSystem._brush_uv_to_pixel_center(hit.get("uv", Vector2.ZERO))
	var key := "%d:%d" % [pixel.x / 8, pixel.y / 8]
	if seen_pixels.has(key):
		return false
	seen_pixels[key] = true
	hits.append(hit)
	return true


func _screen_bounds_for_mesh_aabb(camera: Camera3D, mesh_instance: MeshInstance3D) -> Rect2:
	var aabb := mesh_instance.get_aabb()
	var min_screen := Vector2(INF, INF)
	var max_screen := Vector2(-INF, -INF)
	for sx in [0.0, 1.0]:
		for sy in [0.0, 1.0]:
			for sz in [0.0, 1.0]:
				var local_corner := aabb.position + aabb.size * Vector3(sx, sy, sz)
				var world_corner: Vector3 = mesh_instance.global_transform * local_corner
				if camera.is_position_behind(world_corner):
					continue
				var screen_corner := camera.unproject_position(world_corner)
				min_screen = Vector2(minf(min_screen.x, screen_corner.x), minf(min_screen.y, screen_corner.y))
				max_screen = Vector2(maxf(max_screen.x, screen_corner.x), maxf(max_screen.y, screen_corner.y))
	if min_screen.x >= INF or min_screen.y >= INF:
		return Rect2()
	return Rect2(min_screen, max_screen - min_screen)


func _find_continuous_drag_path(
	system: CamouflageSystem,
	sample_hits: Array[Dictionary],
	mesh_path: String,
	target_surface: int,
	path_sample_count: int,
	min_screen_distance: float = 0.0
) -> Dictionary:
	var local_offsets := PackedVector2Array([
		Vector2(16.0, 0.0),
		Vector2(-16.0, 0.0),
		Vector2(0.0, 16.0),
		Vector2(0.0, -16.0),
		Vector2(12.0, 0.0),
		Vector2(-12.0, 0.0),
		Vector2(0.0, 12.0),
		Vector2(0.0, -12.0),
		Vector2(24.0, 0.0),
		Vector2(-24.0, 0.0),
		Vector2(0.0, 24.0),
		Vector2(0.0, -24.0),
		Vector2(18.0, 18.0),
		Vector2(-18.0, 18.0),
		Vector2(18.0, -18.0),
		Vector2(-18.0, -18.0),
		Vector2(36.0, 0.0),
		Vector2(-36.0, 0.0),
		Vector2(0.0, 36.0),
		Vector2(0.0, -36.0),
		Vector2(8.0, 0.0),
		Vector2(-8.0, 0.0),
		Vector2(0.0, 8.0),
		Vector2(0.0, -8.0),
	])
	var local_end_hits := 0
	var best_local_path_size := -1
	var best_local_offset := Vector2.ZERO
	var best_local_screen := Vector2.ZERO
	for sample_hit in sample_hits:
		var start_hit := sample_hit as Dictionary
		var start_screen: Vector2 = start_hit.get("screen", Vector2.ZERO)
		for offset in local_offsets:
			if offset.length() < min_screen_distance:
				continue
			var end_screen := start_screen + offset
			var end_hit := system.call("_project_screen_to_body_surface", end_screen, false, mesh_path, target_surface) as Dictionary
			if end_hit.is_empty():
				continue
			local_end_hits += 1
			var path_hits := _collect_drag_path_hits(system, start_hit, end_hit, mesh_path, target_surface, path_sample_count)
			if path_hits.size() > best_local_path_size:
				best_local_path_size = path_hits.size()
				best_local_offset = offset
				best_local_screen = start_screen
			if path_hits.size() >= maxi(2, path_sample_count - 1):
				return {
					"start": start_hit,
					"end": end_hit,
					"path_hits": path_hits,
				}
	for start_index in range(sample_hits.size()):
		var start_hit := sample_hits[start_index] as Dictionary
		var start_screen: Vector2 = start_hit.get("screen", Vector2.ZERO)
		for end_index in range(start_index + 1, sample_hits.size()):
			var end_hit := sample_hits[end_index] as Dictionary
			var end_screen: Vector2 = end_hit.get("screen", Vector2.ZERO)
			if start_screen.distance_to(end_screen) < maxf(18.0, min_screen_distance):
				continue
			var path_hits := _collect_drag_path_hits(system, start_hit, end_hit, mesh_path, target_surface, path_sample_count)
			if path_hits.size() >= maxi(2, path_sample_count - 1):
				return {
					"start": start_hit,
					"end": end_hit,
					"path_hits": path_hits,
				}
	print("[GingerbreadRuntimePerfTest] drag_local_candidates=%d local_end_hits=%d best_local_path_hits=%d offset=%s screen=%s" % [
		sample_hits.size(),
		local_end_hits,
		best_local_path_size,
		str(best_local_offset),
		str(best_local_screen),
	])
	return {}


func _collect_drag_path_hits(
	system: CamouflageSystem,
	start_hit: Dictionary,
	end_hit: Dictionary,
	mesh_path: String,
	target_surface: int,
	sample_count: int
) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var start_screen: Vector2 = start_hit.get("screen", Vector2.ZERO)
	var end_screen: Vector2 = end_hit.get("screen", Vector2.ZERO)
	if sample_count <= 0 or start_screen.distance_squared_to(end_screen) <= 0.25:
		return hits
	for index in range(1, sample_count + 1):
		var t := float(index) / float(sample_count + 1)
		var screen_point := start_screen.lerp(end_screen, t)
		var hit := system.call("_project_screen_to_body_surface", screen_point, false, mesh_path, target_surface) as Dictionary
		if hit.is_empty():
			continue
		hits.append(hit)
	return hits


func _save_brush_precision_preview(player: Node, texture_key: String, system: CamouflageSystem, sample_hits: Array[Dictionary]) -> Error:
	if sample_hits.is_empty():
		return ERR_DOES_NOT_EXIST
	_reset_target_canvas(player, texture_key)
	var colors := [
		Color(0.95, 0.15, 0.08, 1.0),
		Color(0.08, 0.72, 0.95, 1.0),
		Color(0.18, 0.88, 0.28, 1.0),
		Color(0.95, 0.80, 0.10, 1.0),
		Color(0.74, 0.28, 0.95, 1.0),
		Color(0.95, 0.45, 0.12, 1.0),
	]
	for index in range(sample_hits.size()):
		system.brush_color = colors[index % colors.size()]
		system.call("_paint_surface", sample_hits[index], true)
	var preview_texture := player._camouflage_paint_textures.get(texture_key) as Texture2D
	var preview_image := preview_texture.get_image() if preview_texture else null
	if not preview_image:
		return ERR_FILE_CANT_WRITE
	var preview_dir := ProjectSettings.globalize_path("res://asset_working/gingerbread")
	var dir_error := DirAccess.make_dir_recursive_absolute(preview_dir)
	if dir_error != OK:
		return dir_error
	return preview_image.save_png(preview_dir.path_join("brush_precision_preview.png"))


func _save_model_surface_preview() -> void:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name.contains("headless"):
		return
	var viewport := get_viewport()
	if not viewport:
		return
	var image := viewport.get_texture().get_image()
	if not image:
		return
	var preview_dir := ProjectSettings.globalize_path("res://asset_working/gingerbread")
	var dir_error := DirAccess.make_dir_recursive_absolute(preview_dir)
	if dir_error != OK:
		return
	image.save_png(preview_dir.path_join("brush_model_preview.png"))


func _max_alpha_near(image: Image, center: Vector2, radius: int) -> float:
	if not image:
		return 0.0
	var min_x := clampi(floori(center.x) - radius, 0, image.get_width() - 1)
	var max_x := clampi(ceili(center.x) + radius, 0, image.get_width() - 1)
	var min_y := clampi(floori(center.y) - radius, 0, image.get_height() - 1)
	var max_y := clampi(ceili(center.y) + radius, 0, image.get_height() - 1)
	var strongest := 0.0
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			strongest = maxf(strongest, image.get_pixel(x, y).a)
	return strongest


func _paint_alpha_centroid(image: Image, center: Vector2, radius: int) -> Vector2:
	if not image:
		return Vector2(INF, INF)
	var min_x := clampi(floori(center.x) - radius, 0, image.get_width() - 1)
	var max_x := clampi(ceili(center.x) + radius, 0, image.get_width() - 1)
	var min_y := clampi(floori(center.y) - radius, 0, image.get_height() - 1)
	var max_y := clampi(ceili(center.y) + radius, 0, image.get_height() - 1)
	var total_alpha := 0.0
	var weighted := Vector2.ZERO
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var alpha := image.get_pixel(x, y).a
			if alpha <= 0.001:
				continue
			total_alpha += alpha
			weighted += Vector2(float(x), float(y)) * alpha
	if total_alpha <= 0.0001:
		return Vector2(INF, INF)
	return weighted / total_alpha
