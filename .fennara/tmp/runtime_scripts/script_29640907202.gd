extends RefCounted

func run(ctx: Variant) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.log("root_missing")
		return

	var old_probe: Node = root.get_node_or_null("RuntimePartyMonsterMaterialProbe")
	if old_probe != null:
		old_probe.queue_free()
		await ctx.wait(0.1)

	var ui_nodes: Array[String] = ["HUDCanvas", "MainMenuUI", "MatchIntroOverlay", "CharacterSetupOverlay"]
	for path: String in ui_nodes:
		var ui_node: Node = root.get_node_or_null(path)
		if ui_node is CanvasItem:
			(ui_node as CanvasItem).visible = false

	var probe_root: Node3D = Node3D.new()
	probe_root.name = "RuntimePartyMonsterMaterialProbe"
	root.add_child(probe_root)

	var skin_scene_resource: Resource = load("res://assets/characters/party_monster/party_monster_skin.tscn")
	if not skin_scene_resource is PackedScene:
		ctx.log("skin_scene_load_failed")
		return
	var skin_scene: PackedScene = skin_scene_resource as PackedScene
	var ids: Array[String] = ["party_monster_c10", "party_monster_masktint02", "party_monster_masktint13"]
	var x_positions: Array[float] = [-2.2, 0.0, 2.2]
	for index: int in range(ids.size()):
		var skin: Node3D = skin_scene.instantiate() as Node3D
		if skin == null:
			ctx.log("skin_instantiate_failed_%d" % index)
			continue
		skin.name = "ProbeSkin%d" % index
		probe_root.add_child(skin)
		skin.position = Vector3(x_positions[index], 0.0, 0.0)
		skin.rotation_degrees.y = 180.0
		skin.scale = Vector3.ONE * 1.25
		if skin.has_method("set_character_model_id"):
			skin.call("set_character_model_id", ids[index])
		if skin.has_method("set_animation_paused"):
			skin.call("set_animation_paused", true)
		if skin.has_method("apply_pose_now"):
			skin.call("apply_pose_now", 0.05)

	var base_mesh: MeshInstance3D = MeshInstance3D.new()
	base_mesh.name = "ProbeMatteBase"
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 3.8
	cylinder.bottom_radius = 4.2
	cylinder.height = 0.18
	cylinder.radial_segments = 96
	base_mesh.mesh = cylinder
	var base_material: StandardMaterial3D = StandardMaterial3D.new()
	base_material.albedo_color = Color(0.55, 0.50, 0.43, 1.0)
	base_material.metallic = 0.2
	base_material.roughness = 0.48
	base_mesh.material_override = base_material
	base_mesh.position = Vector3(0.0, -0.10, 0.0)
	probe_root.add_child(base_mesh)

	var camera: Camera3D = Camera3D.new()
	camera.name = "RuntimeProbeCamera"
	camera.fov = 38.0
	camera.current = true
	probe_root.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 2.0, 7.1), Vector3(0.0, 0.85, 0.0), Vector3.UP)

	var warm_key: DirectionalLight3D = DirectionalLight3D.new()
	warm_key.name = "RuntimeProbeKeyLight"
	warm_key.light_color = Color(1.0, 0.91, 0.78, 1.0)
	warm_key.light_energy = 0.55
	warm_key.shadow_enabled = true
	probe_root.add_child(warm_key)
	warm_key.rotation_degrees = Vector3(-42.0, -28.0, 0.0)

	ctx.log("probe_ready variants=%s" % str(ids))
	await ctx.wait(0.8)
	await ctx.capture("runtime_party_monster_material_probe")
	ctx.log("probe_capture_done")
