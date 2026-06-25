extends SceneTree

const DIRECTIONS: Dictionary = {
	"pp": Vector3(0.85, 0.55, 0.85),
	"np": Vector3(-0.85, 0.55, 0.85),
	"pn": Vector3(0.85, 0.55, -0.85),
	"nn": Vector3(-0.85, 0.55, -0.85),
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var options: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var scene_path: String = String(options.get("scene", ""))
	var out_dir: String = String(options.get("out", ""))
	var labels_csv: String = String(options.get("directions", "pp,np,pn,nn"))
	var angles_csv: String = String(options.get("angles", ""))
	var prefix: String = String(options.get("prefix", "polygon_apocalypse"))
	var map_id: String = String(options.get("map-id", prefix))
	if scene_path.is_empty() or out_dir.is_empty():
		push_error("Usage: godot --path . --script tools/capture_polygon_apocalypse_views.gd -- --scene=res://... --out=C:/... [--directions=pp,np,pn,nn] [--prefix=name]")
		quit(2)
		return

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("Could not load scene: %s" % scene_path)
		quit(3)
		return

	var scene: Node = packed.instantiate()
	get_root().add_child(scene)
	get_root().size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	await process_frame
	_hide_external_ui(scene)
	_apply_visual_overrides(scene, options)

	var generated: Node = scene.get_node_or_null("GeneratedPolygonApocalypseMap")
	if generated == null:
		await process_frame
		generated = scene.get_node_or_null("GeneratedPolygonApocalypseMap")
	var layout: Node3D = generated.get_node_or_null("PolygonApocalypseLayout") as Node3D if generated != null else null
	if layout == null:
		push_error("Missing GeneratedPolygonApocalypseMap/PolygonApocalypseLayout in %s" % scene_path)
		quit(4)
		return

	var bounds: AABB = _bounds_from_sector_meta(layout) if options.has("prefer-sector-bounds") else AABB()
	if bounds.size == Vector3.ZERO:
		bounds = _bounds_from_unity_audit(options, map_id)
	if bounds.size == Vector3.ZERO:
		bounds = _calculate_bounds(layout)
	var center: Vector3 = bounds.get_center()
	if options.has("mirror-x-around-bounds"):
		_mirror_x_around_center(generated as Node3D, center.x)
	if options.has("conjugate-mirror-x-around-bounds"):
		_conjugate_mirror_generated_x(generated as Node3D, center.x)
	var max_size: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if max_size <= 0.01:
		max_size = 10.0
	var distance_scale: float = String(options.get("distance-scale", "1.35")).to_float()

	DirAccess.make_dir_recursive_absolute(out_dir)
	var captures: Array[Dictionary] = _build_capture_directions(labels_csv, angles_csv)
	for capture_data: Dictionary in captures:
		var label: String = String(capture_data.get("label", ""))
		var direction: Vector3 = (capture_data.get("direction", Vector3.ZERO) as Vector3).normalized()
		if direction == Vector3.ZERO:
			push_warning("Direction label produced zero vector and was skipped: %s" % label)
			continue
		var camera: Camera3D = Camera3D.new()
		camera.name = "RuntimeAuditCamera_%s" % label
		camera.fov = 45.0
		camera.near = 0.01
		camera.far = 5000.0
		scene.add_child(camera)
		camera.current = true
		var pos: Vector3 = center + direction * max_size * distance_scale
		camera.look_at_from_position(pos, center, Vector3.UP)
		await process_frame
		await process_frame
		var image: Image = get_root().get_texture().get_image()
		if options.has("flip-x-output"):
			image.flip_x()
		if options.has("flip-y-output"):
			image.flip_y()
		var output_path: String = "%s/%s_%s.png" % [out_dir.rstrip("/").rstrip("\\"), prefix, label]
		var err: Error = image.save_png(output_path)
		if err != OK:
			push_error("Failed to save %s: %s" % [output_path, error_string(err)])
			quit(5)
			return
		print("saved=%s center=%s size=%s" % [output_path, str(center), str(bounds.size)])
		camera.queue_free()
		await process_frame

	scene.queue_free()
	await process_frame
	quit(0)

func _build_capture_directions(labels_csv: String, angles_csv: String) -> Array[Dictionary]:
	var captures: Array[Dictionary] = []
	for raw_label: String in labels_csv.split(",", false):
		var label: String = raw_label.strip_edges()
		if not DIRECTIONS.has(label):
			push_warning("Unknown direction label skipped: %s" % label)
			continue
		captures.append({
			"label": label,
			"direction": DIRECTIONS[label],
		})
	for raw_angle: String in angles_csv.split(",", false):
		var value: String = raw_angle.strip_edges()
		if value.is_empty():
			continue
		var angle_degrees: float = value.to_float()
		var radians: float = deg_to_rad(angle_degrees)
		var horizontal_radius: float = sqrt(0.85 * 0.85 + 0.85 * 0.85)
		captures.append({
			"label": "a%03d" % int(round(angle_degrees)) if angle_degrees >= 0.0 else "am%03d" % int(round(absf(angle_degrees))),
			"direction": Vector3(cos(radians) * horizontal_radius, 0.55, sin(radians) * horizontal_radius),
		})
	return captures

func _parse_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for arg: String in args:
		if not arg.begins_with("--"):
			continue
		var body: String = arg.substr(2)
		var split_at: int = body.find("=")
		if split_at == -1:
			result[body] = "true"
		else:
			result[body.substr(0, split_at)] = body.substr(split_at + 1)
	return result

func _apply_visual_overrides(scene: Node, options: Dictionary) -> void:
	if options.has("background"):
		var color: Color = _color_from_csv(String(options["background"]), Color(0.22, 0.22, 0.22, 1.0))
		_apply_environment_value(scene, "background_color", color)
	if options.has("tonemap"):
		_apply_environment_value(scene, "tonemap_mode", _tonemap_from_name(String(options["tonemap"])))
	if options.has("exposure"):
		_apply_environment_value(scene, "tonemap_exposure", String(options["exposure"]).to_float())
	if options.has("ambient-energy"):
		_apply_environment_value(scene, "ambient_light_energy", String(options["ambient-energy"]).to_float())
	if options.has("light-energy-min"):
		_apply_light_energy_min(scene, String(options["light-energy-min"]).to_float())
	if options.has("light-energy-scale"):
		_apply_light_energy_scale(scene, String(options["light-energy-scale"]).to_float())
	if options.has("directional-light-energy"):
		_apply_directional_light_energy(scene, String(options["directional-light-energy"]).to_float())
	if options.has("directional-light-shadows"):
		_apply_directional_light_shadows(scene, _bool_from_string(String(options["directional-light-shadows"])))
	if options.has("light-shadows"):
		_apply_light_shadows(scene, _bool_from_string(String(options["light-shadows"])))
	if options.has("directional-light-look-from"):
		var light_offset: Vector3 = _vector3_from_csv(String(options["directional-light-look-from"]), Vector3.ZERO)
		_apply_directional_light_look_from(scene, light_offset)
	if options.has("material-tint"):
		var tint: Color = _color_from_csv(String(options["material-tint"]), Color.WHITE)
		_apply_material_tint(scene, tint)
	if options.has("normal-maps"):
		_apply_normal_maps_enabled(scene, _bool_from_string(String(options["normal-maps"])))
	if options.has("roughness-override"):
		_apply_roughness_override(scene, String(options["roughness-override"]).to_float())
	if options.has("metallic-override"):
		_apply_metallic_override(scene, String(options["metallic-override"]).to_float())
	if options.has("name-material-tint") and options.has("name-material-tint-color"):
		var name_tint: Color = _color_from_csv(String(options["name-material-tint-color"]), Color.WHITE)
		var tinted_by_name: int = _tint_materials_below_name_contains(scene, String(options["name-material-tint"]), name_tint)
		print("tinted_by_name=%d pattern=%s tint=%s" % [tinted_by_name, String(options["name-material-tint"]), str(name_tint)])
	if options.has("material-name-tint") and options.has("material-name-tint-color"):
		var material_name_tint: Color = _color_from_csv(String(options["material-name-tint-color"]), Color.WHITE)
		var tinted_by_material_name: int = _tint_materials_by_material_name_contains(scene, String(options["material-name-tint"]), material_name_tint)
		print("tinted_by_material_name=%d pattern=%s tint=%s" % [tinted_by_material_name, String(options["material-name-tint"]), str(material_name_tint)])
	if options.has("name-material-blend-mode") and options.has("name-material-blend-mode-value"):
		var blend_mode: int = _blend_mode_from_name(String(options["name-material-blend-mode-value"]))
		var blended_by_name: int = _set_blend_mode_below_name_contains(scene, String(options["name-material-blend-mode"]), blend_mode)
		print("blended_by_name=%d pattern=%s mode=%s" % [blended_by_name, String(options["name-material-blend-mode"]), String(options["name-material-blend-mode-value"])])
	if options.has("name-material-alpha") and options.has("name-material-alpha-value"):
		var alpha_value: float = String(options["name-material-alpha-value"]).to_float()
		var alpha_by_name: int = _set_alpha_below_name_contains(scene, String(options["name-material-alpha"]), alpha_value)
		print("alpha_by_name=%d pattern=%s alpha=%f" % [alpha_by_name, String(options["name-material-alpha"]), alpha_value])
	if options.has("name-material-render-priority") and options.has("name-material-render-priority-value"):
		var priority_by_name: int = _set_render_priority_below_name_contains(scene, String(options["name-material-render-priority"]), String(options["name-material-render-priority-value"]).to_int())
		print("render_priority_by_name=%d pattern=%s priority=%s" % [priority_by_name, String(options["name-material-render-priority"]), String(options["name-material-render-priority-value"])])
	if options.has("material-name-render-priority") and options.has("material-name-render-priority-value"):
		var priority_by_material_name: int = _set_render_priority_by_material_name_contains(scene, String(options["material-name-render-priority"]), String(options["material-name-render-priority-value"]).to_int())
		print("render_priority_by_material_name=%d pattern=%s priority=%s" % [priority_by_material_name, String(options["material-name-render-priority"]), String(options["material-name-render-priority-value"])])
	if options.has("name-material-depth-draw-mode") and options.has("name-material-depth-draw-mode-value"):
		var depth_by_name: int = _set_depth_draw_mode_below_name_contains(scene, String(options["name-material-depth-draw-mode"]), _depth_draw_mode_from_name(String(options["name-material-depth-draw-mode-value"])))
		print("depth_draw_by_name=%d pattern=%s mode=%s" % [depth_by_name, String(options["name-material-depth-draw-mode"]), String(options["name-material-depth-draw-mode-value"])])
	if options.has("material-name-depth-draw-mode") and options.has("material-name-depth-draw-mode-value"):
		var depth_by_material_name: int = _set_depth_draw_mode_by_material_name_contains(scene, String(options["material-name-depth-draw-mode"]), _depth_draw_mode_from_name(String(options["material-name-depth-draw-mode-value"])))
		print("depth_draw_by_material_name=%d pattern=%s mode=%s" % [depth_by_material_name, String(options["material-name-depth-draw-mode"]), String(options["material-name-depth-draw-mode-value"])])
	if options.has("hide-name-contains"):
		var hidden_by_name: int = _hide_nodes_by_name_contains(scene, String(options["hide-name-contains"]))
		print("hidden_by_name=%d pattern=%s" % [hidden_by_name, String(options["hide-name-contains"])])
	if options.has("hide-material-name-contains"):
		var hidden_by_material: int = _hide_meshes_by_material_name_contains(scene, String(options["hide-material-name-contains"]))
		print("hidden_by_material=%d pattern=%s" % [hidden_by_material, String(options["hide-material-name-contains"])])

func _apply_environment_value(scene: Node, property_name: String, value: Variant) -> void:
	var environments: Array[WorldEnvironment] = []
	_find_environments(scene, environments)
	for environment_node: WorldEnvironment in environments:
		if environment_node.environment:
			environment_node.environment.set(property_name, value)

func _tonemap_from_name(value: String) -> int:
	match value.to_lower():
		"reinhardt":
			return Environment.TONE_MAPPER_REINHARDT
		"filmic":
			return Environment.TONE_MAPPER_FILMIC
		"aces":
			return Environment.TONE_MAPPER_ACES
		"agx":
			return Environment.TONE_MAPPER_AGX
		_:
			return Environment.TONE_MAPPER_LINEAR

func _find_environments(node: Node, result: Array[WorldEnvironment]) -> void:
	if node is WorldEnvironment:
		result.append(node as WorldEnvironment)
	for child: Node in node.get_children():
		_find_environments(child, result)

func _apply_light_energy_min(node: Node, minimum_energy: float) -> void:
	if node is Light3D:
		var light: Light3D = node as Light3D
		light.light_energy = maxf(light.light_energy, minimum_energy)
	for child: Node in node.get_children():
		_apply_light_energy_min(child, minimum_energy)

func _apply_light_energy_scale(node: Node, scale: float) -> void:
	if node is Light3D:
		var light: Light3D = node as Light3D
		light.light_energy *= scale
	for child: Node in node.get_children():
		_apply_light_energy_scale(child, scale)

func _apply_directional_light_energy(node: Node, energy: float) -> void:
	if node is DirectionalLight3D:
		var light: DirectionalLight3D = node as DirectionalLight3D
		light.light_energy = energy
	for child: Node in node.get_children():
		_apply_directional_light_energy(child, energy)

func _apply_directional_light_shadows(node: Node, enabled: bool) -> void:
	if node is DirectionalLight3D:
		var light: DirectionalLight3D = node as DirectionalLight3D
		light.shadow_enabled = enabled
	for child: Node in node.get_children():
		_apply_directional_light_shadows(child, enabled)

func _apply_light_shadows(node: Node, enabled: bool) -> void:
	if node is Light3D:
		var light: Light3D = node as Light3D
		light.shadow_enabled = enabled
	for child: Node in node.get_children():
		_apply_light_shadows(child, enabled)

func _apply_directional_light_look_from(scene: Node, offset: Vector3) -> void:
	if offset == Vector3.ZERO:
		return
	var layout: Node3D = scene.get_node_or_null("GeneratedPolygonApocalypseMap/PolygonApocalypseLayout") as Node3D
	if layout == null:
		return
	var bounds: AABB = _calculate_bounds(layout)
	if bounds.size == Vector3.ZERO:
		return
	var center: Vector3 = bounds.get_center()
	var max_size: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	_set_directional_light_look_from(scene, center, offset.normalized() * max_size)

func _set_directional_light_look_from(node: Node, center: Vector3, offset: Vector3) -> void:
	if node is DirectionalLight3D:
		var light: DirectionalLight3D = node as DirectionalLight3D
		light.look_at_from_position(center + offset, center, Vector3.UP)
	for child: Node in node.get_children():
		_set_directional_light_look_from(child, center, offset)

func _apply_material_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.albedo_color = variant.albedo_color * tint
					if variant.emission_enabled:
						variant.emission = variant.emission * tint
					mesh_instance.set_surface_override_material(surface_index, variant)
	for child: Node in node.get_children():
		_apply_material_tint(child, tint)

func _apply_normal_maps_enabled(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.normal_enabled = enabled
					mesh_instance.set_surface_override_material(surface_index, variant)
	for child: Node in node.get_children():
		_apply_normal_maps_enabled(child, enabled)

func _apply_roughness_override(node: Node, roughness: float) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.roughness = clampf(roughness, 0.0, 1.0)
					mesh_instance.set_surface_override_material(surface_index, variant)
	for child: Node in node.get_children():
		_apply_roughness_override(child, roughness)

func _apply_metallic_override(node: Node, metallic: float) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.metallic = clampf(metallic, 0.0, 1.0)
					mesh_instance.set_surface_override_material(surface_index, variant)
	for child: Node in node.get_children():
		_apply_metallic_override(child, metallic)

func _tint_materials_below_name_contains(node: Node, patterns_csv: String, tint: Color) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var tinted_count: int = 0
	if node is Node3D and _string_matches_any_pattern(String(node.name), patterns):
		tinted_count += _tint_materials_in_subtree(node, tint)
	for child: Node in node.get_children():
		tinted_count += _tint_materials_below_name_contains(child, patterns_csv, tint)
	return tinted_count

func _tint_materials_in_subtree(node: Node, tint: Color) -> int:
	var tinted_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.albedo_color = variant.albedo_color * tint
					if variant.emission_enabled:
						variant.emission = variant.emission * tint
					mesh_instance.set_surface_override_material(surface_index, variant)
					tinted_count += 1
	for child: Node in node.get_children():
		tinted_count += _tint_materials_in_subtree(child, tint)
	return tinted_count

func _tint_materials_by_material_name_contains(node: Node, patterns_csv: String, tint: Color) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var tinted_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface_index)
				if material is StandardMaterial3D and _material_matches_any_pattern(material, patterns):
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.albedo_color = variant.albedo_color * tint
					if variant.emission_enabled:
						variant.emission = variant.emission * tint
					mesh_instance.set_surface_override_material(surface_index, variant)
					tinted_count += 1
	for child: Node in node.get_children():
		tinted_count += _tint_materials_by_material_name_contains(child, patterns_csv, tint)
	return tinted_count

func _blend_mode_from_name(value: String) -> int:
	match value.to_lower():
		"add":
			return BaseMaterial3D.BLEND_MODE_ADD
		"sub":
			return BaseMaterial3D.BLEND_MODE_SUB
		"mul":
			return BaseMaterial3D.BLEND_MODE_MUL
		_:
			return BaseMaterial3D.BLEND_MODE_MIX

func _set_blend_mode_below_name_contains(node: Node, patterns_csv: String, blend_mode: int) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var changed_count: int = 0
	if node is Node3D and _string_matches_any_pattern(String(node.name), patterns):
		changed_count += _set_blend_mode_in_subtree(node, blend_mode)
	for child: Node in node.get_children():
		changed_count += _set_blend_mode_below_name_contains(child, patterns_csv, blend_mode)
	return changed_count

func _set_blend_mode_in_subtree(node: Node, blend_mode: int) -> int:
	var changed_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.blend_mode = blend_mode as BaseMaterial3D.BlendMode
					mesh_instance.set_surface_override_material(surface_index, variant)
					changed_count += 1
	for child: Node in node.get_children():
		changed_count += _set_blend_mode_in_subtree(child, blend_mode)
	return changed_count

func _set_alpha_below_name_contains(node: Node, patterns_csv: String, alpha_value: float) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var changed_count: int = 0
	if node is Node3D and _string_matches_any_pattern(String(node.name), patterns):
		changed_count += _set_alpha_in_subtree(node, alpha_value)
	for child: Node in node.get_children():
		changed_count += _set_alpha_below_name_contains(child, patterns_csv, alpha_value)
	return changed_count

func _set_alpha_in_subtree(node: Node, alpha_value: float) -> int:
	var changed_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.albedo_color.a = clampf(alpha_value, 0.0, 1.0)
					variant.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if variant.albedo_color.a < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
					mesh_instance.set_surface_override_material(surface_index, variant)
					changed_count += 1
	for child: Node in node.get_children():
		changed_count += _set_alpha_in_subtree(child, alpha_value)
	return changed_count

func _set_render_priority_below_name_contains(node: Node, patterns_csv: String, priority: int) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var changed_count: int = 0
	if node is Node3D and _string_matches_any_pattern(String(node.name), patterns):
		changed_count += _set_render_priority_in_subtree(node, priority)
	for child: Node in node.get_children():
		changed_count += _set_render_priority_below_name_contains(child, patterns_csv, priority)
	return changed_count

func _set_render_priority_in_subtree(node: Node, priority: int) -> int:
	var changed_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.render_priority = clampi(priority, -128, 127)
					mesh_instance.set_surface_override_material(surface_index, variant)
					changed_count += 1
	for child: Node in node.get_children():
		changed_count += _set_render_priority_in_subtree(child, priority)
	return changed_count

func _set_render_priority_by_material_name_contains(node: Node, patterns_csv: String, priority: int) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var changed_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface_index)
				if material is StandardMaterial3D and _material_matches_any_pattern(material, patterns):
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.render_priority = clampi(priority, -128, 127)
					mesh_instance.set_surface_override_material(surface_index, variant)
					changed_count += 1
	for child: Node in node.get_children():
		changed_count += _set_render_priority_by_material_name_contains(child, patterns_csv, priority)
	return changed_count

