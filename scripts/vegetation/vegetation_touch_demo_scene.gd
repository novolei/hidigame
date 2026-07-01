extends Node3D

const PLATFORM_SIZE := Vector2(14.0, 10.0)
const WALK_START := Vector3(4.8, 0.88, 2.2)
const WALK_END := Vector3(-4.8, 0.88, -2.2)
const WALK_SPEED := 2.2

var _walker: Node3D
var _walk_progress: float = 0.0
var _walk_direction: float = 1.0


func _ready() -> void:
	_create_environment()
	_create_vegetation()
	_create_walker()


func _process(delta: float) -> void:
	if _walker == null:
		return
	var path_length: float = WALK_START.distance_to(WALK_END)
	if path_length <= 0.001:
		return
	_walk_progress += _walk_direction * delta * WALK_SPEED / path_length
	if _walk_progress >= 1.0:
		_walk_progress = 1.0
		_walk_direction = -1.0
	elif _walk_progress <= 0.0:
		_walk_progress = 0.0
		_walk_direction = 1.0
	var next_position: Vector3 = WALK_START.lerp(WALK_END, _walk_progress)
	_walker.look_at_from_position(next_position, next_position + (WALK_END - WALK_START).normalized() * _walk_direction, Vector3.UP)
	_walker.global_position = next_position


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.48, 0.76, 0.98, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.64, 0.80, 0.82, 1.0)
	environment.ambient_light_energy = 0.40
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.08
	environment.tonemap_agx_contrast = 1.16
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.10
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "WarmSun"
	sun.light_color = Color(1.0, 0.88, 0.66, 1.0)
	sun.light_energy = 2.05
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_fade_start = 0.94
	sun.directional_shadow_pancake_size = 8.0
	sun.rotation_degrees = Vector3(-49.0, 34.0, 0.0)
	add_child(sun)

	var platform := MeshInstance3D.new()
	platform.name = "SoftGreenPlatform"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(PLATFORM_SIZE.x, 0.22, PLATFORM_SIZE.y)
	platform.mesh = box_mesh
	platform.position = Vector3(0.0, -0.11, 0.0)
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.30, 0.58, 0.22, 1.0)
	platform_material.roughness = 0.9
	platform.material_override = platform_material
	add_child(platform)

	var path := MeshInstance3D.new()
	path.name = "WalkPathGuide"
	var path_mesh := BoxMesh.new()
	path_mesh.size = Vector3(10.8, 0.025, 0.18)
	path.mesh = path_mesh
	path.position = Vector3(0.0, 0.025, 0.0)
	path.rotation_degrees.y = rad_to_deg(atan2(WALK_END.x - WALK_START.x, WALK_END.z - WALK_START.z))
	var path_material := StandardMaterial3D.new()
	path_material.albedo_color = Color(0.78, 0.92, 0.46, 0.42)
	path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_material.roughness = 1.0
	path.material_override = path_material
	add_child(path)

	var camera := Camera3D.new()
	camera.name = "OverviewCamera"
	camera.current = true
	camera.fov = 43.0
	camera.look_at_from_position(Vector3(6.8, 8.2, 9.6), Vector3(0.0, 0.38, 0.0), Vector3.UP)
	add_child(camera)


func _create_vegetation() -> void:
	var profile := VegetationProfile.new()
	profile.profile_id = "vegetation_touch_lab"
	profile.generation_seed = 927413
	profile.build_visuals_in_headless = true
	profile.enable_grass = true
	profile.grass_instance_count = 9000
	profile.grass_chunk_size = 8.0
	profile.grass_min_height = 0.34
	profile.grass_max_height = 0.78
	profile.grass_min_width = 0.82
	profile.grass_max_width = 1.42
	profile.grass_patch_frequency = 0.030
	profile.grass_edge_bias = 0.02
	profile.grass_lane_clearance = 0.0
	profile.grass_base_color = Color(0.24, 0.62, 0.17, 1.0)
	profile.grass_tip_color = Color(0.52, 0.86, 0.30, 1.0)
	profile.grass_shadow_color = Color(0.08, 0.26, 0.08, 1.0)
	profile.wind_direction = Vector2(0.88, 0.42)
	profile.grass_wind_strength = 0.52
	profile.wind_speed = 0.86
	profile.wind_noise_scale = 0.048
	profile.gust_strength = 0.42
	profile.touch_radius = 2.75
	profile.touch_push_strength = 0.82
	profile.touch_crush_strength = 0.68
	profile.touch_recovery_speed = 0.90
	profile.touch_slot_count = 6
	profile.touch_min_move_distance = 0.24
	profile.enable_flowers = true
	profile.flower_instance_count = 360
	profile.flower_chunk_size = 8.0
	profile.flower_min_height = 0.62
	profile.flower_max_height = 1.18
	profile.flower_min_width = 0.86
	profile.flower_max_width = 1.52
	profile.flower_patch_frequency = 0.060
	profile.flower_density = 0.34
	profile.flower_cluster_count = 18
	profile.flower_cluster_min_flowers = 10
	profile.flower_cluster_max_flowers = 24
	profile.flower_cluster_min_radius = 0.55
	profile.flower_cluster_max_radius = 1.35
	profile.flower_cluster_min_spacing = 2.55
	profile.flower_cluster_height_variation = 0.32
	profile.flower_heads_per_instance = 7
	profile.flower_shape_variety = 1.0
	profile.flower_petal_color_a = Color(0.94, 0.97, 0.88, 1.0)
	profile.flower_petal_color_b = Color(0.97, 0.82, 0.92, 1.0)
	profile.flower_petal_color_c = Color(0.70, 0.88, 1.0, 1.0)
	profile.flower_petal_color_d = Color(0.99, 0.86, 0.42, 1.0)
	profile.flower_petal_color_e = Color(0.76, 0.68, 1.0, 1.0)
	profile.enable_trees = false
	profile.fallback_support_center = Vector3.ZERO
	profile.fallback_support_size = PLATFORM_SIZE
	profile.fallback_support_top_y = 0.0

	var vegetation := VegetationController.new()
	vegetation.name = "VegetationController"
	vegetation.profile = profile
	vegetation.install_wait_frames = 1
	add_child(vegetation)


func _create_walker() -> void:
	_walker = Node3D.new()
	_walker.name = "AutoWalker"
	_walker.add_to_group("players")
	add_child(_walker)
	_walker.global_position = WALK_START

	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.34
	capsule.height = 1.16
	body.mesh = capsule
	body.position = Vector3(0.0, 0.58, 0.0)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(1.0, 0.42, 0.64, 1.0)
	body_material.roughness = 0.75
	body.material_override = body_material
	_walker.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	head.mesh = sphere
	head.position = Vector3(0.0, 1.22, 0.0)
	head.material_override = body_material
	_walker.add_child(head)
