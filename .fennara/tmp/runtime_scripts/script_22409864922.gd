extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root=null")
		return
	var stage: Node3D = Node3D.new()
	stage.name = "FennaraPartyMonsterMaterialPreview"
	root.add_child(stage)
	stage.global_position = Vector3(0.0, 3.0, 0.0)

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "PreviewWorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.54, 0.76, 0.92, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.91, 0.96, 1.0)
	environment.ambient_light_energy = 0.42
	world_environment.environment = environment
	stage.add_child(world_environment)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "PreviewKeyLight"
	light.light_energy = 2.4
	light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	stage.add_child(light)

	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "PreviewSoftFill"
	fill.light_energy = 1.15
	fill.omni_range = 6.0
	fill.global_position = stage.global_position + Vector3(-2.0, 2.0, 2.0)
	stage.add_child(fill)

	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 1.35
	floor_mesh.bottom_radius = 1.35
	floor_mesh.height = 0.05
	floor_mesh.radial_segments = 72
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.78, 0.72, 0.63, 1.0)
	floor_material.roughness = 0.58
	floor_mesh.material = floor_material
	var floor_left: MeshInstance3D = MeshInstance3D.new()
	floor_left.name = "PreviewBaseDefault"
	floor_left.mesh = floor_mesh
	floor_left.position = Vector3(-1.05, -0.03, 0.0)
	stage.add_child(floor_left)
	var floor_right: MeshInstance3D = MeshInstance3D.new()
	floor_right.name = "PreviewBaseMaskTint"
	floor_right.mesh = floor_mesh
	floor_right.position = Vector3(1.05, -0.03, 0.0)
	stage.add_child(floor_right)

	var scene: PackedScene = load("res://assets/characters/party_monster/party_monster_skin.tscn") as PackedScene
	if scene == null:
		ctx.log("party_monster_scene=null")
		return
	var default_skin: Node3D = scene.instantiate() as Node3D
	var mask_skin: Node3D = scene.instantiate() as Node3D
	if default_skin == null or mask_skin == null:
		ctx.log("instantiate_failed")
		return
	default_skin.name = "PreviewDefaultPBR"
	mask_skin.name = "PreviewMaskTint"
	stage.add_child(default_skin)
	stage.add_child(mask_skin)
	default_skin.global_position = stage.global_position + Vector3(-1.05, 0.0, 0.0)
	mask_skin.global_position = stage.global_position + Vector3(1.05, 0.0, 0.0)
	default_skin.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	mask_skin.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	default_skin.scale = Vector3.ONE * 0.95
	mask_skin.scale = Vector3.ONE * 0.95
	if default_skin.has_method("set_character_model_id"):
		default_skin.call("set_character_model_id", "party_monster_c01")
	if mask_skin.has_method("set_character_model_id"):
		mask_skin.call("set_character_model_id", "party_monster_masktint01")
	if default_skin.has_method("idle"):
		default_skin.call("idle")
	if mask_skin.has_method("idle"):
		mask_skin.call("idle")

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 36.0
	stage.add_child(camera)
	camera.global_position = stage.global_position + Vector3(0.0, 1.25, 4.25)
	camera.look_at(stage.global_position + Vector3(0.0, 0.78, 0.0), Vector3.UP)
	camera.current = true

	await ctx.wait(0.45)
	ctx.log("capturing party monster shader preview default+masktint")
	await ctx.capture("party_monster_shader_preview")
	ctx.close_scene()