func _depth_draw_mode_from_name(value: String) -> int:
	match value.to_lower():
		"always":
			return BaseMaterial3D.DEPTH_DRAW_ALWAYS
		"disabled", "never":
			return BaseMaterial3D.DEPTH_DRAW_DISABLED
		_:
			return BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

func _set_depth_draw_mode_below_name_contains(node: Node, patterns_csv: String, depth_draw_mode: int) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var changed_count: int = 0
	if node is Node3D and _string_matches_any_pattern(String(node.name), patterns):
		changed_count += _set_depth_draw_mode_in_subtree(node, depth_draw_mode)
	for child: Node in node.get_children():
		changed_count += _set_depth_draw_mode_below_name_contains(child, patterns_csv, depth_draw_mode)
	return changed_count

func _set_depth_draw_mode_in_subtree(node: Node, depth_draw_mode: int) -> int:
	var changed_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.depth_draw_mode = depth_draw_mode as BaseMaterial3D.DepthDrawMode
					mesh_instance.set_surface_override_material(surface_index, variant)
					changed_count += 1
	for child: Node in node.get_children():
		changed_count += _set_depth_draw_mode_in_subtree(child, depth_draw_mode)
	return changed_count

func _set_depth_draw_mode_by_material_name_contains(node: Node, patterns_csv: String, depth_draw_mode: int) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var changed_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var material: Material = mesh_instance.get_surface_override_material(surface_index)
				if material == null:
					material = mesh_instance.mesh.surface_get_material(surface_index)
				if material is StandardMaterial3D and _material_matches_any_pattern(material, patterns):
					var variant: StandardMaterial3D = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.depth_draw_mode = depth_draw_mode as BaseMaterial3D.DepthDrawMode
					mesh_instance.set_surface_override_material(surface_index, variant)
					changed_count += 1
	for child: Node in node.get_children():
		changed_count += _set_depth_draw_mode_by_material_name_contains(child, patterns_csv, depth_draw_mode)
	return changed_count

