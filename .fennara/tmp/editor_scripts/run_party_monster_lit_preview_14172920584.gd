@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterLitPreview"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created lit preview root")
	else:
		ctx.clear_children(root)
		ctx.log("Cleared existing lit preview")

	var root_3d: Node3D = root as Node3D
	if root_3d == null:
		ctx.error("Root is not Node3D")
		return

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "PreviewEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.72, 0.84, 0.82, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.76, 0.90, 0.86, 1.0)
	environment.ambient_light_energy = 0.82
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.92
	environment.tonemap_white = 3.2
	world_environment.environment = environment
	root.add_child(world_environment)
	ctx.own(world_environment)

	var skin: Node3D = ctx.instance_scene(root, "res://assets/characters/party_monster/party_monster_skin.tscn", "PartyMonsterSkin") as Node3D
	if skin == null:
		ctx.error("Failed to instance PartyMonsterSkin")
		return
	skin.position = Vector3(0.0, 0.0, 0.0)
	skin.rotation_degrees = Vector3(0.0, -18.0, 0.0)
	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", "party_monster_c01")
	if skin.has_method("idle"):
		skin.call("idle")
	if skin.has_method("apply_pose_now"):
		skin.call("apply_pose_now", 0.0)
	if skin.has_method("set_animation_paused"):
		skin.call("set_animation_paused", true)
	ctx.log("Instanced PartyMonsterSkin")

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_color = Color(1.0, 0.90, 0.78, 1.0)
	key_light.light_energy = 1.22
	key_light.rotation_degrees = Vector3(-38.0, -30.0, 0.0)
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.5
	root.add_child(key_light)
	ctx.own(key_light)

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.name = "SoftFillLight"
	fill_light.light_color = Color(0.72, 0.92, 0.88, 1.0)
	fill_light.light_energy = 0.58
	fill_light.omni_range = 5.0
	fill_light.omni_attenuation = 0.38
	fill_light.position = Vector3(-1.8, 1.8, 2.4)
	root.add_child(fill_light)
	ctx.own(fill_light)

	var face_light: OmniLight3D = OmniLight3D.new()
	face_light.name = "FaceLight"
	face_light.light_color = Color(1.0, 0.82, 0.68, 1.0)
	face_light.light_energy = 0.36
	face_light.omni_range = 4.0
	face_light.omni_attenuation = 0.34
	face_light.position = Vector3(1.15, 1.3, 2.2)
	root.add_child(face_light)
	ctx.own(face_light)

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(0.0, 1.10, 3.35)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.78, 0.0), Vector3.UP)
	camera.fov = 32.0
	camera.current = true
	root.add_child(camera)
	ctx.own(camera)

	ctx.mark_modified()
	ctx.log("Lit preview ready")
