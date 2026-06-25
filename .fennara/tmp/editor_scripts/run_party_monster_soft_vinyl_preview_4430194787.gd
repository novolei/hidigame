@tool
extends RefCounted

const SKIN_SCENE_PATH := "res://assets/characters/party_monster/party_monster_skin.tscn"

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterSoftVinylPreview"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created preview root")
	else:
		ctx.clear_children(root)
		ctx.log("Cleared preview root")

	var root_3d: Node3D = root as Node3D
	if root_3d == null:
		ctx.error("Preview root is not Node3D")
		return

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.name = "SoftVinylWorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.66, 0.64, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.96, 0.91, 0.84, 1.0)
	env.ambient_light_energy = 0.92
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.98
	env.tonemap_white = 2.10
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.66, 0.80, 0.78, 1.0)
	env.fog_density = 0.028
	env.fog_depth_begin = 3.4
	env.fog_depth_end = 8.5
	environment_node.environment = env
	root_3d.add_child(environment_node)
	ctx.own(environment_node)

	var stage: Node3D = Node3D.new()
	stage.name = "StudioStage"
	root_3d.add_child(stage)
	ctx.own(stage)

	_add_platform(ctx, stage)
	_add_backdrop_cards(ctx, stage)

	var default_skin: Node3D = ctx.instance_scene(stage, SKIN_SCENE_PATH, "DefaultSoftVinylPM01") as Node3D
	if default_skin != null:
		default_skin.call("set_character_model_id", "party_monster_c01")
		_fit_model_to_stage(default_skin, Vector3(-0.58, 0.064, 0.0), 1.44, 1.08)
		default_skin.rotation_degrees = Vector3(0.0, 13.0, 0.0)
		ctx.log("Instanced party_monster_c01")

	var mask_skin: Node3D = ctx.instance_scene(stage, SKIN_SCENE_PATH, "TintSoftVinylPM01") as Node3D
	if mask_skin != null:
		mask_skin.call("set_character_model_id", "party_monster_masktint01")
		_fit_model_to_stage(mask_skin, Vector3(0.58, 0.064, 0.0), 1.44, 1.08)
		mask_skin.rotation_degrees = Vector3(0.0, -13.0, 0.0)
		ctx.log("Instanced party_monster_masktint01")

	_add_lights(ctx, stage)
	_add_camera(ctx, stage)
	ctx.mark_modified()
	ctx.log("Soft vinyl preview rebuilt with tuned teal background and lower exposure")


func _add_platform(ctx, stage: Node3D) -> void:
	var shadow_mat: StandardMaterial3D = _make_material(Color(0.045, 0.055, 0.060, 0.34), 0.06, 0.88, Color(0.0, 0.0, 0.0, 1.0), 0.0, true)
	_add_disc(ctx, stage, "SoftPlatformShadow", 1.42, 0.012, -0.124, shadow_mat)
	var base_mat: StandardMaterial3D = _make_material(Color(0.16, 0.17, 0.17, 1.0), 0.82, 0.30, Color(0.04, 0.035, 0.030, 1.0), 0.015, false)
	_add_disc(ctx, stage, "TitaniumBase", 1.12, 0.12, -0.078, base_mat)
	var rim_mat: StandardMaterial3D = _make_material(Color(0.56, 0.52, 0.43, 1.0), 0.90, 0.24, Color(0.34, 0.29, 0.20, 1.0), 0.045, false)
	_add_disc(ctx, stage, "GreyGoldRim", 1.17, 0.022, 0.004, rim_mat)
	var top_mat: StandardMaterial3D = _make_material(Color(0.74, 0.72, 0.66, 0.40), 0.50, 0.26, Color(0.30, 0.27, 0.20, 1.0), 0.025, true)
	_add_disc(ctx, stage, "BrushedSoftTop", 0.96, 0.016, 0.038, top_mat)


func _add_disc(ctx, stage: Node3D, node_name: String, radius: float, height: float, y: float, mat: StandardMaterial3D) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 128
	mesh.rings = 1
	mesh.material = mat
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = Vector3(0.0, y, 0.0)
	stage.add_child(node)
	ctx.own(node)