func _hide_nodes_by_name_contains(node: Node, patterns_csv: String) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var hidden_count: int = 0
	if node is Node3D and _string_matches_any_pattern(String(node.name), patterns):
		(node as Node3D).visible = false
		hidden_count += 1
	for child: Node in node.get_children():
		hidden_count += _hide_nodes_by_name_contains(child, patterns_csv)
	return hidden_count

func _hide_meshes_by_material_name_contains(node: Node, patterns_csv: String) -> int:
	var patterns: PackedStringArray = patterns_csv.split(",", false)
	var hidden_count: int = 0
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh and _mesh_has_material_matching(mesh_instance, patterns):
			mesh_instance.visible = false
			hidden_count += 1
	for child: Node in node.get_children():
		hidden_count += _hide_meshes_by_material_name_contains(child, patterns_csv)
	return hidden_count

func _mesh_has_material_matching(mesh_instance: MeshInstance3D, patterns: PackedStringArray) -> bool:
	if mesh_instance.mesh == null:
		return false
	for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
		var material: Material = mesh_instance.get_surface_override_material(surface_index)
		if material == null:
			material = mesh_instance.mesh.surface_get_material(surface_index)
		if material == null:
			continue
		if _string_matches_any_pattern(String(material.resource_name), patterns):
			return true
		if _string_matches_any_pattern(String(material.resource_path), patterns):
			return true
	return false

