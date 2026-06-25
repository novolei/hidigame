@tool
extends RefCounted

const PARTY_MONSTER_SCENE := "res://assets/characters/party_monster/party_monster_skin.tscn"
const VARIANT_IDS: Array[String] = [
	"party_monster_c01",
	"party_monster_c11",
	"party_monster_masktint02"
]

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "PartyMonsterMaterialProbe"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created probe scene root")
	else:
		ctx.clear_children(root)
		ctx.log("Cleared existing probe scene")

	var root_3d: Node3D = root as Node3D
	if root_3d == null:
		ctx.error("Probe root is not Node3D")
		return

	var environment_node: WorldEnvironment = WorldEnvironment.new()
	environment_node.name = "ProbeWorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.70, 0.82, 0.90, 1.0)
	environment.background_energy_multiplier = 0.82
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.68, 0.82, 1.0)
	environment.ambient_light_energy = 0.72
	environment.ambient_light_sky_contribution = 0.10
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.88
	environment.tonemap_white = 3.2
	environment.fog_enabled = false
	environment_node.environment = environment
	root.add_child(environment_node)
	ctx.own(environment_node)

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.name = "WarmKeyLight"
	key_light.light_color = Color(1.0, 0.90, 0.78, 1.0)
	key_light.light_energy = 0.86
	key_light.light_specular = 0.72
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.2
	key_light.rotation_degrees = Vector3(-58.0, 34.0, 0.0)
	root.add_child(key_light)
	ctx.own(key_light)

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.name = "SoftFrontFill"
	fill_light.position = Vector3(0.0, 2.0, 3.3)
	fill_light.light_color = Color(0.76, 0.88, 1.0, 1.0)
	fill_light.light_energy = 0.22
	fill_light.light_specular = 0.18
	fill_light.omni_range = 6.0
	root.add_child(fill_light)
	ctx.own(fill_light)

	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 3.0
	floor_mesh.bottom_radius = 3.12
	floor_mesh.height = 0.16
	floor_mesh.radial_segments = 96
	floor_mesh.rings = 1
	var floor_material: StandardMaterial3D = StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.61, 0.54, 0.43, 1.0)
	floor_material.roughness = 0.52
	floor_material.metallic = 0.08
	floor_material.metallic_specular = 0.42
	floor_mesh.material = floor_material
	var base_node: MeshInstance3D = MeshInstance3D.new()
	base_node.name = "NeutralPreviewBase"
	base_node.mesh = floor_mesh
	base_node.position = Vector3(0.0, -0.08, 0.0)
	root.add_child(base_node)
	ctx.own(base_node)

	var positions: Array[Vector3] = [Vector3(-1.75, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(1.75, 0.0, 0.0)]
	for index in range(VARIANT_IDS.size()):
		var variant_id: String = VARIANT_IDS[index]
		var character: Node3D = ctx.instance_scene(root, PARTY_MONSTER_SCENE, "Probe_%s" % variant_id) as Node3D
		if character == null:
			ctx.error("Failed to instance Party Monster scene")
			return
		character.position = positions[index]
		character.rotation_degrees = Vector3(0.0, -10.0 + float(index) * 10.0, 0.0)
		if character.has_method("set_character_model_id"):
			character.call("set_character_model_id", variant_id)
		ctx.log("Instanced %s at %s" % [variant_id, str(positions[index])])

	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 42.0
	camera.near = 0.05
	camera.far = 80.0
	root.add_child(camera)
	ctx.own(camera)
	camera.look_at_from_position(Vector3(0.0, 1.35, 6.3), Vector3(0.0, 0.95, 0.0), Vector3.UP)

	ctx.mark_modified()
	ctx.log("Probe scene saved")
