extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var player_scene := load("res://scenes/level/player.tscn")
	if not player_scene is PackedScene:
		failures.append("Player scene did not load as PackedScene")
	else:
		var floor := StaticBody3D.new()
		floor.name = "PhysicsTestFloor"
		floor.collision_layer = 2
		floor.collision_mask = 3
		var floor_collision := CollisionShape3D.new()
		var floor_shape := BoxShape3D.new()
		floor_shape.size = Vector3(12.0, 0.2, 12.0)
		floor_collision.shape = floor_shape
		floor_collision.position.y = -0.1
		floor.add_child(floor_collision)
		add_child(floor)
		var wall := StaticBody3D.new()
		wall.name = "PhysicsTestWall"
		wall.collision_layer = 2
		wall.collision_mask = 4
		var wall_collision := CollisionShape3D.new()
		var wall_shape := BoxShape3D.new()
		wall_shape.size = Vector3(0.35, 4.0, 12.0)
		wall_collision.shape = wall_shape
		wall_collision.position = Vector3(4.0, 2.0, 0.0)
		wall.add_child(wall_collision)
		add_child(wall)

		var player := (player_scene as PackedScene).instantiate()
		player.name = "1"
		add_child(player)
		await get_tree().process_frame

		var precision_radii := player.call(
			"_sanitize_camouflage_brush_radii",
			PackedFloat32Array([CamouflageSystem.BRUSH_PRECISION_SAMPLE_MIN_RADIUS]),
			1,
			CamouflageSystem.BRUSH_DEFAULT_RADIUS
		) as PackedFloat32Array
		if precision_radii.is_empty() or absf(precision_radii[0] - CamouflageSystem.BRUSH_PRECISION_SAMPLE_MIN_RADIUS) > 0.001:
			failures.append("Player brush batch sanitization should preserve small precision sample radii for fast accurate dabs")

		var camouflage_palette := [
			Color(0.34, 0.52, 0.31, 1.0),
			Color(0.20, 0.28, 0.18, 1.0),
			Color(0.52, 0.68, 0.42, 1.0),
			Color(0.42, 0.38, 0.28, 1.0),
		]
		var camouflage_texture := CamouflageSystem.create_camouflage_texture(camouflage_palette, 42)
		if not camouflage_texture:
			failures.append("Camouflage texture should be created from an environment palette")
		elif ClassDB.class_exists("DrawableTexture2D") and not camouflage_texture.is_class("DrawableTexture2D"):
			failures.append("Godot 4.7 camouflage texture should use DrawableTexture2D")
		var paint_layer := CamouflageSystem.create_paint_layer_canvas()
		var paint_layer_image := paint_layer.get_image() if paint_layer else null
		if paint_layer_image and paint_layer_image.get_pixel(128, 128).a > 0.01:
			failures.append("Brush paint layer should start transparent so picking a color does not repaint the whole body")
		if paint_layer and paint_layer.is_class("DrawableTexture2D") and bool(paint_layer.call("get_use_mipmaps")):
			failures.append("Dynamic brush paint layers should not generate mipmaps every stroke")
		var edge_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		edge_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var edge_canvas := ImageTexture.create_from_image(edge_canvas_image)
		var edge_painted := CamouflageSystem.paint_brush_on_texture(edge_canvas, Vector2.ZERO, Color(1.0, 0.1, 0.05, 1.0), 24.0, 0.0)
		var edge_painted_image := edge_painted.get_image() if edge_painted else null
		if not edge_painted_image or edge_painted_image.get_pixel(0, 0).a < 0.20:
			failures.append("Brush center should stay under the clicked UV even when clipped by the texture edge")
		var atlas_edge_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		atlas_edge_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var atlas_edge_canvas := ImageTexture.create_from_image(atlas_edge_canvas_image)
		var atlas_edge_uv := Vector2(0.742736, 0.916311)
		var atlas_edge_pixel := CamouflageSystem._brush_uv_to_pixel_center_float(atlas_edge_uv)
		var atlas_edge_painted := CamouflageSystem.paint_brush_on_texture(atlas_edge_canvas, atlas_edge_uv, Color(0.95, 0.26, 0.12, 1.0), CamouflageSystem.BRUSH_MAX_RADIUS, 0.0)
		var atlas_edge_image := atlas_edge_painted.get_image() if atlas_edge_painted else null
		var atlas_edge_centroid := _paint_alpha_centroid(atlas_edge_image, atlas_edge_pixel, 96)
		if not atlas_edge_image or atlas_edge_image.get_pixelv(Vector2i(roundi(atlas_edge_pixel.x), roundi(atlas_edge_pixel.y))).a < 0.80:
			failures.append("Large brush stamps near a UV atlas edge should still color the exact clicked texel")
		elif atlas_edge_centroid.distance_to(atlas_edge_pixel) > 0.45:
			failures.append("Large brush stamps near a UV atlas edge should shrink symmetrically instead of drifting after texture-edge clipping")
		var center_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		center_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var center_canvas := ImageTexture.create_from_image(center_canvas_image)
		var center_uv := Vector2(0.347, 0.681)
		var center_painted := CamouflageSystem.paint_brush_on_texture(center_canvas, center_uv, Color(0.2, 0.9, 0.4, 1.0), 18.0, 0.0)
		var center_painted_image := center_painted.get_image() if center_painted else null
		var center_pixel := Vector2i(
			clampi(roundi(center_uv.x * float(CamouflageSystem.TEXTURE_SIZE - 1)), 0, CamouflageSystem.TEXTURE_SIZE - 1),
			clampi(roundi(center_uv.y * float(CamouflageSystem.TEXTURE_SIZE - 1)), 0, CamouflageSystem.TEXTURE_SIZE - 1)
		)
		if center_painted != center_canvas:
			failures.append("CPU brush fallback should update existing ImageTexture in place to avoid per-stroke texture allocation")
		if not center_painted_image or center_painted_image.get_pixelv(center_pixel).a < 0.70:
			failures.append("Brush texture stamp should put the strongest paint under the clicked UV center")
		elif _painted_pixel_count(center_painted_image, Vector2(center_pixel), 8, 0.35) < 140:
			failures.append("Brush texture stamp should create a continuous painted brush area, not star-like speckles")
		var subpixel_center := Vector2(100.49, 200.49)
		var subpixel_uv := (subpixel_center + Vector2(0.5, 0.5)) / float(CamouflageSystem.TEXTURE_SIZE)
		var subpixel_target := CamouflageSystem._brush_pixel_target_for_uv(subpixel_uv)
		var subpixel_base: Vector2i = subpixel_target.get("base_pixel", Vector2i.ZERO)
		var subpixel_offset: Vector2 = subpixel_target.get("offset", Vector2.ZERO)
		var resolved_subpixel_center := Vector2(subpixel_base) + subpixel_offset
		if resolved_subpixel_center.distance_to(subpixel_center) > 0.13:
			failures.append("Brush UV targeting should preserve sub-texel centers instead of rounding clicks to integer pixels")
		var subpixel_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		subpixel_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var subpixel_canvas := ImageTexture.create_from_image(subpixel_canvas_image)
		var subpixel_painted := CamouflageSystem.paint_brush_on_texture(subpixel_canvas, subpixel_uv, Color(0.1, 0.55, 0.95, 1.0), 18.0, 0.0)
		var subpixel_centroid := _paint_alpha_centroid(subpixel_painted.get_image() if subpixel_painted else null, subpixel_center, 42)
		if subpixel_centroid.distance_to(subpixel_center) > 0.45:
			failures.append("Brush paint footprint should stay centered on the exact sub-texel UV hit")
		if ClassDB.class_exists("DrawableTexture2D"):
			var drawable_center_canvas := CamouflageSystem.create_paint_layer_canvas()
			var drawable_center_painted := CamouflageSystem.paint_brush_on_texture(drawable_center_canvas, center_uv, Color(0.1, 0.7, 0.95, 1.0), 18.0, 0.0)
			if drawable_center_painted != drawable_center_canvas or not drawable_center_painted.is_class("DrawableTexture2D"):
				failures.append("DrawableTexture2D brush path should keep using the fast writable texture without fallback replacement")
			await get_tree().process_frame
			var drawable_center_image := drawable_center_painted.get_image() if drawable_center_painted else null
			var drawable_centroid := _paint_alpha_centroid(drawable_center_image, Vector2(center_pixel), 42)
			var drawable_center_alpha := drawable_center_image.get_pixelv(center_pixel).a if drawable_center_image else 0.0
			var drawable_strongest_pixel := _strongest_alpha_pixel(drawable_center_image, Vector2(center_pixel), 128)
			var drawable_strongest_alpha := drawable_center_image.get_pixelv(Vector2i(int(drawable_strongest_pixel.x), int(drawable_strongest_pixel.y))).a if drawable_center_image and drawable_strongest_pixel.x < INF else 0.0
			if drawable_center_image and drawable_strongest_pixel.x < INF and drawable_center_alpha < 0.60:
				failures.append("DrawableTexture2D brush path should paint the exact clicked UV center alpha=%.3f strongest=%s strongest_alpha=%.3f" % [drawable_center_alpha, str(drawable_strongest_pixel), drawable_strongest_alpha])
			elif drawable_center_image and drawable_strongest_pixel.x < INF and drawable_centroid.distance_to(Vector2(center_pixel)) > 1.0:
				failures.append("DrawableTexture2D brush path should stay centered on the clicked UV instead of drifting during blit")
		var precision_patch := CamouflageSystem._make_rotated_brush_texture(37, Color(0.2, 0.9, 0.4, 1.0), 0.0)
		var precision_patch_image := precision_patch.get_image() if precision_patch else null
		if not precision_patch_image or precision_patch_image.get_size() != Vector2i(37, 37):
			failures.append("Brush stamp texture should use an odd pixel size so the clicked UV has an exact center pixel")
		var sampled_orange := Color(0.84, 0.34, 0.12, 1.0)
		var fidelity_patch := CamouflageSystem._make_rotated_brush_texture(37, sampled_orange, 0.0)
		var fidelity_patch_image := fidelity_patch.get_image() if fidelity_patch else null
		var fidelity_center := fidelity_patch_image.get_pixel(18, 18) if fidelity_patch_image else Color.TRANSPARENT
		if fidelity_center.a < 0.99 or CamouflageSystem._rgb_color_distance(fidelity_center, sampled_orange) > 0.015:
			failures.append("Brush stamp center should preserve the sampled paint color exactly instead of washing it toward the character base color")
		var color_blend_probe := CamouflageSystem.new()
		var screen_orange := Color(0.84, 0.34, 0.12, 1.0)
		var wrong_material_cream := Color(1.0, 0.78, 0.55, 1.0)
		var picked_orange := color_blend_probe.call("_blend_material_and_screen_color", wrong_material_cream, screen_orange) as Color
		if CamouflageSystem._rgb_color_distance(picked_orange, screen_orange) > 0.015:
			failures.append("Screen color picking should keep the visible pixel color when material sampling disagrees strongly")
		var similar_material_orange := Color(0.80, 0.32, 0.10, 1.0)
		var calibrated_orange := color_blend_probe.call("_blend_material_and_screen_color", similar_material_orange, screen_orange) as Color
		if CamouflageSystem._rgb_color_distance(calibrated_orange, screen_orange) > 0.001:
			failures.append("Screen color picking should keep the exact visible pixel color instead of calibrating toward material color")
		var sampled_material := StandardMaterial3D.new()
		sampled_material.albedo_color = Color(0.72, 0.28, 0.12, 1.0)
		sampled_material.roughness = 0.31
		sampled_material.metallic = 0.58
		var sampled_profile := color_blend_probe.call("_material_profile_from_material", sampled_material, Vector2(0.5, 0.5)) as Dictionary
		if not bool(sampled_profile.get("has_response", false)):
			failures.append("Brush color picking should capture source material response in addition to visible color")
		if absf(float(sampled_profile.get("roughness", -1.0)) - 0.31) > 0.001 or absf(float(sampled_profile.get("metallic", -1.0)) - 0.58) > 0.001:
			failures.append("Brush color picking should inherit source roughness and metallic values")
		color_blend_probe.free()
		var cache_key_a := CamouflageSystem._brush_patch_cache_key(18, Color(0.2, 0.9, 0.4, 1.0), 0.001)
		var cache_key_b := CamouflageSystem._brush_patch_cache_key(18, Color(0.2, 0.9, 0.4, 1.0), 0.002)
		if cache_key_a != cache_key_b:
			failures.append("Brush patch cache should quantize tiny angle changes to avoid rebuilding textures every frame")
		var clipped_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		clipped_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var clipped_canvas := ImageTexture.create_from_image(clipped_canvas_image)
		var clipped_uv := Vector2(0.5, 0.5)
		var clipped_triangles := PackedVector2Array([
			clipped_uv,
			clipped_uv + Vector2(0.018, 0.0),
			clipped_uv + Vector2(0.0, 0.018),
		])
		var clipped_painted := CamouflageSystem.paint_brush_strokes_on_texture(
			clipped_canvas,
			PackedVector2Array([clipped_uv]),
			Color(0.95, 0.25, 0.1, 1.0),
			32.0,
			0.0,
			PackedFloat32Array([32.0]),
			clipped_triangles,
			PackedInt32Array([1])
		)
		var clipped_image := clipped_painted.get_image() if clipped_painted else null
		var clipped_center_pixel := Vector2i(
			clampi(roundi(clipped_uv.x * float(CamouflageSystem.TEXTURE_SIZE - 1)), 0, CamouflageSystem.TEXTURE_SIZE - 1),
			clampi(roundi(clipped_uv.y * float(CamouflageSystem.TEXTURE_SIZE - 1)), 0, CamouflageSystem.TEXTURE_SIZE - 1)
		)
		var clipped_outside_pixel := clipped_center_pixel + Vector2i(12, 12)
		if not clipped_image or clipped_image.get_pixelv(clipped_center_pixel).a < 0.70:
			failures.append("Triangle-clipped brush stamp should still paint the exact clicked UV center")
		elif clipped_image.get_pixelv(clipped_outside_pixel).a > 0.05:
			failures.append("Triangle-clipped brush stamp should not bleed onto nearby unrelated UV island pixels")
		var large_clipped_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		large_clipped_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var large_clipped_canvas := ImageTexture.create_from_image(large_clipped_canvas_image)
		var large_clipped_painted := CamouflageSystem.paint_brush_strokes_on_texture(
			large_clipped_canvas,
			PackedVector2Array([clipped_uv]),
			Color(0.95, 0.9, 0.1, 1.0),
			96.0,
			0.0,
			PackedFloat32Array([96.0]),
			clipped_triangles,
			PackedInt32Array([1])
		)
		var large_clipped_image := large_clipped_painted.get_image() if large_clipped_painted else null
		var large_clipped_outside_pixel := clipped_center_pixel + Vector2i(50, 50)
		if not large_clipped_image or large_clipped_image.get_pixelv(clipped_center_pixel).a < 0.70:
			failures.append("Large triangle-clipped brush stamp should still paint the exact clicked UV center")
		elif large_clipped_image.get_pixelv(large_clipped_outside_pixel).a > 0.05:
			failures.append("Large brush stamps should stay clipped to the hit UV island instead of painting unrelated texture areas")
		if ClassDB.class_exists("DrawableTexture2D"):
			var drawable_clipped_canvas := CamouflageSystem.create_paint_layer_canvas()
			var drawable_clipped_painted := CamouflageSystem.paint_brush_strokes_on_texture(
				drawable_clipped_canvas,
				PackedVector2Array([clipped_uv]),
				Color(0.95, 0.55, 0.1, 1.0),
				96.0,
				0.0,
				PackedFloat32Array([96.0]),
				clipped_triangles,
				PackedInt32Array([1])
			)
			if drawable_clipped_painted != drawable_clipped_canvas or not drawable_clipped_painted.is_class("DrawableTexture2D"):
				failures.append("DrawableTexture2D clipped brush path should keep using the fast writable texture without fallback replacement")
		var connected_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		connected_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var connected_canvas := ImageTexture.create_from_image(connected_canvas_image)
		var connected_triangles := PackedVector2Array([
			clipped_uv,
			clipped_uv + Vector2(0.018, 0.0),
			clipped_uv + Vector2(0.0, 0.018),
			clipped_uv + Vector2(0.018, 0.0),
			clipped_uv + Vector2(0.018, 0.018),
			clipped_uv + Vector2(0.0, 0.018),
		])
		var connected_painted := CamouflageSystem.paint_brush_strokes_on_texture(
			connected_canvas,
			PackedVector2Array([clipped_uv]),
			Color(0.2, 0.85, 0.95, 1.0),
			32.0,
			0.0,
			PackedFloat32Array([32.0]),
			connected_triangles,
			PackedInt32Array([2])
		)
		var connected_image := connected_painted.get_image() if connected_painted else null
		var connected_inside_pixel := clipped_center_pixel + Vector2i(12, 12)
		var connected_outside_pixel := clipped_center_pixel + Vector2i(24, 0)
		if not connected_image or connected_image.get_pixelv(connected_inside_pixel).a < 0.05:
			failures.append("Brush triangle clipping should preserve paint across connected UV-neighbor triangles")
		elif connected_image.get_pixelv(connected_outside_pixel).a > 0.05:
			failures.append("Brush triangle clipping should still reject nearby pixels outside the connected UV footprint")
		var clip_offsets := CamouflageSystem._uv_clip_offsets_for_counts(PackedInt32Array([1, 2, 0]), 9, 3)
		if clip_offsets != PackedInt32Array([0, 3, 9]):
			failures.append("Brush UV clip offsets should be precomputed once per paint batch")
		var invalid_clip_offsets := CamouflageSystem._uv_clip_offsets_for_counts(PackedInt32Array([1, 2]), 12, 2)
		if not invalid_clip_offsets.is_empty():
			failures.append("Brush UV clip offset validation should reject mismatched triangle payloads")
		var estimated_texture_radius := CamouflageSystem._estimate_texture_radius_from_triangle(
			0.25,
			Vector3.ZERO,
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
			Vector2.ZERO,
			Vector2(0.5, 0.0),
			Vector2(0.0, 0.5)
		)
		if absf(estimated_texture_radius - 128.0) > 2.0:
			failures.append("Brush texture radius should follow the hit triangle UV density")
		var stretched_texture_radius := CamouflageSystem._estimate_texture_radius_from_triangle(
			0.10,
			Vector3.ZERO,
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
			Vector2.ZERO,
			Vector2(0.90, 0.0),
			Vector2(0.0, 0.10)
		)
		if stretched_texture_radius < 88.0:
			failures.append("Brush texture radius should use the strongest local UV stretch so the visible world-space brush footprint stays covered")
		var degenerate_metric := CamouflageSystem._uv_footprint_metric_from_triangle(
			0.10,
			Vector3.ZERO,
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
			Vector2(0.5, 0.5),
			Vector2(0.5, 0.5),
			Vector2(0.5, 0.5)
		)
		if not degenerate_metric.is_empty():
			failures.append("Degenerate UV triangles should not produce invalid anisotropic brush footprint metrics")
		var fallback_metric := CamouflageSystem._fallback_uv_footprint_metric(48.0)
		if fallback_metric.size() != 3 or fallback_metric[0] <= 0.0 or fallback_metric[2] <= 0.0:
			failures.append("Degenerate UV brush hits should have a stable isotropic footprint metric fallback")
		var footprint_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		footprint_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var footprint_canvas := ImageTexture.create_from_image(footprint_canvas_image)
		var footprint_uv := Vector2(0.5, 0.5)
		var footprint_metrics := PackedFloat32Array([10000.0, 0.0, 156.25])
		var footprint_painted := CamouflageSystem.paint_brush_strokes_on_texture(
			footprint_canvas,
			PackedVector2Array([footprint_uv]),
			Color(0.95, 0.15, 0.8, 1.0),
			80.0,
			0.0,
			PackedFloat32Array([80.0]),
			PackedVector2Array(),
			PackedInt32Array(),
			footprint_metrics
		)
		var footprint_image := footprint_painted.get_image() if footprint_painted else null
		var footprint_center_pixel := CamouflageSystem._brush_uv_to_pixel_center(footprint_uv)
		var footprint_rejected_pixel := footprint_center_pixel + Vector2i(30, 0)
		var footprint_accepted_pixel := footprint_center_pixel + Vector2i(0, 30)
		if not footprint_image or footprint_image.get_pixelv(footprint_center_pixel).a < 0.70:
			failures.append("Brush UV footprint mask should keep the exact hit center painted")
		elif footprint_image.get_pixelv(footprint_rejected_pixel).a > 0.05 or footprint_image.get_pixelv(footprint_accepted_pixel).a < 0.05:
			failures.append("Brush UV footprint mask should turn anisotropic UV stretch into a precise surface-space brush footprint")
		elif _painted_pixel_count(footprint_image, Vector2(footprint_center_pixel), 16, 0.08) < 150:
			failures.append("Brush UV footprint mask should preserve a continuous painted area instead of isolated dots")
		var footprint_bounds := CamouflageSystem._uv_footprint_pixel_bounds(
			footprint_uv,
			footprint_metrics,
			Rect2i(Vector2i.ZERO, Vector2i(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE)),
			int(ceil(CamouflageSystem.BRUSH_UV_TRIANGLE_CLIP_MARGIN_PIXELS))
		)
		if footprint_bounds.size.x <= 0 or footprint_bounds.size.y <= 0 or footprint_bounds.size.x >= footprint_bounds.size.y or footprint_bounds.size.x > 48:
			failures.append("Brush UV footprint mask should bound the CPU paint loop to the anisotropic surface footprint")
		var variable_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		variable_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var variable_canvas := ImageTexture.create_from_image(variable_canvas_image)
		var variable_uvs := PackedVector2Array([Vector2(0.20, 0.20), Vector2(0.70, 0.20)])
		var variable_radii := PackedFloat32Array([8.0, 32.0])
		var variable_painted := CamouflageSystem.paint_brush_strokes_on_texture(variable_canvas, variable_uvs, Color(0.8, 0.2, 0.1, 1.0), 8.0, 0.0, variable_radii)
		var variable_image := variable_painted.get_image() if variable_painted else null
		var small_probe_pixel := Vector2i(
			clampi(roundi(variable_uvs[0].x * float(CamouflageSystem.TEXTURE_SIZE - 1)) + 24, 0, CamouflageSystem.TEXTURE_SIZE - 1),
			clampi(roundi(variable_uvs[0].y * float(CamouflageSystem.TEXTURE_SIZE - 1)), 0, CamouflageSystem.TEXTURE_SIZE - 1)
		)
		var large_probe_pixel := Vector2i(
			clampi(roundi(variable_uvs[1].x * float(CamouflageSystem.TEXTURE_SIZE - 1)) + 24, 0, CamouflageSystem.TEXTURE_SIZE - 1),
			clampi(roundi(variable_uvs[1].y * float(CamouflageSystem.TEXTURE_SIZE - 1)), 0, CamouflageSystem.TEXTURE_SIZE - 1)
		)
		if not variable_image or variable_image.get_pixelv(small_probe_pixel).a > 0.05 or variable_image.get_pixelv(large_probe_pixel).a < 0.20:
			failures.append("Brush stroke batches should support per-stamp texture radii")
		player._apply_camouflage_palette(camouflage_palette, 0.86)
		await get_tree().process_frame
		var camo_mesh := player.get_node_or_null("3DGodotRobot/RobotArmature/Skeleton3D/Chest") as MeshInstance3D
		var camo_material := camo_mesh.get_surface_override_material(0) if camo_mesh else null
		if not camo_material is StandardMaterial3D or not (camo_material as StandardMaterial3D).albedo_texture:
			failures.append("Camouflage palette should be applied to the player body material")
		player._start_camouflage_brush_visual(Color(0.18, 0.34, 0.22, 1.0))
		player._apply_camouflage_brush_stroke(Vector2(0.48, 0.42), Color(0.74, 0.62, 0.38, 1.0), 20.0, 0.4)
		player._apply_camouflage_brush_stroke(
			Vector2(0.48, 0.42),
			Color(0.74, 0.62, 0.38, 1.0),
			20.0,
			0.4,
			player.global_position + Vector3(0.0, 1.2, 0.0),
			Vector3.FORWARD,
			"3DGodotRobot/RobotArmature/Skeleton3D/Chest",
			0
		)
		await get_tree().process_frame
		camo_material = camo_mesh.get_surface_override_material(0) if camo_mesh else null
		if not camo_material is ShaderMaterial:
			failures.append("Brush camouflage strokes should keep an editable body texture applied")
		elif not (camo_material as ShaderMaterial).get_shader_parameter("paint_texture") is Texture2D:
			failures.append("Brush camouflage strokes should apply an editable paint layer texture")
		elif (camo_material as ShaderMaterial).get_meta("camouflage_bound_paint_texture", null) != (camo_material as ShaderMaterial).get_shader_parameter("paint_texture"):
			failures.append("Brush paint-layer material should cache the currently bound paint texture to avoid redundant shader parameter writes")
		elif absf(float((camo_material as ShaderMaterial).get_meta("camouflage_bound_paint_strength", -1.0)) - 1.0) > 0.001:
			failures.append("Brush paint-layer material should cache the current display strength")
		if camo_material is ShaderMaterial:
			var paint_layer_material := camo_material as ShaderMaterial
			if bool(paint_layer_material.get_shader_parameter("paint_exact_color_match")):
				failures.append("Brush paint-layer shader should default to LIT material response mode")
			player.set_camouflage_paint_material_controls(false, 0.35, 0.45)
			if bool(paint_layer_material.get_shader_parameter("paint_exact_color_match")):
				failures.append("Brush paint material controls should keep LIT response mode when requested")
			if absf(float(paint_layer_material.get_shader_parameter("paint_roughness")) - 0.35) > 0.001:
				failures.append("Brush paint material controls should update shader roughness")
			if absf(float(paint_layer_material.get_shader_parameter("paint_metallic")) - 0.45) > 0.001:
				failures.append("Brush paint material controls should update shader metallic")
			player.set_camouflage_paint_material_controls(false, 1.0, 0.0)
		if player._camouflage_paint_textures.is_empty():
			failures.append("Brush camouflage strokes should paint the targeted body surface texture")
		player.set_camouflage_brush_locked(true)
		if not player.is_camouflage_brushing():
			failures.append("Brush camouflage mode should expose movement lock state")
		var orbit_before: float = player.get_node("SpringArmOffset").rotation.y
		player.adjust_camouflage_camera_orbit(Vector2(80.0, 0.0))
		if absf(angle_difference(orbit_before, player.get_node("SpringArmOffset").rotation.y)) < 0.2:
			failures.append("Middle mouse brush orbit should rotate the camera around the locked player")
		var spring_controller := player.get_node("SpringArmOffset")
		player.adjust_camouflage_camera_zoom(-20.0)
		var brush_zoom_length := float(spring_controller.get("_target_spring_length"))
		if brush_zoom_length >= SpringArmCharacter.CAMERA_ZOOM_MIN or absf(brush_zoom_length - SpringArmCharacter.CAMOUFLAGE_CAMERA_ZOOM_MIN) > 0.001:
			failures.append("Mouse wheel brush zoom should use the close-up camouflage camera range")
		player.set_camouflage_brush_locked(false)
		if player.is_camouflage_brushing():
			failures.append("Brush camouflage mode should release movement lock state")

		var primitive_probe := CamouflageSystem.new()
		var plane_arrays := primitive_probe.call("_get_mesh_surface_arrays", PlaneMesh.new(), 0) as Array
		if plane_arrays.is_empty() or not plane_arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			failures.append("Brush projection should read PrimitiveMesh arrays without ArrayMesh surface calls")
		var hud_probe := CamouflageHUD.new()
		add_child(hud_probe)
		hud_probe.set_skill_active(true, true, Color(0.2, 0.4, 0.9, 1.0), 18.0, 0.0)
		hud_probe.set_preparing_surface()
		if hud_probe._status != CamouflageHUD.STATUS_PREPARING:
			failures.append("Brush HUD should show a non-error preparing state while exact paint cache warms up")
		var hud_status_font := hud_probe.call("_get_status_font") as Font
		var hud_value_font := hud_probe.call("_get_value_font") as Font
		if not hud_status_font or hud_status_font.resource_path != CamouflageHUD.LOBBY_HUD_STATUS_FONT_PATH:
			failures.append("Brush HUD should reuse the lobby status font")
		if not hud_value_font or hud_value_font.resource_path != CamouflageHUD.LOBBY_HUD_VALUE_FONT_PATH:
			failures.append("Brush HUD should reuse the lobby value font")
		if CamouflageHUD.LOBBY_HUD_ITALIC_SKEW > -0.05:
			failures.append("Brush HUD primary text should stay italicized")
		if CamouflageHUD.STATUS_ACTIVE.find("F") >= 0:
			failures.append("Brush HUD should tell players to click for color picking instead of pressing F")
		if bool(hud_probe.get("_exact_color_match")):
			failures.append("Brush HUD should default to LIT material response mode")
		hud_probe.set_material_controls(false, 0.35, 0.45)
		if bool(hud_probe.get("_exact_color_match")) or absf(float(hud_probe.get("_paint_roughness")) - 0.35) > 0.001 or absf(float(hud_probe.get("_paint_metallic")) - 0.45) > 0.001:
			failures.append("Brush HUD should display material color-match controls")
		if CamouflageHUD.STATUS_CONTROL_CAPTION.find("Z/X") < 0 or CamouflageHUD.STATUS_CONTROL_CAPTION.find("F/G") < 0 or CamouflageHUD.STATUS_CAPTION_FONT_SIZE < 12:
			failures.append("Brush HUD should caption roughness and metallic shortcut controls")
		if CamouflageHUD.STATUS_FONT_SIZE < 24 or CamouflageHUD.STATUS_VALUE_FONT_SIZE < 34 or CamouflageHUD.STATUS_MIN_SIZE.x < 500.0 or CamouflageHUD.STATUS_MIN_SIZE.y < 126.0:
			failures.append("Brush HUD status panel should stay large enough for readable paint feedback")
		if CamouflageHUD.CROSSHAIR_LINE_WIDTH < 3.0 or CamouflageHUD.CROSSHAIR_OUTLINE_WIDTH < 6.0:
			failures.append("Brush HUD crosshair should stay visibly thick while aiming")
		if CamouflageHUD.STATUS_PANEL_CUT < 10.0 or CamouflageHUD.STATUS_PANEL_DEPTH.length() < 7.0:
			failures.append("Brush HUD color panel should keep a beveled sci-fi 3D silhouette")
		if CamouflageHUD.STATUS_PANEL_ICON_SIZE < 48.0 or CamouflageHUD.STATUS_PANEL_METER_SEGMENTS < 12:
			failures.append("Brush HUD color panel should keep its hero-style emblem and segmented brush meter")
		hud_probe.set_brush_surface(Vector2(128.0, 96.0), false)
		if not bool(hud_probe.call("_should_draw_crosshair")):
			failures.append("Brush HUD crosshair should be visible while aiming off the body")
		hud_probe.set_brush_surface(Vector2(128.0, 96.0), true)
		if bool(hud_probe.call("_should_draw_crosshair")):
			failures.append("Brush HUD crosshair should disappear once it is over the player body")
		hud_probe.queue_free()
		var plane_probe := MeshInstance3D.new()
		plane_probe.mesh = PlaneMesh.new()
		add_child(plane_probe)
		var plane_hit := primitive_probe.call(
			"_intersect_mesh_triangles",
			plane_probe,
			"PlaneProbe",
			Vector3(0.0, 1.0, 0.0),
			Vector3.DOWN
		) as Dictionary
		if plane_hit.is_empty():
			failures.append("Brush projection should ray-hit PrimitiveMesh through cached TriangleMesh data")
		plane_probe.queue_free()

		var exact_mesh := ArrayMesh.new()
		var exact_arrays := []
		exact_arrays.resize(Mesh.ARRAY_MAX)
		var exact_vertices := PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
		])
		var exact_uvs := PackedVector2Array([
			Vector2(0.10, 0.20),
			Vector2(0.90, 0.20),
			Vector2(0.10, 0.80),
		])
		exact_arrays[Mesh.ARRAY_VERTEX] = exact_vertices
		exact_arrays[Mesh.ARRAY_TEX_UV] = exact_uvs
		exact_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		exact_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, exact_arrays)
		var exact_probe := MeshInstance3D.new()
		exact_probe.mesh = exact_mesh
		add_child(exact_probe)
		var barycentric_point := exact_vertices[0] * 0.20 + exact_vertices[1] * 0.30 + exact_vertices[2] * 0.50
		var exact_hit := primitive_probe.call(
			"_intersect_mesh_triangles",
			exact_probe,
			"ExactProbe",
			barycentric_point + Vector3(0.0, 0.0, 1.0),
			Vector3(0.0, 0.0, -1.0)
		) as Dictionary
		var expected_exact_uv := exact_uvs[0] * 0.20 + exact_uvs[1] * 0.30 + exact_uvs[2] * 0.50
		var actual_exact_uv: Vector2 = exact_hit.get("uv", Vector2(-1.0, -1.0))
		if exact_hit.is_empty() or actual_exact_uv.distance_to(expected_exact_uv) > 0.005:
			failures.append("Brush projection should return exact triangle barycentric UVs")
		if int(exact_hit.get("face_index", -1)) != 0:
			failures.append("Brush projection should preserve the exact hit face index for local surface painting")
		var exact_barycentric: Vector3 = exact_hit.get("barycentric", Vector3.ZERO)
		if exact_barycentric.distance_to(Vector3(0.20, 0.30, 0.50)) > 0.005:
			failures.append("Brush projection should preserve hit barycentric weights for precision painting")
		if exact_hit.get("face_uv0", Vector2.ZERO) != exact_uvs[0] or exact_hit.get("face_uv1", Vector2.ZERO) != exact_uvs[1] or exact_hit.get("face_uv2", Vector2.ZERO) != exact_uvs[2]:
			failures.append("Brush projection should preserve hit face UV corners for UV seam-aware painting")
		var exact_hit_data := primitive_probe.call("_get_mesh_surface_hit_data", exact_mesh, 0) as Dictionary
		if int(exact_hit_data.get("triangle_count", 0)) != 1:
			failures.append("Brush hit cache should keep the full exact triangle set without sampling")
		if not bool(primitive_probe.call("_should_prewarm_surface", exact_mesh, 0)):
			failures.append("Small paint meshes should still be warmed up for immediate brush response")
		var stretched_mesh := ArrayMesh.new()
		var stretched_arrays := []
		stretched_arrays.resize(Mesh.ARRAY_MAX)
		stretched_arrays[Mesh.ARRAY_VERTEX] = exact_vertices
		stretched_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2.ZERO,
			Vector2(0.90, 0.0),
			Vector2(0.0, 0.10),
		])
		stretched_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		stretched_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stretched_arrays)
		var stretched_probe := TextureRadiusProjectionProbe.new()
		stretched_probe.mesh = stretched_mesh
		add_child(stretched_probe)
		var previous_primitive_brush_radius: float = primitive_probe.brush_radius
		primitive_probe.brush_radius = 102.4
		var stretched_hit := primitive_probe.call(
			"_intersect_mesh_triangles",
			stretched_probe,
			"StretchedProbe",
			Vector3(0.25, 0.25, 1.0),
			Vector3(0.0, 0.0, -1.0)
		) as Dictionary
		primitive_probe.brush_radius = previous_primitive_brush_radius
		if float(stretched_hit.get("texture_radius", 0.0)) < 88.0:
			failures.append("Brush projection should carry the local UV stretch into each precise surface hit")
		var stretched_metric: PackedFloat32Array = stretched_hit.get("uv_footprint_metric", PackedFloat32Array())
		if stretched_metric.size() != 3 or stretched_metric[2] <= stretched_metric[0]:
			failures.append("Brush projection should include anisotropic UV footprint metrics for precise surface-space masking")
		stretched_probe.queue_free()
		var scaled_mesh := ArrayMesh.new()
		var far_surface_arrays := []
		far_surface_arrays.resize(Mesh.ARRAY_MAX)
		far_surface_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-0.5, -0.5, 0.0),
			Vector3(0.5, -0.5, 0.0),
			Vector3(-0.5, 0.5, 0.0),
		])
		far_surface_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0.05, 0.05),
			Vector2(0.15, 0.05),
			Vector2(0.05, 0.15),
		])
		far_surface_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		scaled_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, far_surface_arrays)
		var near_surface_arrays := []
		near_surface_arrays.resize(Mesh.ARRAY_MAX)
		near_surface_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
			Vector3(-0.5, -0.5, 0.5),
			Vector3(0.5, -0.5, 0.5),
			Vector3(-0.5, 0.5, 0.5),
		])
		near_surface_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0.75, 0.75),
			Vector2(0.85, 0.75),
			Vector2(0.75, 0.85),
		])
		near_surface_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		scaled_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, near_surface_arrays)
		var scaled_probe := MeshInstance3D.new()
		scaled_probe.mesh = scaled_mesh
		scaled_probe.scale = Vector3(1.0, 1.0, 0.25)
		add_child(scaled_probe)
		var scaled_hit := primitive_probe.call(
			"_intersect_mesh_triangles",
			scaled_probe,
			"ScaledProbe",
			Vector3(0.0, 0.0, 1.0),
			Vector3(0.0, 0.0, -1.0)
		) as Dictionary
		if int(scaled_hit.get("surface", -1)) != 1:
			failures.append("Brush projection should choose the closest hit by world-space distance on scaled meshes")
		scaled_probe.queue_free()
		var connected_mesh := ArrayMesh.new()
		var connected_arrays := []
		connected_arrays.resize(Mesh.ARRAY_MAX)
		var connected_vertices := PackedVector3Array([
			Vector3(0.0, 0.0, 0.0),
			Vector3(1.0, 0.0, 0.0),
			Vector3(0.0, 1.0, 0.0),
			Vector3(1.0, 1.0, 0.0),
		])
		var connected_uv_base := Vector2(0.44, 0.44)
		var connected_uvs := PackedVector2Array([
			connected_uv_base,
			connected_uv_base + Vector2(0.02, 0.0),
			connected_uv_base + Vector2(0.0, 0.02),
			connected_uv_base + Vector2(0.02, 0.02),
		])
		connected_arrays[Mesh.ARRAY_VERTEX] = connected_vertices
		connected_arrays[Mesh.ARRAY_TEX_UV] = connected_uvs
		connected_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
		connected_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, connected_arrays)
		var connected_hit_data := primitive_probe.call("_get_mesh_surface_hit_data", connected_mesh, 0) as Dictionary
		var connected_clip := primitive_probe.call(
			"_collect_uv_clip_triangles_for_brush",
			connected_hit_data,
			0,
			connected_uv_base + Vector2(0.008, 0.008),
			32.0
		) as PackedVector2Array
		if not connected_clip.is_empty():
			failures.append("Brush UV triangle clipping should stay disabled by default; soft brush stamping avoids triangle-shaped paint artifacts")
		if CamouflageSystem.BRUSH_USE_UV_FOOTPRINT_MASK:
			failures.append("Brush UV footprint masks should stay disabled by default so curved body areas receive continuous brush stamps")
		var skinned_root := Node3D.new()
		skinned_root.name = "SkinnedProbeRoot"
		add_child(skinned_root)
		var skinned_skeleton := Skeleton3D.new()
		skinned_skeleton.name = "Skeleton3D"
		skinned_skeleton.add_bone("Root")
		skinned_skeleton.set_bone_rest(0, Transform3D.IDENTITY)
		skinned_skeleton.set_bone_pose_position(0, Vector3(0.35, 0.0, 0.0))
		skinned_root.add_child(skinned_skeleton)
		var skinned_mesh := ArrayMesh.new()
		var skinned_arrays := []
		skinned_arrays.resize(Mesh.ARRAY_MAX)
		skinned_arrays[Mesh.ARRAY_VERTEX] = exact_vertices
		skinned_arrays[Mesh.ARRAY_TEX_UV] = exact_uvs
		skinned_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		skinned_arrays[Mesh.ARRAY_BONES] = PackedInt32Array([
			0, 0, 0, 0,
			0, 0, 0, 0,
			0, 0, 0, 0,
		])
		skinned_arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([
			1.0, 0.0, 0.0, 0.0,
			1.0, 0.0, 0.0, 0.0,
			1.0, 0.0, 0.0, 0.0,
		])
		skinned_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, skinned_arrays)
		var skin := Skin.new()
		skin.set_bind_count(1)
		skin.set_bind_bone(0, 0)
		skin.set_bind_name(0, "Root")
		skin.set_bind_pose(0, Transform3D.IDENTITY)
		var skinned_probe := MeshInstance3D.new()
		skinned_probe.name = "SkinnedPaintMesh"
		skinned_probe.mesh = skinned_mesh
		skinned_probe.skin = skin
		skinned_probe.skeleton = NodePath("..")
		skinned_skeleton.add_child(skinned_probe)
		skinned_skeleton.force_update_all_bone_transforms()
		var skinned_visual_point := barycentric_point + Vector3(0.35, 0.0, 0.0)
		var skinned_hit := primitive_probe.call(
			"_intersect_mesh_triangles",
			skinned_probe,
			"SkinnedProbe",
			skinned_visual_point + Vector3(0.0, 0.0, 1.0),
			Vector3(0.0, 0.0, -1.0)
		) as Dictionary
		var skinned_uv: Vector2 = skinned_hit.get("uv", Vector2(-1.0, -1.0))
		if skinned_hit.is_empty() or skinned_uv.distance_to(expected_exact_uv) > 0.005:
			failures.append("Skinned brush projection should ray-hit the current skeleton pose, not the rest mesh")
		var initial_pose_generation := primitive_probe._pose_hit_cache_generation
		skinned_skeleton.set_bone_pose_position(0, Vector3(1.35, 0.0, 0.0))
		skinned_skeleton.force_update_all_bone_transforms()
		var moved_skinned_visual_point := barycentric_point + Vector3(1.35, 0.0, 0.0)
		var moved_skinned_hit := primitive_probe.call(
			"_intersect_mesh_triangles",
			skinned_probe,
			"SkinnedProbeMoved",
			moved_skinned_visual_point + Vector3(0.0, 0.0, 1.0),
			Vector3(0.0, 0.0, -1.0)
		) as Dictionary
		var moved_skinned_uv: Vector2 = moved_skinned_hit.get("uv", Vector2(-1.0, -1.0))
		if moved_skinned_hit.is_empty() or moved_skinned_uv.distance_to(expected_exact_uv) > 0.005:
			failures.append("Skinned brush projection should invalidate stale posed hit caches when bones move")
		if primitive_probe._pose_hit_cache_generation <= initial_pose_generation:
			failures.append("Skinned brush hit cache generation should advance when the skeleton pose signature changes")
		skinned_skeleton.set_bone_pose_position(0, Vector3(0.35, 0.0, 0.0))
		skinned_skeleton.force_update_all_bone_transforms()
		var skinned_async_probe := CamouflageSystem.new()
		var skinned_async_initial := skinned_async_probe.call("_get_mesh_instance_surface_hit_data", skinned_probe, 0, false) as Dictionary
		if not skinned_async_initial.is_empty():
			failures.append("Async skinned brush hit cache warmup should not synchronously block for new posed surfaces")
		if not bool(skinned_async_probe.call("_has_pending_mesh_hit_jobs")):
			failures.append("Async skinned brush hit cache warmup should leave a pending background job")
		var skinned_async_hit := {}
		for _attempt in range(20):
			skinned_async_probe.call("_finalize_mesh_hit_cache_jobs")
			skinned_async_hit = skinned_async_probe.call(
				"_intersect_mesh_triangles",
				skinned_probe,
				"SkinnedProbeAsync",
				skinned_visual_point + Vector3(0.0, 0.0, 1.0),
				Vector3(0.0, 0.0, -1.0),
				true
			) as Dictionary
			if not skinned_async_hit.is_empty():
				break
			await get_tree().process_frame
		if skinned_async_hit.is_empty():
			failures.append("Async skinned brush hit cache should eventually hit the current skeleton pose")
		skinned_async_probe.free()
		var skinned_warmup_probe := WarmupTargetProbe.new()
		skinned_warmup_probe.target_mesh = skinned_probe
		skinned_warmup_probe.call("_request_paintable_mesh_cache_warmup")
		if not bool(skinned_warmup_probe.call("_has_pending_mesh_hit_jobs")):
			failures.append("Brush color-pick warmup should start async hit cache jobs for skinned paint meshes")
		for _warmup_attempt in range(20):
			skinned_warmup_probe.call("_finalize_mesh_hit_cache_jobs")
			if not bool(skinned_warmup_probe.call("_has_pending_mesh_hit_jobs")):
				break
			await get_tree().process_frame
		if bool(skinned_warmup_probe.call("_has_pending_mesh_hit_jobs")):
			failures.append("Brush color-pick warmup skinned hit cache job should finish without blocking the main thread")
		skinned_warmup_probe.free()
		skinned_root.queue_free()
		var async_probe := CamouflageSystem.new()
		var async_initial := async_probe.call("_get_mesh_surface_hit_data", exact_mesh, 0, false) as Dictionary
		if not async_initial.is_empty():
			failures.append("Async brush hit cache warmup should not synchronously block for new surfaces")
		var async_hit := {}
		for _attempt in range(20):
			async_probe.call("_finalize_mesh_hit_cache_jobs")
			async_hit = async_probe.call(
				"_intersect_mesh_triangles",
				exact_probe,
				"ExactProbeAsync",
				barycentric_point + Vector3(0.0, 0.0, 1.0),
				Vector3(0.0, 0.0, -1.0),
				true
			) as Dictionary
			if not async_hit.is_empty():
				break
			await get_tree().process_frame
		if async_hit.is_empty():
			failures.append("Async brush hit cache warmup should eventually provide exact triangle hits")
		async_probe.free()
		exact_probe.queue_free()
		primitive_probe.free()

		player.set_character_model("gingerbread")
		await get_tree().process_frame
		await get_tree().process_frame
		var ginger_root := player.get_node_or_null("3DGodotRobot/CustomCharacterSkin")
		var ginger_mesh := _find_first_mesh(ginger_root)
		if not ginger_mesh:
			failures.append("Gingerbread skin should expose a paintable mesh")
		else:
			if CharacterSkinCatalog.scene_path_for("gingerbread") != "res://assets/characters/gingerbread/gingerbread_animated_skin.tscn":
				failures.append("Gingerbread should use the runtime skin wrapper scene")
			var ginger_animation_player := _find_first_animation_player(ginger_root)
			if ginger_animation_player:
				var ginger_animation_speed := ginger_animation_player.speed_scale
				player.set_camouflage_brush_locked(true)
				if ginger_animation_player.speed_scale != 0.0:
					failures.append("Brush mode should pause animated skins so exact paint hit caches stay aligned")
				player.set_camouflage_brush_locked(false)
				if absf(ginger_animation_player.speed_scale - ginger_animation_speed) > 0.001:
					failures.append("Brush mode should restore animated skin playback speed after painting")
			elif not ginger_root.has_method("set_animation_paused"):
				failures.append("Gingerbread skin should expose a pause hook for brush pose locking when no AnimationPlayer is present")
			if absf(player.call("_sanitize_camouflage_brush_radius", 140.0) - 140.0) > 0.001:
				failures.append("Brush radius sanitization should preserve large brush sizes instead of clamping to the old 64px limit")
			var camouflage_system := CamouflageSystem.new()
			camouflage_system.camouflage_owner = player
			var ginger_triangle_count := int(camouflage_system.call("_get_mesh_surface_triangle_count_estimate", ginger_mesh.mesh, 0))
			if ginger_triangle_count <= 0 or ginger_triangle_count > 8000:
				failures.append("Rigged 6K Meshy gingerbread should stay near the requested 6K paint runtime budget; got %d triangles" % ginger_triangle_count)
			if not bool(camouflage_system.call("_should_prewarm_surface", ginger_mesh.mesh, 0)):
				failures.append("Rigged 6K Meshy gingerbread should be eligible for on-demand exact hit cache")
			camouflage_system.activate_skill()
			camouflage_system.has_sampled_color = false
			camouflage_system.call("_process", 0.016)
			var ginger_activation_metrics := camouflage_system.get_performance_metrics()
			if int(ginger_activation_metrics.get("surface_projection_calls", 0)) != 0:
				failures.append("Rigged 6K Meshy gingerbread brush mode should not project surface hits before a color is sampled")
			camouflage_system.deactivate_skill()
			var paintable_meshes := camouflage_system.call("_get_paintable_meshes") as Array
			var saw_gingerbread_mesh := false
			var saw_hidden_robot_mesh := false
			for mesh_data in paintable_meshes:
				var mesh_path := str(mesh_data.get("path", ""))
				if mesh_path.contains("CustomCharacterSkin"):
					saw_gingerbread_mesh = true
				if mesh_path.contains("RobotArmature"):
					saw_hidden_robot_mesh = true
			if not saw_gingerbread_mesh:
				failures.append("Brush target discovery should include visible gingerbread meshes")
			if saw_hidden_robot_mesh:
				failures.append("Brush target discovery should ignore hidden robot meshes while gingerbread is active")
			camouflage_system.free()

			var ginger_path := str(player.get_path_to(ginger_mesh))
			var ginger_aabb := ginger_mesh.get_aabb()
			var ginger_center := ginger_mesh.global_transform * (ginger_aabb.position + ginger_aabb.size * 0.5)
			var ginger_extent := maxf(ginger_aabb.size.x, maxf(ginger_aabb.size.y, ginger_aabb.size.z))
			var ginger_projection_camera := Camera3D.new()
			ginger_projection_camera.name = "GingerProjectionCamera"
			ginger_projection_camera.fov = 45.0
			add_child(ginger_projection_camera)
			ginger_projection_camera.global_position = ginger_center + Vector3(0.0, 0.0, maxf(ginger_extent * 2.5, 2.0))
			ginger_projection_camera.look_at(ginger_center, Vector3.UP)
			ginger_projection_camera.current = true
			await get_tree().process_frame
			var ginger_projection_system := CamouflageSystem.new()
			ginger_projection_system.camouflage_owner = player
			ginger_projection_system.camera = ginger_projection_camera
			ginger_projection_system.brush_radius = 48.0
			var ginger_screen_point := ginger_projection_camera.unproject_position(ginger_center)
			var ginger_surface_hit := ginger_projection_system.call(
				"_project_screen_to_body_surface",
				ginger_screen_point,
				false,
				ginger_path,
				0
			) as Dictionary
			var ginger_hit_uv := Vector2(-1.0, -1.0)
			if ginger_surface_hit.is_empty():
				failures.append("High-poly gingerbread brush projection should hit the visible model from a real camera screen point")
			else:
				ginger_hit_uv = ginger_surface_hit.get("uv", Vector2(-1.0, -1.0))
				var ginger_hit_metric: PackedFloat32Array = ginger_surface_hit.get("uv_footprint_metric", PackedFloat32Array())
				if ginger_hit_uv.x < 0.0 or ginger_hit_uv.x > 1.0 or ginger_hit_uv.y < 0.0 or ginger_hit_uv.y > 1.0:
					failures.append("High-poly gingerbread brush projection should produce a normalized UV under the screen cursor")
				if str(ginger_surface_hit.get("mesh_path", "")) != ginger_path or int(ginger_surface_hit.get("surface", -1)) != 0:
					failures.append("High-poly gingerbread brush projection should keep the exact target mesh path and surface")
				if ginger_hit_metric.size() != 3:
					failures.append("High-poly gingerbread brush projection should carry surface-space footprint metrics for precise painting")
				if float(ginger_surface_hit.get("texture_radius", 0.0)) <= 0.0:
					failures.append("High-poly gingerbread brush projection should estimate a positive texture-space brush radius")
			var ginger_material_before_brush := ginger_mesh.get_surface_override_material(0)
			player._start_camouflage_brush_visual(Color(0.36, 0.22, 0.12, 1.0))
			if ginger_mesh.get_surface_override_material(0) != ginger_material_before_brush:
				failures.append("Starting brush mode should not repaint the entire gingerbread body")
			if not ginger_surface_hit.is_empty():
				var readable_ginger_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
				readable_ginger_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
				var readable_ginger_texture := ImageTexture.create_from_image(readable_ginger_canvas_image)
				player._camouflage_paint_textures["%s:%d" % [ginger_path, 0]] = readable_ginger_texture
				ginger_projection_system.has_sampled_color = true
				ginger_projection_system.brush_color = Color(0.95, 0.18, 0.08, 1.0)
				ginger_projection_system._surface_lock = ginger_surface_hit
				ginger_projection_system._surface_lock_mouse_position = Vector2.ZERO
				ginger_projection_system.call("_paint_at_mouse", true, ginger_screen_point)
				await get_tree().process_frame
				var precise_click_texture := player._camouflage_paint_textures.get("%s:%d" % [ginger_path, 0]) as Texture2D
				var precise_click_image := precise_click_texture.get_image() if precise_click_texture else null
				var ginger_hit_pixel := CamouflageSystem._brush_uv_to_pixel_center_float(ginger_hit_uv)
				var precise_center_alpha := _max_alpha_near(precise_click_image, ginger_hit_pixel, 1)
				var strongest_pixel := _strongest_alpha_pixel(precise_click_image, ginger_hit_pixel, 96)
				var global_strongest_pixel := _strongest_alpha_pixel(precise_click_image, ginger_hit_pixel, CamouflageSystem.TEXTURE_SIZE)
				var ginger_click_centroid := _paint_alpha_centroid(precise_click_image, ginger_hit_pixel, 96)
				var precise_metrics := ginger_projection_system.get_performance_metrics()
				if precise_center_alpha < 0.45:
					failures.append("High-poly gingerbread forced brush click should color the exact projected UV hit alpha=%.3f strongest_distance=%.3f global_strongest=%s global_distance=%.3f image=%s batches=%d texture_changed=%s" % [precise_center_alpha, strongest_pixel.distance_to(ginger_hit_pixel), str(global_strongest_pixel), global_strongest_pixel.distance_to(ginger_hit_pixel), str(precise_click_image != null), int(precise_metrics.get("brush_batches_submitted", 0)), str(precise_click_texture != readable_ginger_texture)])
				elif ginger_click_centroid.x >= INF or ginger_click_centroid.distance_to(ginger_hit_pixel) > 8.0:
					failures.append("High-poly gingerbread forced brush click should keep the painted area centered on the projected UV hit centroid=%s hit=%s distance=%.3f center_alpha=%.3f strongest=%s" % [str(ginger_click_centroid), str(ginger_hit_pixel), ginger_click_centroid.distance_to(ginger_hit_pixel), precise_center_alpha, str(strongest_pixel)])
				else:
					var ginger_click_pixel_count := _painted_pixel_count(precise_click_image, ginger_hit_pixel, 10, 0.06)
					if ginger_click_pixel_count < 30:
						var ginger_clip_triangles: PackedVector2Array = ginger_surface_hit.get("uv_clip_triangles", PackedVector2Array())
						failures.append("High-poly gingerbread forced brush click should paint a visible brush area instead of only speckles count=%d texture_radius=%.3f metric=%s clip_triangles=%d" % [ginger_click_pixel_count, float(ginger_surface_hit.get("texture_radius", 0.0)), str(ginger_surface_hit.get("uv_footprint_metric", PackedFloat32Array())), int(ginger_clip_triangles.size() / 3)])
			ginger_projection_system.free()
			ginger_projection_camera.queue_free()
			player._apply_camouflage_brush_stroke(
				Vector2(0.5, 0.5),
				Color(0.85, 0.28, 0.12, 1.0),
				18.0,
				0.0,
				player.global_position + Vector3(0.0, 1.0, 0.0),
				Vector3.FORWARD,
				ginger_path,
				0
			)
			await get_tree().process_frame
			var ginger_material := ginger_mesh.get_surface_override_material(0)
			if not ginger_material is ShaderMaterial:
				failures.append("Brush stroke should apply a paint-layer shader to the gingerbread mesh")
			elif not bool((ginger_material as ShaderMaterial).get_meta("camouflage_paint_layer", false)):
				failures.append("Brush stroke should use the dedicated camouflage paint-layer material")
			elif not (ginger_material as ShaderMaterial).get_shader_parameter("paint_texture") is Texture2D:
				failures.append("Brush stroke should apply an editable paint texture to the gingerbread mesh")
			if not player._camouflage_paint_textures.has("%s:%d" % [ginger_path, 0]):
				failures.append("Brush stroke should track the gingerbread target texture")
			var batch_uvs := PackedVector2Array([Vector2(0.42, 0.42), Vector2(0.46, 0.44), Vector2(0.50, 0.47)])
			player._apply_camouflage_brush_stroke_batch(
				batch_uvs,
				Color(0.18, 0.64, 0.92, 1.0),
				16.0,
				0.1,
				PackedVector3Array(),
				Vector3.FORWARD,
				ginger_path,
				0
			)
			if not player._camouflage_paint_textures.has("%s:%d" % [ginger_path, 0]):
				failures.append("Batch brush strokes should paint the targeted gingerbread texture")
			var reused_material := ginger_mesh.get_surface_override_material(0)
			player._apply_camouflage_brush_stroke(
				Vector2(0.52, 0.52),
				Color(0.20, 0.72, 0.30, 1.0),
				14.0,
				0.0,
				player.global_position + Vector3(0.0, 1.0, 0.0),
				Vector3.FORWARD,
				ginger_path,
				0
			)
			if ginger_mesh.get_surface_override_material(0) != reused_material:
				failures.append("Brush strokes should reuse the gingerbread surface material instead of duplicating every stroke")
			var target_texture_count_before_invalid: int = player._camouflage_paint_textures.size()
			var global_texture_before_invalid: Texture2D = player._camouflage_paint_texture
			player._apply_camouflage_brush_stroke(
				Vector2(0.25, 0.25),
				Color(0.95, 0.95, 0.1, 1.0),
				18.0,
				0.0,
				Vector3.ZERO,
				Vector3.UP,
				"MissingPaintMesh",
				0
			)
			if player._camouflage_paint_textures.size() != target_texture_count_before_invalid or player._camouflage_paint_texture != global_texture_before_invalid:
				failures.append("Targeted brush strokes with missing mesh paths should not fall back to repainting the whole character")
			var surface_key_probe := MeshInstance3D.new()
			surface_key_probe.name = "SurfaceKeyProbe"
			var surface_key_mesh := ArrayMesh.new()
			for _surface_index in range(2):
				var surface_arrays := []
				surface_arrays.resize(Mesh.ARRAY_MAX)
				surface_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
					Vector3(0.0, 0.0, 0.0),
					Vector3(1.0, 0.0, 0.0),
					Vector3(0.0, 1.0, 0.0),
				])
				surface_arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
					Vector2(0.1, 0.1),
					Vector2(0.2, 0.1),
					Vector2(0.1, 0.2),
				])
				surface_arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
				surface_key_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
			surface_key_probe.mesh = surface_key_mesh
			player.add_child(surface_key_probe)
			player._apply_camouflage_brush_stroke(
				Vector2(0.30, 0.30),
				Color(0.2, 0.2, 0.95, 1.0),
				18.0,
				0.0,
				Vector3.ZERO,
				Vector3.UP,
				"SurfaceKeyProbe",
				999
			)
			if not player._camouflage_paint_textures.has("SurfaceKeyProbe:1") or player._camouflage_paint_textures.has("SurfaceKeyProbe:999"):
				failures.append("Targeted brush strokes should normalize surface IDs before caching paint textures")
			surface_key_probe.queue_free()
		player.set_character_model(CharacterSkinCatalog.DEFAULT_ID)
		await get_tree().process_frame

		var no_color_probe := NoColorProcessProbe.new()
		no_color_probe.skill_active = true
		no_color_probe.has_sampled_color = false
		no_color_probe.call("_process", 0.016)
		if no_color_probe.update_count != 0:
			failures.append("Brush mode should not start expensive surface projection before a color is picked")
		no_color_probe.has_sampled_color = true
		no_color_probe.call("_process", 0.016)
		if no_color_probe.update_count != 1:
			failures.append("Brush mode should resume surface projection after a color is picked")
		no_color_probe.free()

		var pose_cache_probe := CamouflageSystem.new()
		pose_cache_probe._mesh_hit_cache["static:0"] = {}
		pose_cache_probe._mesh_hit_cache["123:0:pose:0"] = {}
		pose_cache_probe.call("_advance_pose_hit_cache_generation")
		if pose_cache_probe._mesh_hit_cache.has("123:0:pose:0"):
			failures.append("Brush pose hit cache should prune stale animated-pose entries when the pose generation changes")
		if not pose_cache_probe._mesh_hit_cache.has("static:0"):
			failures.append("Brush pose hit cache pruning should preserve reusable static mesh entries")
		pose_cache_probe._mesh_hit_build_jobs["123:0:pose:0"] = Thread.new()
		if bool(pose_cache_probe.call("_has_pending_mesh_hit_jobs")):
			failures.append("Stale animated-pose hit jobs should not block forced brush clicks")
		pose_cache_probe._mesh_hit_build_jobs.clear()
		pose_cache_probe.free()

		var warmup_order_owner := BrushLockOrderOwner.new()
		add_child(warmup_order_owner)
		var warmup_order_probe := ActivationWarmupOrderProbe.new()
		warmup_order_probe.camouflage_owner = warmup_order_owner
		warmup_order_probe.activate_skill()
		if not warmup_order_owner.locked:
			failures.append("Brush activation should still lock the owner immediately")
		if warmup_order_probe.warmup_called:
			failures.append("Brush activation should not prewarm surface hit caches; exact hits are built on demand to avoid CPU spikes")
		warmup_order_probe.deactivate_skill()
		warmup_order_probe.free()
		warmup_order_owner.queue_free()

		var direct_target_probe := DirectTargetProjectionProbe.new()
		add_child(direct_target_probe.camouflage_owner)
		direct_target_probe.call("_project_screen_to_body_surface", Vector2(64.0, 64.0), true, "PaintMesh", 2)
		if direct_target_probe.paintable_mesh_query_count != 0:
			failures.append("Targeted brush surface projection should bypass paintable mesh list scans")
		if direct_target_probe.intersect_count != 1 or direct_target_probe.last_target_surface != 2:
			failures.append("Targeted brush surface projection should ray-hit only the requested mesh surface")
		var direct_target_metrics := direct_target_probe.get_performance_metrics()
		if int(direct_target_metrics.get("targeted_surface_projection_calls", 0)) != 1:
			failures.append("Brush performance metrics should count targeted surface projection fast-path calls")
		if int(direct_target_metrics.get("paintable_mesh_cache_rebuilds", 0)) != 0:
			failures.append("Targeted brush projection fast path should not rebuild the paintable mesh cache")
		direct_target_probe.camouflage_owner.queue_free()
		direct_target_probe.free()

		var lock_probe := SurfaceLockProbe.new()
		lock_probe._surface_lock = {"uv": Vector2.ZERO}
		lock_probe._surface_lock_mouse_position = Vector2.ZERO
		lock_probe.call("_get_surface_lock", false)
		if lock_probe.update_count != 0:
			failures.append("Cached brush surface lock should be reused when the mouse has not moved")
		lock_probe.call("_get_surface_lock", true, Vector2(0.2, 0.0))
		if lock_probe.update_count != 1 or lock_probe._surface_lock_mouse_position.distance_to(Vector2(0.2, 0.0)) > 0.001:
			failures.append("Forced brush painting should refresh from the exact click position instead of reusing a nearby preview lock")
		lock_probe.call("_get_surface_lock", true, Vector2(0.2, 0.0))
		if lock_probe.update_count != 1:
			failures.append("Forced brush painting should reuse the surface lock only when the click position exactly matches the cached preview")
		lock_probe._surface_lock_mouse_position = Vector2(100.0, 100.0)
		lock_probe.call("_get_surface_lock", true)
		if lock_probe.update_count != 2:
			failures.append("Forced brush painting should refresh the surface lock after the mouse moves away from the preview")
		lock_probe.free()

		var event_click_probe := PaintProjectionProbe.new()
		add_child(event_click_probe.camouflage_owner)
		event_click_probe.skill_active = true
		event_click_probe.has_sampled_color = true
		event_click_probe.brush_color = Color(0.9, 0.25, 0.15, 1.0)
		event_click_probe.current_screen = Vector2.ZERO
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		click_event.position = Vector2(84.0, 0.0)
		event_click_probe.handle_brush_input(click_event)
		if event_click_probe.submitted_batches.is_empty():
			failures.append("Brush mouse-button input should paint immediately when a color has been sampled")
		else:
			var event_click_uvs := event_click_probe.submitted_batches[0].get("uvs", PackedVector2Array()) as PackedVector2Array
			var expected_event_click_uv := Vector2(84.0 / 140.0, 0.5)
			if event_click_uvs.is_empty() or event_click_uvs[0].distance_to(expected_event_click_uv) > 0.001:
				failures.append("Brush mouse-button input should use the exact event screen position instead of a stale viewport mouse position")
		event_click_probe.camouflage_owner.queue_free()
		event_click_probe.free()

		var left_pick_probe := LeftClickPickProbe.new()
		add_child(left_pick_probe.camouflage_owner)
		left_pick_probe.skill_active = true
		left_pick_probe.has_sampled_color = false
		var first_pick_event := InputEventMouseButton.new()
		first_pick_event.button_index = MOUSE_BUTTON_LEFT
		first_pick_event.pressed = true
		first_pick_event.position = Vector2(44.0, 12.0)
		left_pick_probe.handle_brush_input(first_pick_event)
		if left_pick_probe.picked_positions.size() != 1 or left_pick_probe.picked_positions[0].distance_to(first_pick_event.position) > 0.001:
			failures.append("Left mouse click should pick a scene color before painting starts")
		if not left_pick_probe.submitted_batches.is_empty():
			failures.append("Left mouse click should not paint before a scene color has been picked")
		left_pick_probe.force_empty_surface = true
		left_pick_probe.picked_positions.clear()
		left_pick_probe.submitted_batches.clear()
		left_pick_probe.has_sampled_color = true
		var repick_event := InputEventMouseButton.new()
		repick_event.button_index = MOUSE_BUTTON_LEFT
		repick_event.pressed = true
		repick_event.position = Vector2(25.0, 18.0)
		left_pick_probe.handle_brush_input(repick_event)
		if left_pick_probe.picked_positions.size() != 1 or left_pick_probe.picked_positions[0].distance_to(repick_event.position) > 0.001:
			failures.append("Left mouse click on the environment should update the sampled color while in brush mode")
		if not left_pick_probe.submitted_batches.is_empty():
			failures.append("Left mouse click on the environment should not submit a body paint stroke")
		left_pick_probe.camouflage_owner.queue_free()
		left_pick_probe.free()

		var material_key_probe := PaintProjectionProbe.new()
		add_child(material_key_probe.camouflage_owner)
		material_key_probe.skill_active = true
		material_key_probe.paint_exact_color_match = false
		material_key_probe.paint_metallic = 0.5
		var metallic_down_event := InputEventKey.new()
		metallic_down_event.keycode = KEY_F
		metallic_down_event.pressed = true
		material_key_probe.handle_brush_input(metallic_down_event)
		if absf(material_key_probe.paint_metallic - (0.5 - CamouflageSystem.PAINT_MATERIAL_STEP)) > 0.001:
			failures.append("F should decrease brush material metallic after color picking moved to left click")
		var metallic_up_event := InputEventKey.new()
		metallic_up_event.keycode = KEY_G
		metallic_up_event.pressed = true
		material_key_probe.handle_brush_input(metallic_up_event)
		if absf(material_key_probe.paint_metallic - 0.5) > 0.001:
			failures.append("G should increase brush material metallic instead of toggling color-match mode")
		if bool(material_key_probe.paint_exact_color_match):
			failures.append("G should not toggle the brush out of default LIT material response mode")
		var old_metallic := material_key_probe.paint_metallic
		var old_metallic_down_event := InputEventKey.new()
		old_metallic_down_event.keycode = KEY_V
		old_metallic_down_event.pressed = true
		material_key_probe.handle_brush_input(old_metallic_down_event)
		if absf(material_key_probe.paint_metallic - old_metallic) > 0.001:
			failures.append("V should no longer adjust brush metallic controls")
		var old_metallic_up_event := InputEventKey.new()
		old_metallic_up_event.keycode = KEY_B
		old_metallic_up_event.pressed = true
		material_key_probe.handle_brush_input(old_metallic_up_event)
		if absf(material_key_probe.paint_metallic - old_metallic) > 0.001:
			failures.append("B should no longer adjust brush metallic controls")
		material_key_probe.camouflage_owner.queue_free()
		material_key_probe.free()

		var throttled_drag_probe := PaintProjectionProbe.new()
		add_child(throttled_drag_probe.camouflage_owner)
		throttled_drag_probe.skill_active = true
		throttled_drag_probe.has_sampled_color = true
		throttled_drag_probe.brush_color = Color(0.2, 0.85, 0.3, 1.0)
		throttled_drag_probe.brush_radius = 32.0
		throttled_drag_probe._last_stroke_key = "PaintMesh:0"
		throttled_drag_probe._last_stroke_screen_position = Vector2.ZERO
		throttled_drag_probe._last_stroke_world_position = Vector3.ZERO
		throttled_drag_probe._last_stroke_uv = Vector2.ZERO
		throttled_drag_probe._stroke_wait = CamouflageSystem.BRUSH_STROKE_INTERVAL
		var throttled_screen := Vector2(91.0, 0.0)
		throttled_drag_probe.call("_paint_at_mouse", false, throttled_screen)
		if not throttled_drag_probe._pending_drag_paint:
			failures.append("Throttled brush drags should remember the latest precise mouse event instead of dropping it")
		elif throttled_drag_probe._pending_drag_screen_position.distance_to(throttled_screen) > 0.001:
			failures.append("Throttled brush drags should preserve the exact skipped event screen position")
		if not throttled_drag_probe.submitted_batches.is_empty():
			failures.append("Throttled brush drags should not paint until the stroke interval is ready")
		throttled_drag_probe._stroke_wait = 0.0
		throttled_drag_probe.call("_try_flush_pending_drag_paint")
		if throttled_drag_probe._pending_drag_paint or throttled_drag_probe.submitted_batches.is_empty():
			failures.append("Throttled brush drags should flush the queued precise mouse position once the interval is ready")
		else:
			var throttled_uvs := throttled_drag_probe.submitted_batches[0].get("uvs", PackedVector2Array()) as PackedVector2Array
			var expected_throttled_uv := Vector2(throttled_screen.x / 140.0, 0.5)
			var saw_flushed_uv := false
			for throttled_uv in throttled_uvs:
				if throttled_uv.distance_to(expected_throttled_uv) <= 0.001:
					saw_flushed_uv = true
					break
			if not saw_flushed_uv:
				failures.append("Flushed throttled brush drags should paint the preserved mouse event position")
		throttled_drag_probe.camouflage_owner.queue_free()
		throttled_drag_probe.free()

		var release_flush_probe := PaintProjectionProbe.new()
		add_child(release_flush_probe.camouflage_owner)
		release_flush_probe.skill_active = true
		release_flush_probe.has_sampled_color = true
		release_flush_probe.brush_color = Color(0.3, 0.9, 0.45, 1.0)
		release_flush_probe.brush_radius = 32.0
		release_flush_probe._last_stroke_key = "PaintMesh:0"
		release_flush_probe._last_stroke_screen_position = Vector2.ZERO
		release_flush_probe._last_stroke_world_position = Vector3.ZERO
		release_flush_probe._last_stroke_uv = Vector2.ZERO
		release_flush_probe._stroke_wait = CamouflageSystem.BRUSH_STROKE_INTERVAL
		release_flush_probe.call("_paint_at_mouse", false, Vector2(91.0, 0.0))
		var release_event := InputEventMouseButton.new()
		release_event.button_index = MOUSE_BUTTON_LEFT
		release_event.pressed = false
		release_event.position = Vector2(112.0, 0.0)
		release_flush_probe.handle_brush_input(release_event)
		if release_flush_probe._pending_drag_paint or release_flush_probe.submitted_batches.is_empty():
			failures.append("Releasing the brush should flush the throttled final drag point instead of dropping it")
		else:
			var release_uvs := release_flush_probe.submitted_batches[0].get("uvs", PackedVector2Array()) as PackedVector2Array
			var expected_release_uv := Vector2(release_event.position.x / 140.0, 0.5)
			var saw_release_uv := false
			for release_uv in release_uvs:
				if release_uv.distance_to(expected_release_uv) <= 0.001:
					saw_release_uv = true
					break
			if not saw_release_uv:
				failures.append("Releasing the brush should paint the final release screen position")
		release_flush_probe.camouflage_owner.queue_free()
		release_flush_probe.free()

		var release_endpoint_probe := PaintProjectionProbe.new()
		add_child(release_endpoint_probe.camouflage_owner)
		release_endpoint_probe.skill_active = true
		release_endpoint_probe.has_sampled_color = true
		release_endpoint_probe.brush_color = Color(0.35, 0.75, 0.95, 1.0)
		release_endpoint_probe.brush_radius = 32.0
		release_endpoint_probe._last_stroke_key = "PaintMesh:0"
		release_endpoint_probe._last_stroke_mesh_path = "PaintMesh"
		release_endpoint_probe._last_stroke_screen_position = Vector2(84.0, 0.0)
		release_endpoint_probe._last_stroke_world_position = Vector3(0.6, 0.0, 0.0)
		release_endpoint_probe._last_stroke_uv = Vector2(0.6, 0.5)
		release_endpoint_probe._stroke_wait = CamouflageSystem.BRUSH_STROKE_INTERVAL
		var release_endpoint_event := InputEventMouseButton.new()
		release_endpoint_event.button_index = MOUSE_BUTTON_LEFT
		release_endpoint_event.pressed = false
		release_endpoint_event.position = Vector2(126.0, 0.0)
		release_endpoint_probe.handle_brush_input(release_endpoint_event)
		if release_endpoint_probe._pending_drag_paint or release_endpoint_probe.submitted_batches.is_empty():
			failures.append("Releasing the brush at a new screen position should paint the final endpoint even without a queued drag event")
		else:
			var release_endpoint_uvs := release_endpoint_probe.submitted_batches[0].get("uvs", PackedVector2Array()) as PackedVector2Array
			var expected_release_endpoint_uv := Vector2(release_endpoint_event.position.x / 140.0, 0.5)
			var saw_release_endpoint_uv := false
			for release_endpoint_uv in release_endpoint_uvs:
				if release_endpoint_uv.distance_to(expected_release_endpoint_uv) <= 0.001:
					saw_release_endpoint_uv = true
					break
			if not saw_release_endpoint_uv:
				failures.append("Release endpoint painting should use the exact release event screen position")
		release_endpoint_probe.camouflage_owner.queue_free()
		release_endpoint_probe.free()

		var release_noop_probe := PaintProjectionProbe.new()
		add_child(release_noop_probe.camouflage_owner)
		release_noop_probe.skill_active = true
		release_noop_probe.has_sampled_color = true
		release_noop_probe.brush_color = Color(0.35, 0.75, 0.95, 1.0)
		release_noop_probe.brush_radius = 32.0
		release_noop_probe._last_stroke_key = "PaintMesh:0"
		release_noop_probe._last_stroke_mesh_path = "PaintMesh"
		release_noop_probe._last_stroke_screen_position = Vector2(84.0, 0.0)
		release_noop_probe._last_stroke_world_position = Vector3(0.6, 0.0, 0.0)
		release_noop_probe._last_stroke_uv = Vector2(0.6, 0.5)
		release_noop_probe._stroke_wait = CamouflageSystem.BRUSH_STROKE_INTERVAL
		var release_noop_event := InputEventMouseButton.new()
		release_noop_event.button_index = MOUSE_BUTTON_LEFT
		release_noop_event.pressed = false
		release_noop_event.position = release_noop_probe._last_stroke_screen_position
		release_noop_probe.handle_brush_input(release_noop_event)
		if release_noop_probe._pending_drag_paint or not release_noop_probe.submitted_batches.is_empty():
			failures.append("Releasing at the last painted screen position should not duplicate a click dab")
		release_noop_probe.camouflage_owner.queue_free()
		release_noop_probe.free()

		var projection_probe := PaintProjectionProbe.new()
		add_child(projection_probe.camouflage_owner)
		projection_probe.has_sampled_color = true
		projection_probe.brush_color = Color(0.9, 0.2, 0.1, 1.0)
		projection_probe._last_stroke_key = "PaintMesh:0"
		projection_probe._last_stroke_screen_position = Vector2.ZERO
		projection_probe._last_stroke_world_position = Vector3.ZERO
		projection_probe._last_stroke_uv = Vector2.ZERO
		projection_probe.current_screen = Vector2(140.0, 0.0)
		projection_probe.call("_paint_at_mouse", false)
		var projected_stamp_count := 0
		for batch in projection_probe.submitted_batches:
			projected_stamp_count += (batch.get("uvs", PackedVector2Array()) as PackedVector2Array).size()
		if projected_stamp_count <= 1:
			failures.append("Brush dragging should resample the screen path instead of linearly lerping UVs")
		if projection_probe.targeted_projection_count <= 0:
			failures.append("Brush drag interpolation should query intermediate stamps on the clicked mesh surface fast path")
		if projection_probe.untargeted_projection_count > 0:
			failures.append("Brush drag interpolation should not run full body projection for intermediate stamps")
		var projected_radius_count := 0
		for batch in projection_probe.submitted_batches:
			projected_radius_count += (batch.get("radii", PackedFloat32Array()) as PackedFloat32Array).size()
		if projected_radius_count < 5:
			failures.append("Dragged brush strokes should lay down multiple precise center stamps along the cursor path")
		var max_drag_stamp_count := CamouflageSystem.BRUSH_MAX_INTERPOLATED_STAMPS + CamouflageSystem.BRUSH_PRECISION_DAB_MAX_SAMPLES - 1
		if projected_radius_count > max_drag_stamp_count:
			failures.append("Interpolated brush strokes should keep precision dabs bounded for performance")
		if int(projection_probe.get_performance_metrics().get("brush_precision_local_samples", 0)) <= 0:
			failures.append("Regular held brush strokes should use the same bounded local precision dab as forced clicks")
		var saw_projected_radius := false
		var saw_projected_uv_clip := false
		var saw_projected_footprint_mask := false
		for batch in projection_probe.submitted_batches:
			var radii := batch.get("radii", PackedFloat32Array()) as PackedFloat32Array
			var uv_clip_triangles := batch.get("uv_clip_triangles", PackedVector2Array()) as PackedVector2Array
			var uv_clip_triangle_counts := batch.get("uv_clip_triangle_counts", PackedInt32Array()) as PackedInt32Array
			var uv_footprint_metrics := batch.get("uv_footprint_metrics", PackedFloat32Array()) as PackedFloat32Array
			if not uv_clip_triangles.is_empty() or not uv_clip_triangle_counts.is_empty():
				saw_projected_uv_clip = true
			if not uv_footprint_metrics.is_empty():
				saw_projected_footprint_mask = true
			for radius in radii:
				if absf(radius - 73.0) < 0.001:
					saw_projected_radius = true
		if not saw_projected_radius:
			failures.append("Brush stroke submission should preserve the exact clicked surface texture radius")
		if saw_projected_uv_clip:
			failures.append("Brush stroke submission should not send hit-triangle UV clipping by default because it creates triangular paint artifacts")
		if saw_projected_footprint_mask:
			failures.append("Brush stroke submission should not send surface footprint masks by default because they create dotted paint on curved areas")
		projection_probe.camouflage_owner.queue_free()
		projection_probe.free()

		var fast_drag_probe := PaintProjectionProbe.new()
		add_child(fast_drag_probe.camouflage_owner)
		fast_drag_probe.has_sampled_color = true
		fast_drag_probe.brush_color = Color(0.18, 0.7, 0.95, 1.0)
		fast_drag_probe.brush_radius = 24.0
		fast_drag_probe._last_stroke_key = "PaintMesh:0"
		fast_drag_probe._last_stroke_screen_position = Vector2.ZERO
		fast_drag_probe._last_stroke_world_position = Vector3.ZERO
		fast_drag_probe._last_stroke_uv = Vector2.ZERO
		fast_drag_probe.current_screen = Vector2(180.0, 0.0)
		fast_drag_probe.call("_paint_at_mouse", false)
		var fast_drag_stamp_count := 0
		var fast_drag_uvs := PackedVector2Array()
		var fast_drag_radii := PackedFloat32Array()
		for batch in fast_drag_probe.submitted_batches:
			var batch_uvs := batch.get("uvs", PackedVector2Array()) as PackedVector2Array
			var batch_radii := batch.get("radii", PackedFloat32Array()) as PackedFloat32Array
			fast_drag_stamp_count += batch_radii.size()
			fast_drag_uvs.append_array(batch_uvs)
			fast_drag_radii.append_array(batch_radii)
		var fast_drag_max_stamp_count := CamouflageSystem.BRUSH_MAX_INTERPOLATED_STAMPS + CamouflageSystem.BRUSH_PRECISION_DAB_MAX_SAMPLES - 1
		if fast_drag_stamp_count < 12:
			failures.append("Very fast brush drags should add enough interpolated center stamps to avoid visible gaps")
		if fast_drag_stamp_count > fast_drag_max_stamp_count:
			failures.append("Very fast brush drags should stay bounded by the interpolation and precision-sample caps")
		if fast_drag_probe.targeted_projection_count < CamouflageSystem.BRUSH_MAX_INTERPOLATED_STAMPS - 1:
			failures.append("Very fast brush drags should keep using targeted projection for dense path interpolation")
		if fast_drag_probe.untargeted_projection_count != 0:
			failures.append("Very fast brush drags should not fall back to full body projection")
		var fast_drag_canvas_image := Image.create(CamouflageSystem.TEXTURE_SIZE, CamouflageSystem.TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
		fast_drag_canvas_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		var fast_drag_canvas := ImageTexture.create_from_image(fast_drag_canvas_image)
		var fast_drag_painted := CamouflageSystem.paint_brush_strokes_on_texture(
			fast_drag_canvas,
			fast_drag_uvs,
			Color(0.18, 0.7, 0.95, 1.0),
			24.0,
			0.0,
			fast_drag_radii
		)
		var fast_drag_image := fast_drag_painted.get_image() if fast_drag_painted else null
		var fast_drag_weak_samples := 0
		for sample_index in range(1, 10):
			var sample_uv := Vector2(float(sample_index) / 10.0, 0.5)
			var sample_pixel := CamouflageSystem._brush_uv_to_pixel_center_float(sample_uv)
			if _max_alpha_near(fast_drag_image, sample_pixel, 3) < 0.20:
				fast_drag_weak_samples += 1
		if fast_drag_weak_samples > 0:
			failures.append("Very fast brush drags should paint a continuous texture trail without alpha gaps; weak_samples=%d" % fast_drag_weak_samples)
		fast_drag_probe.camouflage_owner.queue_free()
		fast_drag_probe.free()

		var drag_stress_probe := PaintProjectionProbe.new()
		add_child(drag_stress_probe.camouflage_owner)
		drag_stress_probe.has_sampled_color = true
		drag_stress_probe.brush_color = Color(0.12, 0.75, 0.95, 1.0)
		drag_stress_probe.brush_radius = 86.0
		drag_stress_probe._last_stroke_key = "PaintMesh:0"
		drag_stress_probe._last_stroke_screen_position = Vector2.ZERO
		drag_stress_probe._last_stroke_world_position = Vector3.ZERO
		drag_stress_probe._last_stroke_uv = Vector2.ZERO
		for step in range(1, 6):
			drag_stress_probe.current_screen = Vector2(float(step) * 42.0, 0.0)
			drag_stress_probe._stroke_wait = 0.0
			drag_stress_probe.call("_paint_at_mouse", false)
		var drag_stress_metrics := drag_stress_probe.get_performance_metrics()
		if drag_stress_probe.untargeted_projection_count != 0:
			failures.append("Repeated brush drags should not fall back to full body projection for interpolation")
		if drag_stress_probe.targeted_projection_count < 4:
			failures.append("Repeated brush drags should keep using targeted surface projection for path interpolation")
		if drag_stress_probe.targeted_projection_count > 10:
			failures.append("Repeated brush drags should not add satellite projection work around each interpolated stamp")
		if int(drag_stress_metrics.get("brush_stamps_submitted", 0)) < 8:
			failures.append("Repeated brush drags should submit continuous center stamps along the path")
		drag_stress_probe.camouflage_owner.queue_free()
		drag_stress_probe.free()

		var imprecise_dab_probe := ImpreciseSatelliteProjectionProbe.new()
		add_child(imprecise_dab_probe.camouflage_owner)
		imprecise_dab_probe.has_sampled_color = true
		imprecise_dab_probe.brush_color = Color(0.95, 0.15, 0.12, 1.0)
		imprecise_dab_probe.brush_radius = 96.0
		imprecise_dab_probe.current_screen = Vector2(96.0, 96.0)
		imprecise_dab_probe.call("_paint_at_mouse", true)
		var imprecise_stamp_count := 0
		for batch in imprecise_dab_probe.submitted_batches:
			imprecise_stamp_count += (batch.get("radii", PackedFloat32Array()) as PackedFloat32Array).size()
		if imprecise_stamp_count != 1:
			failures.append("A single brush click should paint only the exact clicked surface point")
		imprecise_dab_probe.camouflage_owner.queue_free()
		imprecise_dab_probe.free()

		var small_dab_probe := PaintProjectionProbe.new()
		add_child(small_dab_probe.camouflage_owner)
		small_dab_probe.has_sampled_color = true
		small_dab_probe.brush_color = Color(0.7, 0.25, 0.1, 1.0)
		small_dab_probe.brush_radius = 12.0
		small_dab_probe.current_screen = Vector2(32.0, 0.0)
		small_dab_probe.call("_paint_at_mouse", true)
		var small_dab_radius_ok := false
		var small_dab_stamp_count := 0
		for batch in small_dab_probe.submitted_batches:
			var radii := batch.get("radii", PackedFloat32Array()) as PackedFloat32Array
			small_dab_stamp_count += radii.size()
			for radius in radii:
				if absf(radius - 73.0) < 0.001:
					small_dab_radius_ok = true
		if not small_dab_radius_ok or small_dab_stamp_count != 1:
			failures.append("Small precise brush clicks should keep the full local texture radius without satellite shrink")
		small_dab_probe.camouflage_owner.queue_free()
		small_dab_probe.free()

		var large_dab_probe := PaintProjectionProbe.new()
		add_child(large_dab_probe.camouflage_owner)
		large_dab_probe.has_sampled_color = true
		large_dab_probe.brush_color = Color(0.2, 0.55, 0.95, 1.0)
		large_dab_probe.brush_radius = 96.0
		large_dab_probe.current_screen = Vector2(48.0, 0.0)
		large_dab_probe.call("_paint_at_mouse", true)
		var large_dab_stamp_count := 0
		var large_dab_center_uv := Vector2(large_dab_probe.current_screen.x / 140.0, 0.5)
		var large_dab_kept_center := false
		var large_dab_sent_masks := false
		for batch in large_dab_probe.submitted_batches:
			var batch_uvs := batch.get("uvs", PackedVector2Array()) as PackedVector2Array
			large_dab_stamp_count += batch_uvs.size()
			for uv in batch_uvs:
				if uv.distance_to(large_dab_center_uv) <= 0.001:
					large_dab_kept_center = true
			if not (batch.get("uv_clip_triangles", PackedVector2Array()) as PackedVector2Array).is_empty():
				large_dab_sent_masks = true
			if not (batch.get("uv_clip_triangle_counts", PackedInt32Array()) as PackedInt32Array).is_empty():
				large_dab_sent_masks = true
			if not (batch.get("uv_footprint_metrics", PackedFloat32Array()) as PackedFloat32Array).is_empty():
				large_dab_sent_masks = true
		if large_dab_stamp_count <= 1 or large_dab_stamp_count > CamouflageSystem.BRUSH_PRECISION_DAB_MAX_SAMPLES:
			failures.append("Extra-large brush clicks should add bounded same-surface precision samples instead of only one imprecise UV stamp")
		if large_dab_probe.targeted_projection_count != 0:
			failures.append("Single brush precision samples should use local UV offsets before falling back to extra ray projections")
		if not large_dab_kept_center:
			failures.append("Precision brush clicks should always preserve the exact cursor hit as the first-class painted center")
		if large_dab_sent_masks:
			failures.append("Precision brush clicks should still avoid triangle and footprint masks so paint remains continuous")
		var large_dab_metrics := large_dab_probe.get_performance_metrics()
		if int(large_dab_metrics.get("brush_batches_submitted", 0)) <= 0 or int(large_dab_metrics.get("brush_stamps_submitted", 0)) < large_dab_stamp_count:
			failures.append("Brush performance metrics should count submitted batches and stamps")
		if int(large_dab_metrics.get("brush_precision_local_samples", 0)) <= 0:
			failures.append("Brush precision dabs should use fast local UV samples when the hit triangle has enough data")
		large_dab_probe.camouflage_owner.queue_free()
		large_dab_probe.free()

		var skewed_uv_probe := SkewedLocalUvProjectionProbe.new()
		add_child(skewed_uv_probe.camouflage_owner)
		skewed_uv_probe.has_sampled_color = true
		skewed_uv_probe.brush_color = Color(0.95, 0.65, 0.12, 1.0)
		skewed_uv_probe.brush_radius = 96.0
		skewed_uv_probe.current_screen = Vector2(70.0, 0.0)
		skewed_uv_probe.call("_paint_at_mouse", true)
		var skewed_uv_stamp_count := 0
		var skewed_uv_kept_center := false
		for batch in skewed_uv_probe.submitted_batches:
			var batch_uvs := batch.get("uvs", PackedVector2Array()) as PackedVector2Array
			skewed_uv_stamp_count += batch_uvs.size()
			for uv in batch_uvs:
				if uv.distance_to(Vector2(0.5, 0.5)) <= 0.001:
					skewed_uv_kept_center = true
		var skewed_uv_metrics := skewed_uv_probe.get_performance_metrics()
		if skewed_uv_stamp_count != 1 or not skewed_uv_kept_center:
			failures.append("Precision brush clicks should reject off-center local UV samples and keep only the exact cursor hit")
		if skewed_uv_probe.targeted_projection_count != 0:
			failures.append("Rejected local UV precision samples should not fall back to imprecise satellite ray projections")
		if int(skewed_uv_metrics.get("brush_precision_local_sample_reject_distribution", 0)) <= 0:
			failures.append("Brush metrics should report rejected local UV sample distributions")
		skewed_uv_probe.camouflage_owner.queue_free()
		skewed_uv_probe.free()

		var pending_probe := PendingPaintProbe.new()
		add_child(pending_probe.camouflage_owner)
		pending_probe.has_sampled_color = true
		pending_probe.skill_active = true
		pending_probe.brush_color = Color(0.1, 0.8, 0.3, 1.0)
		pending_probe.pending_jobs = true
		pending_probe.call("_paint_at_mouse", true)
		if not pending_probe._pending_forced_paint:
			failures.append("Forced brush click should be queued while exact paint cache is preparing")
		pending_probe.pending_jobs = false
		pending_probe.call("_try_flush_pending_paint_request")
		if pending_probe.submitted_batches.is_empty():
			failures.append("Queued brush click should paint automatically after exact hit cache finishes")
		pending_probe.camouflage_owner.queue_free()
		pending_probe.free()

		var queued_position_probe := PendingPaintProbe.new()
		add_child(queued_position_probe.camouflage_owner)
		queued_position_probe.has_sampled_color = true
		queued_position_probe.skill_active = true
		queued_position_probe.brush_color = Color(0.1, 0.8, 0.3, 1.0)
		var queued_click_position := Vector2(123.0, 45.0)
		queued_position_probe.call("_queue_pending_paint_request", queued_click_position)
		queued_position_probe.call("_try_flush_pending_paint_request")
		if queued_position_probe.submitted_batches.is_empty():
			failures.append("Queued brush click should be replayed once exact projection is available")
		else:
			var queued_uvs := queued_position_probe.submitted_batches[0].get("uvs", PackedVector2Array()) as PackedVector2Array
			var expected_queued_uv := Vector2(queued_click_position.x / 256.0, queued_click_position.y / 256.0)
			if queued_uvs.is_empty() or queued_uvs[0].distance_to(expected_queued_uv) > 0.001:
				failures.append("Queued brush click should preserve the original click screen position when delayed by hit-cache preparation")
		queued_position_probe.camouflage_owner.queue_free()
		queued_position_probe.free()

		var preview_owner := CharacterBody3D.new()
		preview_owner.name = "PreviewProbeOwner"
		add_child(preview_owner)
		var preview_probe := CamouflageSystem.new()
		preview_probe.camouflage_owner = preview_owner
		preview_probe.skill_active = true
		preview_probe.has_sampled_color = true
		preview_probe.brush_color = Color(0.25, 0.9, 0.35, 1.0)
		preview_probe.brush_radius = 96.0
		var preview_position := Vector3(0.2, 1.1, -0.4)
		var preview_normal := Vector3.UP
		preview_probe.call("_update_surface_preview", {
			"position": preview_position,
			"normal": preview_normal,
			"uv": Vector2(0.5, 0.5),
			"screen": Vector2(320.0, 240.0),
			"mesh_path": "PaintMesh",
			"surface": 0,
		})
		var surface_preview := preview_owner.get_node_or_null("CamouflageSurfacePreview") as MeshInstance3D
		if not surface_preview or not surface_preview.visible:
			failures.append("Brush surface preview should create a visible 3D marker at the exact hit point")
		elif surface_preview.global_position.distance_to(preview_position + preview_normal * CamouflageSystem.SURFACE_PREVIEW_OFFSET) > 0.002:
			failures.append("Brush surface preview should be snapped to the hit point and offset along the surface normal")
		if surface_preview:
			var preview_mesh := surface_preview.mesh as ArrayMesh
			if not preview_mesh or preview_mesh.get_surface_count() <= 0:
				failures.append("Brush surface preview should use a generated mesh marker")
			elif preview_mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
				failures.append("Brush surface preview should use thick triangle geometry instead of thin line primitives")
			var expected_preview_radius := float(preview_probe.call("_brush_screen_radius_to_world", preview_position, preview_probe.brush_radius))
			var preview_radius_x := surface_preview.global_transform.basis.x.length()
			var preview_radius_z := surface_preview.global_transform.basis.z.length()
			if absf(preview_radius_x - expected_preview_radius) > 0.001 or absf(preview_radius_z - expected_preview_radius) > 0.001:
				failures.append("Brush surface preview radius should match the exact world-space brush radius")
			var preview_texture_radius := CamouflageSystem._estimate_texture_radius_from_triangle(
				expected_preview_radius,
				Vector3.ZERO,
				Vector3(1.0, 0.0, 0.0),
				Vector3(0.0, 0.0, 1.0),
				Vector2.ZERO,
				Vector2(0.5, 0.0),
				Vector2(0.0, 0.5)
			)
			var expected_texture_radius := clampf(expected_preview_radius * 512.0, CamouflageSystem.BRUSH_MIN_RADIUS, CamouflageSystem.BRUSH_MAX_RADIUS)
			if absf(preview_texture_radius - expected_texture_radius) > 1.0:
				failures.append("Brush surface preview world radius should map to the same texture-space radius used by paint stamps")
			preview_probe.brush_radius = 32.0
			preview_probe.call("_update_surface_preview", {
				"position": preview_position,
				"normal": preview_normal,
				"uv": Vector2(0.5, 0.5),
				"screen": Vector2(320.0, 240.0),
				"mesh_path": "PaintMesh",
				"surface": 0,
			})
			var smaller_expected_radius := float(preview_probe.call("_brush_screen_radius_to_world", preview_position, preview_probe.brush_radius))
			if surface_preview.global_transform.basis.x.length() >= preview_radius_x or absf(surface_preview.global_transform.basis.x.length() - smaller_expected_radius) > 0.001:
				failures.append("Brush surface preview should resize immediately when brush size changes")
		preview_probe.call("_hide_surface_preview")
		if surface_preview and surface_preview.visible:
			failures.append("Brush surface preview should hide cleanly when the surface lock is lost")
		preview_probe.free()
		preview_owner.queue_free()

		var preset := ShapeShiftSystem.PRESET_LIBRARY[0]
		player.apply_prop_disguise(preset)
		await get_tree().process_frame
		if not player.has_method("is_disguised") or not player.is_disguised():
			failures.append("Player did not enter prop disguise state")
		if not player.get_node_or_null("3DGodotRobot/PropDisguise"):
			failures.append("Prop disguise visual node was not created")
		var player_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not player_collision or not player_collision.shape is CylinderShape3D:
			failures.append("Prop disguise should switch the player movement collider to a prop cylinder")

		player.clear_prop_disguise()
		await get_tree().process_frame
		if player.is_disguised():
			failures.append("Player did not clear prop disguise state")
		if player.get_node_or_null("3DGodotRobot/PropDisguise"):
			failures.append("Prop disguise visual node remained after clearing")
		if not player_collision or not player_collision.shape is CapsuleShape3D:
			failures.append("Clearing prop disguise should restore the default player capsule collider")

		if FruitPropCatalog.all().size() < 40:
			failures.append("Map prop catalog should include the food prefab families")
		var catalog_entry := FruitPropCatalog.by_id("apple")
		if not load(str(catalog_entry.get("scene", ""))) is PackedScene:
			failures.append("Catalog apple prefab did not load as PackedScene")
		for migrated_id in ["synty_barrel_metal", "tanks_busted_tank", "weapon_ak74"]:
			if str(FruitPropCatalog.by_id(migrated_id).get("id", "")) == migrated_id:
				failures.append("Unity decoration or weapon should not be registered as a replicable map prop: " + migrated_id)
		for decoration in UnityAssetCatalog.decorations():
			var decoration_scene_path := str(decoration.get("scene", ""))
			if not load(decoration_scene_path) is PackedScene:
				failures.append("Unity decoration scene did not load as PackedScene: " + decoration_scene_path)
			if str(decoration.get("material", "")).is_empty() or not load(str(decoration.get("material", ""))) is Material:
				failures.append("Unity decoration should have a Godot material override: " + str(decoration.get("id", "")))
		var ak74_weapon := UnityAssetCatalog.weapon_by_id("ak74")
		if not load(str(ak74_weapon.get("scene", ""))) is PackedScene:
			failures.append("AK74 weapon placeholder scene did not load")
		if not load("res://scenes/weapons/ak47.tscn") is PackedScene:
			failures.append("Hunter default AK74 weapon visual scene did not load")

		var prop := FruitProp.new()
		add_child(prop)
		prop.apply_data({
			"id": "apple",
			"name": "Apple",
			"category": "fruit",
			"scene": "res://Prefabs/Fruits/apple.tscn",
			"material": "res://Materials/M_fruit.tres",
			"scale": Vector3.ONE * 4.8,
			"radius": 0.22,
			"position": player.global_position + Vector3(1.0, 0.0, 0.0),
			"rotation_y": 0.0,
		})
		await get_tree().process_frame
		if prop.collision_layer != 4:
			failures.append("Map props should use the dedicated prop physics layer")
		if prop.collision_mask != 2:
			failures.append("Map props should solve rigid-body physics against world geometry only")
		if not (prop is RigidBody3D):
			failures.append("Map props should be rigid bodies so player impacts can move them")
		var map_collision := _find_collision_shape(prop)
		if not map_collision or not map_collision.shape:
			failures.append("Map prop should build a collision footprint")
		elif not map_collision.position.is_zero_approx():
			failures.append("Map prop collision should be centered on the rigid body origin")
		if prop.visual_bounds.position.y < -prop.collision_height * 0.5 - 0.02:
			failures.append("Map prop visuals should stay above the physical floor contact")
		player.global_position = Vector3(0.0, 3.25, 0.0)
		player.velocity = Vector3(0.0, -3.0, 0.0)
		player.apply_prop_disguise(prop.get_disguise_preset())
		var drop_disguise := player.get_node_or_null("3DGodotRobot/PropDisguise") as Node3D
		if absf(player.global_position.y) > 0.05:
			failures.append("Replicating a nearby prop should snap the player body back to the floor")
		if player._prop_disguise_tween == null or not player._prop_disguise_tween.is_valid():
			failures.append("Prop disguise should create the landing squash/stretch tween")
		if drop_disguise and drop_disguise.position.y <= player._prop_disguise_base_position.y:
			failures.append("Prop disguise landing animation should start above the grounded final position")
		if drop_disguise:
			var animated_position := drop_disguise.position
			var animated_scale := drop_disguise.scale
			drop_disguise.position = player._prop_disguise_base_position
			drop_disguise.scale = Vector3.ONE
			var grounded_bounds: AABB = player._calculate_prop_disguise_bounds_in_body_space()
			if absf(grounded_bounds.position.y) > 0.05:
				failures.append("Prop disguise final visual bottom should be aligned with the floor")
			var expected_prop_height := prop.visual_bounds.size.y
			if absf(grounded_bounds.size.y - expected_prop_height) > 0.08:
				failures.append("Prop disguise final visual height should match the replicated prop height (visual=%.3f expected=%.3f)" % [grounded_bounds.size.y, expected_prop_height])
			drop_disguise.position = animated_position
			drop_disguise.scale = animated_scale
		var disguise_collision := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if disguise_collision and disguise_collision.shape is CylinderShape3D:
			var disguise_height := (disguise_collision.shape as CylinderShape3D).height
			var expected_collision_height := minf(prop.visual_bounds.size.y, player.PROP_COLLISION_MAX_HEIGHT)
			if disguise_height < expected_collision_height - 0.05:
				failures.append("Prop disguise collider should preserve the replicated prop height (collider=%.3f expected=%.3f)" % [disguise_height, expected_collision_height])
		player.clear_prop_disguise()
		await get_tree().process_frame
		player.global_position = Vector3.ZERO
		player.velocity = Vector3.ZERO
		prop.global_position = Vector3(0.74, prop.collision_height * 0.5 + 0.035, 0.0)
		await get_tree().physics_frame
		var motion_collision: KinematicCollision3D = player.move_and_collide(Vector3(1.2, 0.0, 0.0), true)
		if motion_collision and motion_collision.get_collider() == prop:
			failures.append("Player movement should not be solved directly against round prop bodies")
		prop.linear_velocity = Vector3.ZERO
		prop.angular_velocity = Vector3.ZERO
		prop.sleeping = true
		player.global_position = Vector3.ZERO
		player.velocity = Vector3(7.0, 0.0, 0.0)
		await get_tree().physics_frame
		player.move_and_slide()
		var applied_impact: bool = player._apply_prop_collision_impacts(Vector3(7.0, 0.0, 0.0))
		await get_tree().physics_frame
		if not applied_impact:
			failures.append("Player proximity impact should detect nearby movable props")
		if prop.linear_velocity.length() < 0.05 and prop.angular_velocity.length() < 0.05:
			failures.append("Player impact should apply movement or rolling velocity to map props")
		if player.velocity.y > 0.05:
			failures.append("Player impact against movable props should not inject upward velocity")

		var watermelon_entry := FruitPropCatalog.by_id("watermelon")
		var watermelon := FruitProp.new()
		add_child(watermelon)
		watermelon.apply_data({
			"id": "watermelon",
			"name": "Watermelon",
			"category": "fruit",
			"scene": str(watermelon_entry.get("scene", "res://Prefabs/Fruits/watermelon.tscn")),
			"material": str(watermelon_entry.get("material", "res://Materials/M_fruit.tres")),
			"scale": Vector3.ONE * 5.0,
			"radius": 0.26,
			"position": Vector3(3.0, 0.0, 0.0),
			"rotation_y": 0.0,
		})
		await get_tree().physics_frame
		if watermelon.visual_bounds.position.y < -watermelon.collision_height * 0.5 - 0.02:
			failures.append("Watermelon visual should not sink below the floor contact after physics spawn")
		var watermelon_collision := _find_collision_shape(watermelon)
		if not watermelon_collision or not watermelon_collision.shape is SphereShape3D:
			failures.append("Watermelon should use a sphere collider for weighted rolling")
		if watermelon.mass <= prop.mass:
			failures.append("Large round props should be heavier than small baseline props")
		watermelon.global_position = Vector3(3.2, watermelon.collision_half_height + 0.045, 0.0)
		watermelon.linear_velocity = Vector3(18.0, 0.0, 0.0)
		watermelon.angular_velocity = Vector3(0.0, 0.0, 16.0)
		watermelon.sleeping = false
		for _i in range(16):
			await get_tree().physics_frame
		if watermelon.global_position.x > 3.95:
			failures.append("Fast round props should collide with fixed blockers instead of tunneling")
		if watermelon.linear_velocity.length() > 7.2 or watermelon.angular_velocity.length() > 7.8:
			failures.append("Prop velocities should be clamped for grounded heavy physics")

		var pineapple_entry := FruitPropCatalog.by_id("pineapple")
		var pineapple := FruitProp.new()
		add_child(pineapple)
		pineapple.apply_data({
			"id": "pineapple",
			"name": "Pineapple",
			"category": "fruit",
			"scene": str(pineapple_entry.get("scene", "res://Prefabs/Fruits/pineapple.tscn")),
			"material": str(pineapple_entry.get("material", "res://Materials/M_fruit.tres")),
			"scale": Vector3.ONE * 5.0,
			"radius": 0.28,
			"position": Vector3(-3.0, 0.0, 0.0),
			"rotation_y": 0.0,
		})
		await get_tree().physics_frame
		if pineapple.collision_kind != "tall":
			failures.append("Pineapple should use a tall collider profile")
		if pineapple.center_of_mass.y >= 0.0:
			failures.append("Tall irregular props should have a lower center of mass to settle naturally")
		if pineapple.visual_bounds.position.y < -pineapple.collision_half_height - 0.02:
			failures.append("Pineapple visual should not clip below its ground contact when spawned")

		var shape_system := ShapeShiftSystem.new()
		player.add_child(shape_system)
		shape_system.initialize(player)
		if not shape_system.has_nearby_replicable_prop():
			failures.append("Nearby replicable prop was not detected")
		elif not shape_system.try_replicate_nearby_prop():
			failures.append("Nearby prop replica did not start")
		else:
			await get_tree().process_frame
			if not player.is_disguised():
				failures.append("Player did not enter map prop disguise state")
			var visual := player.get_node_or_null("3DGodotRobot/PropDisguise/ScenePropVisual")
			if not visual:
				failures.append("Map prop disguise visual scene was not attached")
			elif not (visual as Node3D).scale.is_equal_approx(Vector3.ONE * 4.8):
				failures.append("Map prop disguise did not copy the spawned prop scale")
			if prop.collision_radius > 0.9:
				failures.append("Map prop collision radius should stay controlled even when visuals are large")
			if not player_collision or not player_collision.shape is CylinderShape3D:
				failures.append("Map prop disguise should keep the player collider in prop mode")

			var disguise_node := player.get_node_or_null("3DGodotRobot/PropDisguise") as Node3D
			if disguise_node:
				var base_y: float = player._prop_disguise_base_position.y
				player._adjust_prop_disguise_height(0.24)
				await get_tree().process_frame
				if absf(disguise_node.position.y - (base_y + 0.24)) > 0.01:
					failures.append("Prop disguise height adjustment did not move the disguise node")
				player.clear_prop_disguise()
				await get_tree().process_frame
				player.apply_prop_disguise(prop.get_disguise_preset())
				await get_tree().process_frame
				disguise_node = player.get_node_or_null("3DGodotRobot/PropDisguise") as Node3D
				if disguise_node and absf(player._prop_disguise_height_offset) > 0.01:
					failures.append("Prop disguise height did not reset after clearing disguise")

		prop.queue_free()
		watermelon.queue_free()
		pineapple.queue_free()
		player.queue_free()
		floor.queue_free()
		wall.queue_free()

	if failures.is_empty():
		print("[ShapeCombatPocTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ShapeCombatPocTest] " + failure)
		get_tree().quit(1)


func _find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D:
		return node as CollisionShape3D
	for child in node.get_children():
		var found := _find_collision_shape(child)
		if found:
			return found
	return null


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


func _find_first_animation_player(node: Node) -> AnimationPlayer:
	if not node:
		return null
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_first_animation_player(child)
		if found:
			return found
	return null


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


func _strongest_alpha_pixel(image: Image, center: Vector2, radius: int) -> Vector2:
	if not image:
		return Vector2(INF, INF)
	var min_x := clampi(floori(center.x) - radius, 0, image.get_width() - 1)
	var max_x := clampi(ceili(center.x) + radius, 0, image.get_width() - 1)
	var min_y := clampi(floori(center.y) - radius, 0, image.get_height() - 1)
	var max_y := clampi(ceili(center.y) + radius, 0, image.get_height() - 1)
	var strongest := 0.0
	var strongest_pixel := Vector2(INF, INF)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var alpha := image.get_pixel(x, y).a
			if alpha > strongest:
				strongest = alpha
				strongest_pixel = Vector2(float(x), float(y))
	return strongest_pixel


class SurfaceLockProbe:
	extends CamouflageSystem

	var update_count := 0

	func _update_surface_lock(screen_position: Vector2 = Vector2(-INF, -INF)) -> void:
		update_count += 1
		var resolved_screen := _resolve_screen_position(screen_position)
		_surface_lock = {
			"uv": Vector2(float(update_count), 0.0),
			"screen": resolved_screen,
			"position": Vector3.ZERO,
			"normal": Vector3.UP,
			"mesh_path": "PaintMesh",
			"surface": 0,
		}
		_surface_lock_mouse_position = resolved_screen


class NoColorProcessProbe:
	extends CamouflageSystem

	var update_count := 0

	func _update_surface_lock(screen_position: Vector2 = Vector2(-INF, -INF)) -> void:
		update_count += 1


class TextureRadiusProjectionProbe:
	extends MeshInstance3D


class BrushLockOrderOwner:
	extends CharacterBody3D

	var locked := false

	func set_camouflage_brush_locked(value: bool) -> void:
		locked = value


class ActivationWarmupOrderProbe:
	extends CamouflageSystem

	var warmup_called := false

	func _request_paintable_mesh_cache_warmup() -> void:
		warmup_called = true


class WarmupTargetProbe:
	extends CamouflageSystem

	var target_mesh: MeshInstance3D = null

	func _get_paintable_meshes() -> Array:
		if not target_mesh:
			return []
		return [{"mesh": target_mesh, "path": "WarmupPaintMesh"}]


class DirectTargetProjectionProbe:
	extends CamouflageSystem

	var paintable_mesh_query_count := 0
	var intersect_count := 0
	var last_target_surface := -99

	func _init() -> void:
		camouflage_owner = CharacterBody3D.new()
		camouflage_owner.name = "DirectTargetProbeOwner"
		var mesh := MeshInstance3D.new()
		mesh.name = "PaintMesh"
		mesh.mesh = BoxMesh.new()
		camouflage_owner.add_child(mesh)
		camera = Camera3D.new()
		camera.name = "ProbeCamera"
		camera.position = Vector3(0.0, 0.0, 4.0)
		camouflage_owner.add_child(camera)

	func _get_paintable_meshes() -> Array:
		paintable_mesh_query_count += 1
		return []

	func _intersect_mesh_triangles(
		mesh_instance: MeshInstance3D,
		mesh_path: String,
		ray_origin: Vector3,
		ray_dir: Vector3,
		allow_async_build: bool = false,
		target_surface: int = -1,
		screen_position: Vector2 = Vector2(INF, INF)
	) -> Dictionary:
		intersect_count += 1
		last_target_surface = target_surface
		return {
			"uv": Vector2(0.5, 0.5),
			"screen": Vector2(64.0, 64.0),
			"position": Vector3.ZERO,
			"normal": Vector3.UP,
			"mesh_path": mesh_path,
			"surface": target_surface,
			"distance": 1.0,
		}


class PaintProjectionProbe:
	extends CamouflageSystem

	var current_screen := Vector2.ZERO
	var submitted_batches: Array[Dictionary] = []
	var targeted_projection_count := 0
	var untargeted_projection_count := 0

	func _init() -> void:
		camouflage_owner = CharacterBody3D.new()
		camouflage_owner.name = "ProjectionProbeOwner"

	func _get_surface_lock(force_refresh: bool = false, screen_position: Vector2 = Vector2(-INF, -INF)) -> Dictionary:
		return _surface_for_screen(_probe_screen_position(screen_position))

	func _project_screen_to_body_surface(
		screen_position: Vector2,
		allow_async_build: bool = true,
		target_mesh_path: String = "",
		target_surface: int = -1
	) -> Dictionary:
		_metric_add("surface_projection_calls")
		if target_mesh_path.is_empty():
			untargeted_projection_count += 1
			_metric_add("untargeted_surface_projection_calls")
		else:
			targeted_projection_count += 1
			_metric_add("targeted_surface_projection_calls")
		return _surface_for_screen(screen_position)

	func _submit_brush_stroke_batch(
		uvs: PackedVector2Array,
		angle: float,
		world_positions: PackedVector3Array,
		world_normal: Vector3,
		target_mesh_path: String,
		target_surface: int,
		brush_radii: PackedFloat32Array = PackedFloat32Array(),
		uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
		uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
		uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array()
	) -> void:
		_metric_add("brush_batches_submitted")
		_metric_add("brush_stamps_submitted", uvs.size())
		submitted_batches.append({
			"uvs": uvs,
			"positions": world_positions,
			"mesh_path": target_mesh_path,
			"surface": target_surface,
			"radii": brush_radii,
			"uv_clip_triangles": uv_clip_triangles,
			"uv_clip_triangle_counts": uv_clip_triangle_counts,
			"uv_footprint_metrics": uv_footprint_metrics,
		})

	func _brush_screen_radius_to_world(world_position: Vector3, screen_radius: float) -> float:
		return screen_radius / 100.0

	func _probe_screen_position(screen_position: Vector2) -> Vector2:
		if screen_position.x > -INF and screen_position.x < INF and screen_position.y > -INF and screen_position.y < INF:
			return screen_position
		return current_screen

	func _surface_for_screen(screen_position: Vector2) -> Dictionary:
		var normalized_x := clampf(screen_position.x / 140.0, 0.0, 1.0)
		var center_uv := Vector2(normalized_x, 0.5)
		var uv_extent := 0.08
		var center_position := Vector3(normalized_x, 0.0, 0.0)
		return {
			"uv": center_uv,
			"screen": screen_position,
			"position": center_position,
			"normal": Vector3.UP,
			"angle": 0.0,
			"distance": normalized_x,
			"mesh_path": "PaintMesh",
			"surface": 0,
			"texture_radius": 73.0,
			"uv_footprint_metric": PackedFloat32Array([240.0, 0.0, 240.0]),
			"face_uv0": center_uv + Vector2(-uv_extent, -uv_extent),
			"face_uv1": center_uv + Vector2(uv_extent, -uv_extent),
			"face_uv2": center_uv + Vector2(-uv_extent, uv_extent),
			"world_v0": center_position + Vector3(-1.0, 0.0, -1.0),
			"world_v1": center_position + Vector3(1.0, 0.0, -1.0),
			"world_v2": center_position + Vector3(-1.0, 0.0, 1.0),
		}


class LeftClickPickProbe:
	extends PaintProjectionProbe

	var picked_positions: Array[Vector2] = []
	var force_empty_surface := false

	func _pick_color_at_mouse(screen_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
		picked_positions.append(screen_position)
		has_sampled_color = true
		brush_color = Color(0.44, 0.18, 0.9, 1.0)

	func _get_surface_lock(force_refresh: bool = false, screen_position: Vector2 = Vector2(-INF, -INF)) -> Dictionary:
		if force_empty_surface:
			return {}
		return super._get_surface_lock(force_refresh, screen_position)

	func _has_pending_mesh_hit_jobs() -> bool:
		return false


class ImpreciseSatelliteProjectionProbe:
	extends PaintProjectionProbe

	func _surface_for_screen(screen_position: Vector2) -> Dictionary:
		var center_screen := current_screen
		if screen_position.distance_to(center_screen) <= 0.001:
			return {
				"uv": Vector2(0.5, 0.5),
				"screen": screen_position,
				"position": Vector3.ZERO,
				"normal": Vector3.UP,
				"angle": 0.0,
				"distance": 0.0,
				"mesh_path": "PaintMesh",
				"surface": 0,
				"texture_radius": 73.0,
			}
		if screen_position.x > center_screen.x:
			return {
				"uv": Vector2(0.6, 0.5),
				"screen": screen_position,
				"position": Vector3(50.0, 0.0, 0.0),
				"normal": Vector3.UP,
				"angle": 0.0,
				"distance": 50.0,
				"mesh_path": "PaintMesh",
				"surface": 0,
				"texture_radius": 73.0,
			}
		return {
			"uv": Vector2(0.4, 0.5),
			"screen": screen_position,
			"position": Vector3(0.02, 0.0, 0.0),
			"normal": Vector3.DOWN,
			"angle": 0.0,
			"distance": 0.02,
			"mesh_path": "OtherBodyPart",
			"surface": 0,
			"texture_radius": 73.0,
		}


class SkewedLocalUvProjectionProbe:
	extends PaintProjectionProbe

	func _surface_for_screen(screen_position: Vector2) -> Dictionary:
		var surface := super._surface_for_screen(screen_position)
		var center_uv := Vector2(0.5, 0.5)
		surface["uv"] = center_uv
		surface["face_uv0"] = center_uv + Vector2(0.0, -0.40)
		surface["face_uv1"] = center_uv + Vector2(0.40, 0.40)
		surface["face_uv2"] = center_uv + Vector2(-0.40, 0.40)
		return surface


class PendingPaintProbe:
	extends CamouflageSystem

	var pending_jobs := false
	var submitted_batches: Array[Dictionary] = []

	func _init() -> void:
		camouflage_owner = CharacterBody3D.new()
		camouflage_owner.name = "PendingPaintProbeOwner"

	func _get_surface_lock(force_refresh: bool = false, screen_position: Vector2 = Vector2(-INF, -INF)) -> Dictionary:
		if pending_jobs:
			return {}
		return _ready_surface(screen_position)

	func _project_screen_to_body_surface(
		screen_position: Vector2,
		allow_async_build: bool = true,
		target_mesh_path: String = "",
		target_surface: int = -1
	) -> Dictionary:
		if pending_jobs:
			return {}
		return _ready_surface(screen_position)

	func _has_pending_mesh_hit_jobs() -> bool:
		return pending_jobs

	func _submit_brush_stroke_batch(
		uvs: PackedVector2Array,
		angle: float,
		world_positions: PackedVector3Array,
		world_normal: Vector3,
		target_mesh_path: String,
		target_surface: int,
		brush_radii: PackedFloat32Array = PackedFloat32Array(),
		uv_clip_triangles: PackedVector2Array = PackedVector2Array(),
		uv_clip_triangle_counts: PackedInt32Array = PackedInt32Array(),
		uv_footprint_metrics: PackedFloat32Array = PackedFloat32Array()
	) -> void:
		_metric_add("brush_batches_submitted")
		_metric_add("brush_stamps_submitted", uvs.size())
		submitted_batches.append({
			"uvs": uvs,
			"positions": world_positions,
			"mesh_path": target_mesh_path,
			"surface": target_surface,
			"radii": brush_radii,
			"uv_clip_triangles": uv_clip_triangles,
			"uv_clip_triangle_counts": uv_clip_triangle_counts,
			"uv_footprint_metrics": uv_footprint_metrics,
		})

	func _ready_surface(screen_position: Vector2 = Vector2(96.0, 128.0)) -> Dictionary:
		var screen := screen_position
		if not (screen.x > -INF and screen.x < INF and screen.y > -INF and screen.y < INF):
			screen = Vector2(96.0, 128.0)
		return {
			"uv": Vector2(clampf(screen.x / 256.0, 0.0, 1.0), clampf(screen.y / 256.0, 0.0, 1.0)),
			"screen": screen,
			"position": Vector3(0.2, 0.3, 0.4),
			"normal": Vector3.UP,
			"angle": 0.0,
			"distance": 1.0,
			"mesh_path": "PaintMesh",
			"surface": 0,
		}