func _material_matches_any_pattern(material: Material, patterns: PackedStringArray) -> bool:
	if _string_matches_any_pattern(String(material.resource_name), patterns):
		return true
	if _string_matches_any_pattern(String(material.resource_path), patterns):
		return true
	return false

func _string_matches_any_pattern(value: String, patterns: PackedStringArray) -> bool:
	var lowered_value: String = value.to_lower()
	for raw_pattern: String in patterns:
		var pattern: String = raw_pattern.strip_edges().to_lower()
		if pattern.is_empty():
			continue
		if lowered_value.contains(pattern):
			return true
	return false

func _color_from_csv(value: String, fallback: Color) -> Color:
	var parts: PackedStringArray = value.split(",", false)
	if parts.size() < 3:
		return fallback
	var alpha: float = parts[3].to_float() if parts.size() >= 4 else fallback.a
	return Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float(), alpha)

func _vector3_from_csv(value: String, fallback: Vector3) -> Vector3:
	var parts: PackedStringArray = value.split(",", false)
	if parts.size() < 3:
		return fallback
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())

func _bool_from_string(value: String) -> bool:
	match value.strip_edges().to_lower():
		"false", "0", "no", "off":
			return false
		_:
			return true

func _mirror_x_around_center(node: Node3D, center_x: float) -> void:
	if node == null:
		return
	node.scale.x *= -1.0
	node.position.x = 2.0 * center_x - node.position.x

