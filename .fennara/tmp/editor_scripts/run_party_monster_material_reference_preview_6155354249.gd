@tool
extends RefCounted

const PARTY_MONSTER_SCENE := "res://assets/characters/party_monster/party_monster_skin.tscn"

func _make_material(color: Color, metallic: float, roughness: float, emission: Color = Color(0, 0, 0, 1), emission_energy: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material

func _add_cylinder(ctx: Variant, parent: Node3D, node_name: String, radius: float, height: float, y: float, material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 128
	mesh.rings = 1
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = Vector3(0.0, y, 0.0)
	parent.add_child(instance)
	ctx.own(instance)

func _spawn_party_monster(ctx: Variant, parent: Node3D, model_id: String, node_name: String, position: Vector3, yaw_deg: float) -> void:
	var model: Node3D = ctx.instance_scene(parent, PARTY_MONSTER_SCENE, node_name) as Node3D
	if model == null:
		ctx.error("Could not instance PartyMonsterSkin for %s" % model_id)
		return
	model.position = position
	model.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	model.scale = Vector3.ONE * 1.02
	if model.has_method("set_character_model_id"):
		model.call("set_character_model_id", model_id)
	if model.has_method("idle"):
		model.call("idle")
	if model.has_method("apply_pose_now"):
		model.call("apply_pose_now", 0.0)
	if model.has_method("set_animation_paused"):
		model.call("set_animation_paused", true)
	ctx.log("spawned %s as %s" % [node_name, model_id])

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterMaterialReferencePreview"
		ctx.set_scene_root(new_root)
		root = new_root
	else:
		ctx.clear_children(root)
	var root3d: Node3D = root as Node3D
	if root3d == null:
		ctx.error("Root was not Node3D")
		return

	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.name = "SoftToyEnvironment"
	var env_resource: Environment = Environment.new()
	env_resource.background_mode = Environment.BG_COLOR
	env_resource.background_color = Color(0.54, 0.72, 0.69, 1.0)
	env_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_resource.ambient_light_color = Color(0.82, 0.94, 0.90, 1.0)
	env_resource.ambient_light_energy = 0.78
	env_resource.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_resource.tonemap_exposure = 0.86
	env_resource.tonemap_white = 2.05
	env_resource.fog_enabled = true
	env_resource.fog_mode = Environment.FOG_MODE_DEPTH
	env_resource.fog_light_color = Color(0.56, 0.76, 0.72, 1.0)
	env_resource.fog_density = 0.022
	env_resource.fog_depth_begin = 5.0
	env_resource.fog_depth_end = 10.0
	environment.environment = env_resource
	root3d.add_child(environment)
	ctx.own(environment)

	var stage: Node3D = Node3D.new()
	stage.name = "SoftToyStage"
	root3d.add_child(stage)
	ctx.own(stage)

	_add_cylinder(ctx, stage, "WarmCreamFloor", 2.55, 0.06, -0.06, _make_material(Color(0.84, 0.80, 0.70, 1.0), 0.0, 0.58))
	_add_cylinder(ctx, stage, "MutedGoldRim", 2.64, 0.035, -0.015, _make_material(Color(0.58, 0.53, 0.41, 1.0), 0.55, 0.30, Color(0.34, 0.29, 0.18, 1.0), 0.02))

	_spawn_party_monster(ctx, stage, "party_monster_c01", "CreamYellowMonster", Vector3(-1.06, 0.0, 0.0), 18.0)
	_spawn_party_monster(ctx, stage, "party_monster_c06", "WarmOrangeMonster", Vector3(0.12, 0.0, -0.18), 0.0)
	_spawn_party_monster(ctx, stage, "party_monster_c08", "CoolGreenMonster", Vector3(1.16, 0.0, 0.02), -16.0)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "WarmSoftKey"
	key.light_color = Color(0.98, 0.86, 0.72, 1.0)
	key.light_energy = 1.16
	key.rotation_degrees = Vector3(-42.0, -34.0, 0.0)
	key.shadow_enabled = true
	stage.add_child(key)
	ctx.own(key)

	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.name = "MintRim"
	rim.light_color = Color(0.52, 0.76, 0.80, 1.0)
	rim.light_energy = 0.36
	rim.rotation_degrees = Vector3(-14.0, 144.0, 0.0)
	stage.add_child(rim)
	ctx.own(rim)

	var fill: OmniLight3D = OmniLight3D.new()
	fill.name = "CreamFill"
	fill.light_color = Color(0.88, 0.95, 0.88, 1.0)
	fill.light_energy = 0.78
	fill.omni_range = 5.8
	fill.position = Vector3(-1.8, 2.0, 2.65)
	stage.add_child(fill)
	ctx.own(fill)

	var camera: Camera3D = Camera3D.new()
	camera.name = "SoftToyCamera"
	camera.position = Vector3(0.0, 1.16, 5.85)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.76, 0.0), Vector3.UP)
	camera.fov = 29.0
	stage.add_child(camera)
	ctx.own(camera)
	camera.current = true

	ctx.mark_modified()
	ctx.log("Material reference preview rebuilt")
