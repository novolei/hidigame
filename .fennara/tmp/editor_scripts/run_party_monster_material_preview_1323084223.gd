@tool
extends RefCounted

const PARTY_MONSTER_SCENE_PATH := "res://assets/characters/party_monster/party_monster_skin.tscn"

func run(ctx) -> void:
	var root: Node3D = ctx.get_scene_root() as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "PartyMonsterMaterialPreview"
		ctx.set_scene_root(root)
		ctx.log("Created preview root")
	else:
		ctx.clear_children(root)
		ctx.log("Cleared existing preview root")

	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	root.add_child(world)
	ctx.own(world)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.72, 0.83, 0.88, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.88, 0.95, 1.0)
	environment.ambient_light_energy = 0.86
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	environment.tonemap_white = 1.55
	world.environment = environment

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	key_light.light_energy = 1.45
	key_light.light_color = Color(1.0, 0.94, 0.86, 1.0)
	key_light.light_specular = 0.86
	root.add_child(key_light)
	ctx.own(key_light)

	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(-18.0, 132.0, 0.0)
	fill_light.light_energy = 0.28
	fill_light.light_color = Color(0.72, 0.88, 1.0, 1.0)
	fill_light.light_specular = 0.35
	root.add_child(fill_light)
	ctx.own(fill_light)

	var floor: MeshInstance3D = MeshInstance3D.new()
	floor.name = "MattePreviewFloor"
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(5.4, 2.8)
	floor.mesh = floor_mesh
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.66, 0.60, 0.50, 1.0)
	floor_material.roughness = 0.78
	floor_mesh.material = floor_material
	floor.position = Vector3(0.0, -0.02, 0.0)
	root.add_child(floor)
	ctx.own(floor)

	var ids: Array[String] = ["party_monster_c01", "party_monster_masktint01", "party_monster_masktint11"]
	var labels: Array[String] = ["DefaultYellow", "MaskBlue", "MaskPink"]
	var xs: Array[float] = [-1.35, 0.0, 1.35]
	for index in range(ids.size()):
		var skin: Node3D = ctx.instance_scene(root, PARTY_MONSTER_SCENE_PATH, labels[index]) as Node3D
		if skin == null:
			ctx.error("Could not instance Party Monster preview skin")
			return
		skin.position = Vector3(xs[index], 0.0, 0.0)
		skin.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		if skin.has_method("set_character_model_id"):
			skin.call("set_character_model_id", ids[index])
		if skin.has_method("_build_skin"):
			skin.call("_build_skin")
		if skin.has_method("idle"):
			skin.call("idle")
		ctx.log("Prepared preview skin %s" % ids[index])

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.current = true
	camera.fov = 48.0
	camera.look_at_from_position(Vector3(0.0, 1.05, 4.35), Vector3(0.0, 0.72, 0.0), Vector3.UP)
	root.add_child(camera)
	ctx.own(camera)

	ctx.mark_modified()
	ctx.log("Party Monster material preview scene updated")