func _conjugate_mirror_generated_x(generated: Node3D, center_x: float) -> void:
	if generated == null:
		return
	var layout: Node = generated.get_node_or_null("PolygonApocalypseLayout")
	if layout != null:
		for child: Node in layout.get_children():
			if child is Node3D:
				_conjugate_mirror_node_x(child as Node3D, center_x)
	var lights: Node = generated.get_node_or_null("PolygonApocalypseLights")
	if lights != null:
		for child: Node in lights.get_children():
			if child is Node3D:
				_conjugate_mirror_node_x(child as Node3D, center_x)

func _conjugate_mirror_node_x(node: Node3D, center_x: float) -> void:
	var transform: Transform3D = node.global_transform
	var basis: Basis = transform.basis
	var x_col: Vector3 = basis.x
	var y_col: Vector3 = basis.y
	var z_col: Vector3 = basis.z
	var mirrored_basis := Basis(
		Vector3(x_col.x, -x_col.y, -x_col.z),
		Vector3(-y_col.x, y_col.y, y_col.z),
		Vector3(-z_col.x, z_col.y, z_col.z)
	)
	var origin: Vector3 = transform.origin
	origin.x = 2.0 * center_x - origin.x
	node.global_transform = Transform3D(mirrored_basis, origin)

func _bounds_from_unity_audit(options: Dictionary, map_id: String) -> AABB:
	var audit_path: String = String(options.get("unity-audit", ""))
	if audit_path.is_empty() or not FileAccess.file_exists(audit_path):
		return AABB()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(audit_path))
	if not parsed is Dictionary:
		return AABB()
	var scenes: Variant = (parsed as Dictionary).get("scenes", [])
	if not scenes is Array:
		return AABB()
	for scene_entry: Variant in scenes as Array:
		if not scene_entry is Dictionary:
			continue
		var scene: Dictionary = scene_entry as Dictionary
		if String(scene.get("map_id", "")) != map_id:
			continue
		var bounds_data: Variant = scene.get("bounds", {})
		if not bounds_data is Dictionary:
			return AABB()
		var center: Vector3 = _vector3_from_array((bounds_data as Dictionary).get("center", []))
		var size: Vector3 = _vector3_from_array((bounds_data as Dictionary).get("size", []))
		return AABB(center - size * 0.5, size)
	return AABB()

