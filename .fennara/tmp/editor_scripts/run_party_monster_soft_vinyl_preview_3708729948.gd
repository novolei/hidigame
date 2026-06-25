@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterSoftVinylPreview"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created soft vinyl preview root")

	var root3d: Node3D = root as Node3D
	if root3d == null:
		ctx.error("Preview root is not Node3D")
		return

	ctx.clear_children(root)

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "SoftVinylWorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.74, 0.72, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.94, 0.86, 1.0)
	environment.ambient_light_energy = 1.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.10
	environment.tonemap_white = 2.45
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_saturation = 0.96
	environment.adjustment_contrast = 0.96
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.76, 0.90, 0.88, 1.0)
	environment.fog_density = 0.025
	environment.fog_depth_begin = 5.6
	environment.fog_depth_end = 10.0
	world_environment.environment = environment
	root.add_child(world_environment)
	ctx.own(world_environment)

	var stage: Node3D = Node3D.new()
	stage.name = "StudioStage"
	root.add_child(stage)
	ctx.own(stage)

	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 2.8
	floor_mesh.bottom_radius = 2.8
	floor_mesh.height = 0.08
	floor_mesh.radial_segments = 96
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.74, 0.82, 0.78, 1.0)
	floor_material.metallic = 0.0
	floor_material.roughness = 0.72
	floor_material.disable_receive_shadows = false
	floor_mesh.material = floor_material
	var floor_instance: MeshInstance3D = MeshInstance3D.new()
	floor_instance.name = "SoftMattePlatform"
	floor_instance.mesh = floor_mesh
	floor_instance.position = Vector3(0.0, -0.04, 0.0)
	stage.add_child(floor_instance)
	ctx.own(floor_instance)

	var default_model: Node3D = ctx.instance_scene(stage, "res://assets/characters/party_monster/party_monster_skin.tscn", "DefaultSoftVinylPM01") as Node3D
	if default_model != null:
		default_model.set("character_model_id", "party_monster_c01")
		default_model.position = Vector3(-0.72, 0.0, 0.0)
		default_model.rotation_degrees = Vector3(0.0, -10.0, 0.0)
		default_model.scale = Vector3(0.86, 0.86, 0.86)
		ctx.log("Added default Party Monster preview")

	var tint_model: Node3D = ctx.instance_scene(stage, "res://assets/characters/party_monster/party_monster_skin.tscn", "TintSoftVinylPM01") as Node3D
	if tint_model != null:
		tint_model.set("character_model_id", "party_monster_masktint01")
		tint_model.position = Vector3(0.82, 0.0, 0.08)
		tint_model.rotation_degrees = Vector3(0.0, 12.0, 0.0)
		tint_model.scale = Vector3(0.86, 0.86, 0.86)
		ctx.log("Added mask tint Party Monster preview")

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "WarmSoftboxKey"
	key_light.light_color = Color(1.0, 0.86, 0.69, 1.0)
	key_light.light_energy = 2.26
	key_light.light_specular = 0.82
	key_light.shadow_enabled = true
	key_light.rotation_degrees = Vector3(-44.0, -32.0, 0.0)
	stage.add_child(key_light)
	ctx.own(key_light)

	var sky_fill: DirectionalLight3D = DirectionalLight3D.new()
	sky_fill.name = "CoolTealFill"
	sky_fill.light_color = Color(0.66, 0.86, 1.0, 1.0)
	sky_fill.light_energy = 0.78
	sky_fill.light_specular = 0.36
	sky_fill.rotation_degrees = Vector3(-18.0, 142.0, 0.0)
	stage.add_child(sky_fill)
	ctx.own(sky_fill)

	var blush_fill: OmniLight3D = OmniLight3D.new()
	blush_fill.name = "PeachFaceFill"
	blush_fill.light_color = Color(1.0, 0.68, 0.54, 1.0)
	blush_fill.light_energy = 0.86
	blush_fill.light_specular = 0.32
	blush_fill.omni_range = 3.8
	blush_fill.position = Vector3(0.0, 1.22, 2.1)
	stage.add_child(blush_fill)
	ctx.own(blush_fill)

	var camera: Camera3D = Camera3D.new()
	camera.name = "SoftVinylCamera"
	camera.position = Vector3(0.0, 1.34, 4.25)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.82, 0.0), Vector3.UP)
	camera.fov = 26.0
	camera.current = true
	stage.add_child(camera)
	ctx.own(camera)

	ctx.log("Preview scene authored with soft-vinyl lighting and opaque Party Monster skins")
	ctx.mark_modified()
