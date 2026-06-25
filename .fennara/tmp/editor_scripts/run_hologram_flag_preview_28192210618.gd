@tool
extends RefCounted

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "HologramFlagPreview"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created preview root")
	else:
		ctx.clear_children(root)
		ctx.log("Cleared existing preview children")

	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.015, 0.018, 0.022, 1.0)
	environment.ambient_light_energy = 0.45
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_strength = 1.25
	world_environment.environment = environment
	root.add_child(world_environment)
	ctx.own(world_environment)

	var floor_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	floor_mesh_instance.name = "PreviewFloor"
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(3.2, 0.035, 3.2)
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.045, 0.055, 0.065, 1.0)
	floor_material.roughness = 0.78
	floor_mesh.material = floor_material
	floor_mesh_instance.mesh = floor_mesh
	floor_mesh_instance.position = Vector3(0.0, -0.02, 0.0)
	root.add_child(floor_mesh_instance)
	ctx.own(floor_mesh_instance)

	var flag: Node3D = ctx.instance_scene(root, "res://scenes/effects/hologram_flag.tscn", "HologramFlagPreviewInstance") as Node3D
	if flag == null:
		ctx.error("Could not instance hologram flag scene")
		return
	flag.set("auto_build", true)
	flag.set("owner_peer_id", 1)
	flag.set("character_model_id", "party_monster_c01")
	flag.set("skin_color", 2)
	flag.set("player_height", 2.0)
	flag.position = Vector3(0.0, 0.0, 0.0)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "PreviewKeyLight"
	light.light_energy = 0.7
	light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	root.add_child(light)
	ctx.own(light)

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.current = true
	camera.fov = 36.0
	camera.position = Vector3(1.1, 0.75, 2.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.42, 0.0), Vector3.UP)
	root.add_child(camera)
	ctx.own(camera)

	ctx.log("Preview scene ready with runtime hologram flag instance")
	ctx.mark_modified()