func _bounds_from_sector_meta(layout: Node3D) -> AABB:
	if not layout.has_meta("sector_bounds"):
		return AABB()
	var bounds_value: Variant = layout.get_meta("sector_bounds")
	if not bounds_value is Array or (bounds_value as Array).size() < 4:
		return AABB()
	var bounds := bounds_value as Array
	var min_x := float(bounds[0])
	var max_x := float(bounds[1])
	var min_z := float(bounds[2])
	var max_z := float(bounds[3])
	if min_x >= max_x or min_z >= max_z:
		return AABB()
	return AABB(
		Vector3(min_x, -25.0, min_z),
		Vector3(max_x - min_x, 95.0, max_z - min_z)
	)

func _hide_external_ui(captured_scene: Node) -> void:
	for child: Node in get_root().get_children():
		if child == captured_scene:
			continue
		_hide_canvas_items(child)

func _hide_canvas_items(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	for child: Node in node.get_children():
		_hide_canvas_items(child)

func _vector3_from_array(value: Variant) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func _calculate_bounds(root_node: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(root_node, meshes)
	var has_bounds: bool = false
	var bounds: AABB = AABB()
	for mesh_instance: MeshInstance3D in meshes:
		if mesh_instance.mesh == null:
			continue
		var box: AABB = _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = box
			has_bounds = true
		else:
			bounds = bounds.merge(box)
	return bounds if has_bounds else AABB()

func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_find_meshes(child, result)

func _transform_aabb(world_transform: Transform3D, box: AABB) -> AABB:
	var min_corner: Vector3 = Vector3(INF, INF, INF)
	var max_corner: Vector3 = Vector3(-INF, -INF, -INF)
	for x: float in [0.0, 1.0]:
		for y: float in [0.0, 1.0]:
			for z: float in [0.0, 1.0]:
				var point: Vector3 = box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed: Vector3 = world_transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)
