@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterMaterialPreview"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created preview root")
	if not root is Node3D:
		ctx.error("Preview root is not Node3D")
		return
	var root_3d: Node3D = root as Node3D

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.name = "PreviewEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.54, 0.75, 0.88, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.80, 0.88, 0.95, 1.0)
	environment.ambient_light_energy = 0.34
	environment.ssao_enabled = true
	environment.ssao_radius = 1.25
	environment.ssao_intensity = 1.15
	environment_node.environment = environment
	root_3d.add_child(environment_node)
	ctx.own(environment_node)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "PreviewKeyLight"
	key_light.light_energy = 2.25
	key_light.light_color = Color(1.0, 0.94, 0.86, 1.0)
	key_light.shadow_enabled = true
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	root_3d.add_child(key_light)
	ctx.own(key_light)

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.name = "PreviewFillLight"
	fill_light.light_energy = 0.95
	fill_light.light_specular = 0.52
	fill_light.omni_range = 7.0
	fill_light.position = Vector3(-2.4, 2.1, 2.4)
	root_3d.add_child(fill_light)
	ctx.own(fill_light)

	var base_mesh: CylinderMesh = CylinderMesh.new()
	base_mesh.top_radius = 1.22
	base_mesh.bottom_radius = 1.25
	base_mesh.height = 0.10
	base_mesh.radial_segments = 72
	base_mesh.rings = 1
	var base_material: StandardMaterial3D = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.72, 0.66, 0.56, 1.0)
	base_material.roughness = 0.54
	base_material.metallic = 0.18
	base_mesh.material = base_material

	var default_base: MeshInstance3D = MeshInstance3D.new()
	default_base.name = "DefaultBase"
	default_base.mesh = base_mesh
	default_base.position = Vector3(-1.15, -0.05, 0.0)
	root_3d.add_child(default_base)
	ctx.own(default_base)

	var mask_base: MeshInstance3D = MeshInstance3D.new()
	mask_base.name = "MaskTintBase"
	mask_base.mesh = base_mesh
	mask_base.position = Vector3(1.15, -0.05, 0.0)
	root_3d.add_child(mask_base)
	ctx.own(mask_base)

	var default_skin: Node3D = ctx.instance_scene(root_3d, "res://assets/characters/party_monster/party_monster_skin.tscn", "DefaultPBRPreview") as Node3D
	var mask_skin: Node3D = ctx.instance_scene(root_3d, "res://assets/characters/party_monster/party_monster_skin.tscn", "MaskTintPreview") as Node3D
	if default_skin == null or mask_skin == null:
		ctx.error("Could not instance Party Monster preview skins")
		return
	default_skin.position = Vector3(-1.15, 0.0, 0.0)
	mask_skin.position = Vector3(1.15, 0.0, 0.0)
	default_skin.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	mask_skin.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	default_skin.scale = Vector3.ONE * 0.96
	mask_skin.scale = Vector3.ONE * 0.96
	if default_skin.has_method("set_character_model_id"):
		default_skin.call("set_character_model_id", "party_monster_c01")
	if mask_skin.has_method("set_character_model_id"):
		mask_skin.call("set_character_model_id", "party_monster_masktint01")
	if default_skin.has_method("_build_skin"):
		default_skin.call("_build_skin")
	if mask_skin.has_method("_build_skin"):
		mask_skin.call("_build_skin")
	if default_skin.has_method("idle"):
		default_skin.call("idle")
	if mask_skin.has_method("idle"):
		mask_skin.call("idle")
	ctx.log("Instanced default and mask tint Party Monster previews")

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 34.0
	camera.near = 0.03
	camera.far = 30.0
	camera.current = true
	root_3d.add_child(camera)
	ctx.own(camera)
	camera.look_at_from_position(Vector3(0.0, 1.05, 4.35), Vector3(0.0, 0.78, 0.0), Vector3.UP)
	ctx.log("Preview camera framed")

	ctx.mark_modified()