func _add_backdrop_cards(ctx, stage: Node3D) -> void:
	var mat_a: StandardMaterial3D = _make_material(Color(0.60, 0.78, 0.74, 0.16), 0.0, 0.92, Color(0.60, 0.78, 0.74, 1.0), 0.05, true)
	_add_quad(ctx, stage, "SoftTealGlowLeft", Vector3(-1.45, 1.02, -1.35), Vector2(1.85, 1.40), mat_a)
	var mat_b: StandardMaterial3D = _make_material(Color(0.98, 0.73, 0.54, 0.10), 0.0, 0.92, Color(0.98, 0.73, 0.54, 1.0), 0.04, true)
	_add_quad(ctx, stage, "WarmPeachGlowRight", Vector3(1.38, 0.92, -1.42), Vector2(1.70, 1.30), mat_b)


func _add_quad(ctx, stage: Node3D, node_name: String, pos: Vector3, size: Vector2, mat: StandardMaterial3D) -> void:
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = size
	mesh.material = mat
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	stage.add_child(node)
	ctx.own(node)


func _make_material(albedo: Color, metallic: float, roughness: float, emission: Color, emission_energy: float, transparent: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.metallic = metallic
	mat.roughness = roughness
	mat.emission_enabled = emission_energy > 0.0
	mat.emission = emission
	mat.emission_energy_multiplier = emission_energy
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return mat


func _add_lights(ctx, stage: Node3D) -> void:
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "WarmSoftboxKey"
	key.light_color = Color(1.0, 0.83, 0.66, 1.0)
	key.light_energy = 1.58
	key.rotation_degrees = Vector3(-44.0, -33.0, 0.0)
	key.shadow_enabled = true
	stage.add_child(key)
	ctx.own(key)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "CoolTealFill"
	fill.light_color = Color(0.66, 0.82, 0.92, 1.0)
	fill.light_energy = 0.58
	fill.rotation_degrees = Vector3(-12.0, 142.0, 0.0)
	stage.add_child(fill)
	ctx.own(fill)

	var face: OmniLight3D = OmniLight3D.new()
	face.name = "PeachFaceFill"
	face.light_color = Color(1.0, 0.86, 0.74, 1.0)
	face.light_energy = 0.72
	face.omni_range = 4.5
	face.position = Vector3(-1.4, 1.75, 2.15)
	stage.add_child(face)
	ctx.own(face)


func _add_camera(ctx, stage: Node3D) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "SoftVinylCamera"
	camera.position = Vector3(0.0, 1.20, 3.52)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.64, 0.0), Vector3.UP)
	camera.fov = 34.0
	stage.add_child(camera)
	ctx.own(camera)
	camera.current = true


func _fit_model_to_stage(model: Node3D, target_position: Vector3, target_height: float, target_side: float) -> void:
	var bounds: Array = [false, AABB()]
	_accumulate_bounds(model, model, bounds)
	if not bool(bounds[0]):
		model.position = target_position
		return
	var box: AABB = bounds[1] as AABB
	var bounds_size: Vector3 = box.size
	var side_size: float = maxf(bounds_size.x, bounds_size.z)
	var height_scale: float = target_height / maxf(bounds_size.y, 0.001)
	var side_scale: float = target_side / maxf(side_size, 0.001)
	var fit_scale: float = clampf(minf(height_scale, side_scale), 0.01, 3.0)
	var center: Vector3 = box.position + (box.size * 0.5)
	model.scale = Vector3.ONE * fit_scale
	model.position = Vector3(target_position.x - (center.x * fit_scale), target_position.y - (box.position.y * fit_scale), target_position.z - (center.z * fit_scale))


func _accumulate_bounds(root_model: Node3D, node: Node, bounds: Array) -> void:
	if node is VisualInstance3D:
		var visual: VisualInstance3D = node as VisualInstance3D
		if visual.visible:
			var local_aabb: AABB = visual.get_aabb()
			if local_aabb.size.length_squared() > 0.0001:
				var relative: Transform3D = root_model.global_transform.affine_inverse() * visual.global_transform
				var transformed: AABB = relative * local_aabb
				if bool(bounds[0]):
					bounds[1] = (bounds[1] as AABB).merge(transformed)
				else:
					bounds[0] = true
					bounds[1] = transformed
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		_accumulate_bounds(root_model, child, bounds)
