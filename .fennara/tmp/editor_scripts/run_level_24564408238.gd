@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	ctx.log("root=%s class=%s" % [String(root.name), root.get_class()])

	var environment_node: Node = ctx.get_node_or_null("Environment")
	if environment_node == null:
		ctx.error("Environment node not found")
		return

	var world_node: WorldEnvironment = ctx.get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
	if world_node == null:
		ctx.error("Environment/WorldEnvironment not found")
		return
	var env: Environment = world_node.environment
	if env == null:
		env = Environment.new()
		world_node.environment = env
		ctx.log("Created missing Environment resource")

	ctx.log("before ambient_source=%s ambient=%s energy=%.3f exposure=%.3f white=%.3f" % [str(env.ambient_light_source), str(env.ambient_light_color), env.ambient_light_energy, env.tonemap_exposure, env.tonemap_white])
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.64, 0.76, 0.88, 1.0)
	env.ambient_light_energy = 0.74
	env.ambient_light_sky_contribution = 0.12
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.tonemap_white = 2.20
	env.glow_enabled = true
	env.glow_intensity = 0.30
	env.glow_strength = 0.10
	env.glow_bloom = 0.025
	env.glow_hdr_threshold = 0.72
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.42, 0.55, 1.0)
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.18
	env.fog_sky_affect = 0.10
	ctx.log("after ambient_source=%s ambient=%s energy=%.3f exposure=%.3f white=%.3f" % [str(env.ambient_light_source), str(env.ambient_light_color), env.ambient_light_energy, env.tonemap_exposure, env.tonemap_white])

	if env.sky != null and env.sky.sky_material is ShaderMaterial:
		var sky_material: ShaderMaterial = env.sky.sky_material as ShaderMaterial
		var before_top: Variant = sky_material.get_shader_parameter("top_color")
		var before_bottom: Variant = sky_material.get_shader_parameter("bottom_color")
		sky_material.set_shader_parameter("top_color", Color(0.10, 0.15, 0.34, 1.0))
		sky_material.set_shader_parameter("bottom_color", Color(0.46, 0.38, 0.52, 1.0))
		sky_material.set_shader_parameter("moon_direction", Vector3(-0.82, 0.74, 0.76))
		ctx.log("sky top %s -> %s" % [str(before_top), str(sky_material.get_shader_parameter("top_color"))])
		ctx.log("sky bottom %s -> %s" % [str(before_bottom), str(sky_material.get_shader_parameter("bottom_color"))])
	else:
		ctx.log("Sky material missing or not ShaderMaterial; skipped sky color tuning")

	var key_light: DirectionalLight3D = ctx.get_node_or_null("Environment/DirectionalLight3D") as DirectionalLight3D
	if key_light != null:
		ctx.log("key before color=%s energy=%.3f blur=%.3f" % [str(key_light.light_color), key_light.light_energy, key_light.shadow_blur])
		key_light.light_color = Color(1.0, 0.91, 0.78, 1.0)
		key_light.light_energy = 0.90
		key_light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
		key_light.shadow_enabled = true
		key_light.shadow_blur = 1.35
		key_light.directional_shadow_max_distance = 80.0
		ctx.log("key after color=%s energy=%.3f blur=%.3f" % [str(key_light.light_color), key_light.light_energy, key_light.shadow_blur])
	else:
		ctx.log("Key DirectionalLight3D missing; skipped")

	var fill_light: DirectionalLight3D = ctx.get_node_or_null("Environment/ToyWorldFillLight") as DirectionalLight3D
	if fill_light == null:
		fill_light = DirectionalLight3D.new()
		fill_light.name = "ToyWorldFillLight"
		environment_node.add_child(fill_light)
		ctx.own(fill_light)
		ctx.log("Created ToyWorldFillLight")
	fill_light.rotation_degrees = Vector3(-24.0, 138.0, 0.0)
	fill_light.light_color = Color(0.62, 0.78, 0.96, 1.0)
	fill_light.light_energy = 0.22
	fill_light.shadow_enabled = false
	fill_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY

	var floor_mesh: MeshInstance3D = ctx.get_node_or_null("Environment/Floor/MeshInstance3D") as MeshInstance3D
	if floor_mesh != null:
		var mat: Material = floor_mesh.get_surface_override_material(0)
		var std: StandardMaterial3D = mat as StandardMaterial3D
		if std == null:
			std = StandardMaterial3D.new()
			std.resource_name = "SoftPlaygroundFloorMaterial"
			floor_mesh.set_surface_override_material(0, std)
		ctx.log("floor before albedo=%s" % str(std.albedo_color))
		std.albedo_color = Color(0.16, 0.45, 0.36, 1.0)
		std.roughness = 0.86
		std.metallic = 0.0
		std.metallic_specular = 0.24
		ctx.log("floor after albedo=%s roughness=%.3f spec=%.3f" % [str(std.albedo_color), std.roughness, std.metallic_specular])
	else:
		ctx.log("Floor mesh not found; skipped floor material tuning")

	ctx.mark_modified()
