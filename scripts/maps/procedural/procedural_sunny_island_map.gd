extends MapController
class_name ProceduralSunnyIslandMap

const GENERATED_ROOT_NAME: StringName = &"GeneratedSunnyIsland"
const TERRAIN_BODY_NAME: StringName = &"SunnyIslandTerrainCollision"
const WALKABLE_COLLISION_GROUP_NAME: StringName = &"polygon_apocalypse_walkable_collision"
const PROCEDURAL_WALKABLE_GROUP_NAME: StringName = &"procedural_walkable_collision"
const OCEAN_SHADER_PATH: String = "res://shaders/maps/sunny_island_ocean.gdshader"
const STREAM_SHADER_PATH: String = "res://shaders/maps/sunny_island_stream.gdshader"
const PIRATE_ASSET_ROOT: String = "res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/"
const NATURE_ASSET_ROOT: String = "res://assets/nature_megakit/gltf/"
const TEMPLE_ASSET_ROOT: String = "res://resources/building/ModularTemple/"

const TEMPLE_FLOOR_MESH: String = TEMPLE_ASSET_ROOT + "Floor_Normal_Square.obj"
const TEMPLE_RUINED_WALL_HALF_MESH: String = TEMPLE_ASSET_ROOT + "Wall_Ruined_Half_1.obj"
const TEMPLE_RUINED_WALL_FULL_MESH: String = TEMPLE_ASSET_ROOT + "Wall_Ruined_Full_Cracked_1.obj"
const TEMPLE_DOORWAY_MESH: String = TEMPLE_ASSET_ROOT + "Wall_Straight_Doorway.obj"
const TEMPLE_ARCH_MESH: String = TEMPLE_ASSET_ROOT + "Wall_Arch_Straight.obj"
const TEMPLE_CURVED_SMALL_WALL_MESH: String = TEMPLE_ASSET_ROOT + "Wall_Curved_Small_Middle.obj"
const TEMPLE_CURVED_LARGE_WALL_MESH: String = TEMPLE_ASSET_ROOT + "Wall_Curved_Large_Middle.obj"
const TEMPLE_PILLAR_MESH: String = TEMPLE_ASSET_ROOT + "Pillar_Large_Middle.obj"
const TEMPLE_TOWER_MESH: String = TEMPLE_ASSET_ROOT + "Tower_Bottom.obj"
const TEMPLE_TOWER_TOP_MESH: String = TEMPLE_ASSET_ROOT + "Tower_Top.obj"
const TEMPLE_TOWER_LANDING_MESH: String = TEMPLE_ASSET_ROOT + "Tower_Landing.obj"
const TEMPLE_BRIDGE_RAMP_MESH: String = TEMPLE_ASSET_ROOT + "Floor_Bridge_Ramp.obj"
const TEMPLE_BALCONY_RAMP_MESH: String = TEMPLE_ASSET_ROOT + "Balcony_Base_Bridge_Ramp.obj"
const TEMPLE_RUINED_FLOOR_MESH: String = TEMPLE_ASSET_ROOT + "Floor_Ruined_Straight_1.obj"
const TEMPLE_CURVED_FLOOR_MESH: String = TEMPLE_ASSET_ROOT + "Floor_Curved_Small.obj"
const TEMPLE_STAIRS_MESH: String = TEMPLE_ASSET_ROOT + "Stairs_Steps_Straight.obj"
const TEMPLE_PRESSURE_PLATE_MESH: String = TEMPLE_ASSET_ROOT + "Puzzle_Control_Pressure_Plate.obj"
const TEMPLE_LEVER_MESH: String = TEMPLE_ASSET_ROOT + "Puzzle_Control_Lever.obj"
const TEMPLE_RUG_MESHES: Array[String] = [
	TEMPLE_ASSET_ROOT + "Prop_Rug_Sun.obj",
	TEMPLE_ASSET_ROOT + "Prop_Rug_Moon.obj",
	TEMPLE_ASSET_ROOT + "Prop_Rug_Stars.obj",
]
const TEMPLE_RUBBLE_MESHES: Array[String] = [
	TEMPLE_ASSET_ROOT + "Prop_Rubble_1.obj",
	TEMPLE_ASSET_ROOT + "Prop_Rubble_2.obj",
]
const TEMPLE_VASE_MESHES: Array[String] = [
	TEMPLE_ASSET_ROOT + "Prop_Vase_1.obj",
	TEMPLE_ASSET_ROOT + "Prop_Vase_2.obj",
	TEMPLE_ASSET_ROOT + "Prop_Vase_3.obj",
]
const TEMPLE_FLAG_MESHES: Array[String] = [
	TEMPLE_ASSET_ROOT + "Prop_Flag_Sun.obj",
	TEMPLE_ASSET_ROOT + "Prop_Flag_Moon.obj",
	TEMPLE_ASSET_ROOT + "Prop_Flag_Stars.obj",
]

const CENTRAL_TREE_SCENES: Array[String] = [
	NATURE_ASSET_ROOT + "Pine_1.gltf",
	NATURE_ASSET_ROOT + "Pine_2.gltf",
	NATURE_ASSET_ROOT + "Pine_3.gltf",
	NATURE_ASSET_ROOT + "Pine_4.gltf",
	NATURE_ASSET_ROOT + "Pine_5.gltf",
]
const CENTRAL_ROCK_SCENES: Array[String] = [
	NATURE_ASSET_ROOT + "Rock_Medium_1.gltf",
	NATURE_ASSET_ROOT + "Rock_Medium_2.gltf",
	NATURE_ASSET_ROOT + "Rock_Medium_3.gltf",
]
const CENTRAL_BUSH_SCENES: Array[String] = [
	NATURE_ASSET_ROOT + "Bush_Common.gltf",
	NATURE_ASSET_ROOT + "Bush_Common_Flowers.gltf",
]

const PALM_SCENES: Array[String] = [
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/palm-straight.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/palm-bend.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/palm-detailed-straight.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/palm-detailed-bend.glb",
]
const ROCK_SCENES: Array[String] = [
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/rocks-a.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/rocks-b.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/rocks-c.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/rocks-sand-a.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/rocks-sand-b.glb",
	"res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/rocks-sand-c.glb",
]
const DOCK_SCENE: String = "res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/structure-platform-dock.glb"
const DOCK_SMALL_SCENE: String = "res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/structure-platform-dock-small.glb"
const BOAT_SMALL_SCENE: String = "res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/boat-row-small.glb"
const BOAT_LARGE_SCENE: String = "res://scenes/level/maps/medieval_strategy_world_assets/models/kenney_pirate/boat-row-large.glb"

@export var generation_seed: int = 917213
@export_range(0, 2, 1) var forced_size_tier: int = 0
@export var include_runtime_preview_camera: bool = true
@export var dynamic_day_cycle_enabled: bool = true
@export_range(45.0, 900.0, 1.0) var day_cycle_seconds: float = 240.0
@export_range(0.0, 1.0, 0.01) var day_cycle_start: float = 0.24

var _built: bool = false
var _generated_root: Node3D
var _terrain_material: StandardMaterial3D
var _sand_material: StandardMaterial3D
var _path_material: StandardMaterial3D
var _wood_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _cloth_material: StandardMaterial3D
var _stone_material: StandardMaterial3D
var _terrain_radius: float = 62.0
var _terrain_resolution: int = 54
var _water_y: float = -0.28
var _stream_material: ShaderMaterial
var _world_environment: WorldEnvironment
var _sun_light: DirectionalLight3D
var _fill_light: DirectionalLight3D
var _day_cycle_progress: float = 0.24


func prepare() -> void:
	_build_if_needed()
	super.prepare()


func _process(delta: float) -> void:
	if not _built or not dynamic_day_cycle_enabled:
		return
	_day_cycle_progress = fposmod(_day_cycle_progress + delta / maxf(day_cycle_seconds, 0.001), 1.0)
	_apply_day_lighting(_day_cycle_progress)


func _build_if_needed() -> void:
	if _built:
		return
	_built = true
	set_meta("map_controller", true)
	lighting_mode = MapProfile.Lighting.KEEP
	collision_mode = MapProfile.Collision.ADAPT_LAYERS
	ground_align_mode = MapProfile.GroundAlign.NONE
	ground_y = -3.0
	add_support_floor = true

	var size_profile: Dictionary = _resolve_size_profile()
	_terrain_radius = float(size_profile.get("radius", 62.0))
	_terrain_resolution = int(size_profile.get("resolution", 54))
	_water_y = float(size_profile.get("water_y", -0.28))
	_day_cycle_progress = clampf(day_cycle_start, 0.0, 1.0)
	support_size = Vector2(float(size_profile.get("support_size", 150.0)), float(size_profile.get("support_size", 150.0)))

	_clear_generated_root()
	_create_materials()
	_generated_root = Node3D.new()
	_generated_root.name = GENERATED_ROOT_NAME
	add_child(_generated_root, true)

	_build_environment(size_profile)
	_build_ocean(size_profile)
	_build_terrain(size_profile)
	_build_stream_channels(size_profile)
	_build_paths(size_profile)
	_build_landmarks(size_profile)
	_build_decorations(size_profile)
	_build_temple_ruins(size_profile)
	_build_inner_grove_decorations(size_profile)
	_build_spawn_points(size_profile)
	_build_vegetation_controller(size_profile)
	if include_runtime_preview_camera:
		_build_preview_camera(size_profile)
	set_process(dynamic_day_cycle_enabled)


func _resolve_size_profile() -> Dictionary:
	var configured_players: int = 24
	if Network != null:
		configured_players = int(Network.lobby_config.get("max_players", Network.MAX_PLAYERS))
	var tier: int = forced_size_tier
	if tier <= 0:
		if configured_players <= 8:
			tier = 0
		elif configured_players <= 12:
			tier = 1
		else:
			tier = 2
	match tier:
		0:
			return {
				"tier_name": "8_player",
				"radius": 48.0,
				"resolution": 42,
				"support_size": 112.0,
				"spawn_count": 8,
				"spawn_ring": 20.0,
				"grass_count": 45000,
				"flower_count": 900,
				"tree_count": 34,
				"decor_count": 12,
				"water_y": -0.26,
			}
		1:
			return {
				"tier_name": "12_player",
				"radius": 62.0,
				"resolution": 54,
				"support_size": 150.0,
				"spawn_count": 12,
				"spawn_ring": 27.0,
				"grass_count": 65000,
				"flower_count": 1350,
				"tree_count": 56,
				"decor_count": 18,
				"water_y": -0.28,
			}
		_:
			return {
				"tier_name": "24_player",
				"radius": 84.0,
				"resolution": 72,
				"support_size": 210.0,
				"spawn_count": 24,
				"spawn_ring": 38.0,
				"grass_count": 90000,
				"flower_count": 2000,
				"tree_count": 86,
				"decor_count": 26,
				"water_y": -0.32,
			}


func _clear_generated_root() -> void:
	var existing: Node = get_node_or_null(NodePath(GENERATED_ROOT_NAME))
	if existing != null:
		remove_child(existing)
		existing.free()
	_generated_root = null
	_stream_material = null
	_world_environment = null
	_sun_light = null
	_fill_light = null


func _create_materials() -> void:
	_terrain_material = _make_material("SunnyGrassVertex", Color(0.38, 0.68, 0.25, 1.0), 0.92, true)
	_sand_material = _make_material("SunnySand", Color(0.88, 0.75, 0.49, 1.0), 0.86, false)
	_path_material = _make_material("SunnyPath", Color(0.70, 0.56, 0.36, 1.0), 0.90, false)
	_wood_material = _make_material("WarmWood", Color(0.50, 0.31, 0.18, 1.0), 0.82, false)
	_roof_material = _make_material("CoralRoof", Color(0.76, 0.30, 0.20, 1.0), 0.86, false)
	_cloth_material = _make_material("IslandCloth", Color(0.98, 0.82, 0.46, 1.0), 0.78, false)
	_stone_material = _make_material("SoftStone", Color(0.48, 0.51, 0.44, 1.0), 0.94, false)


func _make_material(material_name: String, albedo: Color, roughness: float, use_vertex_color: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = albedo
	material.roughness = roughness
	material.vertex_color_use_as_albedo = use_vertex_color
	return material


func _build_environment(_size_profile: Dictionary) -> void:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "SunnyWorldEnvironment"
	var environment: Environment = Environment.new()
	environment.resource_name = "SunnyIslandEnvironment"
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.48, 0.76, 0.98, 1.0)
	environment.background_energy_multiplier = 1.02
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.64, 0.80, 0.82, 1.0)
	environment.ambient_light_energy = 0.38
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.08
	environment.tonemap_agx_contrast = 1.18
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.05
	environment.adjustment_saturation = 1.10
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.76, 0.88, 0.98, 1.0)
	environment.fog_density = 0.0026
	environment.fog_depth_begin = _terrain_radius * 1.18
	environment.fog_depth_end = _terrain_radius * 3.6
	world_environment.environment = environment
	_generated_root.add_child(world_environment)
	_world_environment = world_environment

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "SunnyIslandSun"
	sun.light_color = Color(1.0, 0.88, 0.66, 1.0)
	sun.light_energy = 2.18
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = _terrain_radius * 3.0
	sun.directional_shadow_split_1 = 0.18
	sun.directional_shadow_fade_start = 0.94
	sun.directional_shadow_pancake_size = 12.0
	sun.rotation_degrees = Vector3(-49.0, -34.0, 0.0)
	_generated_root.add_child(sun)
	_sun_light = sun

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "SunnyIslandSkyFill"
	fill.light_color = Color(0.45, 0.66, 1.0, 1.0)
	fill.light_energy = 0.10
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-18.0, 138.0, 0.0)
	_generated_root.add_child(fill)
	_fill_light = fill
	_apply_day_lighting(_day_cycle_progress)


func _apply_day_lighting(cycle_progress: float) -> void:
	if _sun_light == null:
		return
	var day_arc: float = sin(clampf(cycle_progress, 0.0, 1.0) * PI)
	var elevation: float = lerpf(28.0, 62.0, day_arc)
	var azimuth: float = lerpf(-58.0, 64.0, clampf(cycle_progress, 0.0, 1.0))
	_sun_light.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
	_sun_light.light_color = Color(1.0, 0.82 + day_arc * 0.12, 0.58 + day_arc * 0.22, 1.0)
	_sun_light.light_energy = lerpf(1.72, 2.32, day_arc)
	if _fill_light != null:
		_fill_light.light_energy = lerpf(0.16, 0.08, day_arc)
		_fill_light.rotation_degrees = Vector3(-18.0, azimuth + 155.0, 0.0)
	if _world_environment != null and _world_environment.environment != null:
		var environment: Environment = _world_environment.environment
		environment.background_color = Color(0.43 + day_arc * 0.10, 0.70 + day_arc * 0.08, 0.94 + day_arc * 0.04, 1.0)
		environment.ambient_light_color = Color(0.58 + day_arc * 0.09, 0.74 + day_arc * 0.08, 0.80 + day_arc * 0.05, 1.0)
		environment.ambient_light_energy = lerpf(0.46, 0.34, day_arc)
		environment.tonemap_exposure = lerpf(1.02, 1.12, day_arc)


func _build_ocean(_size_profile: Dictionary) -> void:
	var ocean_root: Node3D = Node3D.new()
	ocean_root.name = "Ocean"
	_generated_root.add_child(ocean_root)

	var ocean_mesh: PlaneMesh = PlaneMesh.new()
	ocean_mesh.size = Vector2(_terrain_radius * 4.8, _terrain_radius * 4.8)
	ocean_mesh.subdivide_width = 96
	ocean_mesh.subdivide_depth = 96
	var ocean: MeshInstance3D = MeshInstance3D.new()
	ocean.name = "DynamicOceanSurface"
	ocean.mesh = ocean_mesh
	ocean.position = Vector3(0.0, _water_y, 0.0)
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var shader: Shader = load(OCEAN_SHADER_PATH) as Shader
	if shader != null:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("foam_radius", _terrain_radius * 0.94)
		material.set_shader_parameter("foam_width", maxf(5.5, _terrain_radius * 0.11))
		material.set_shader_parameter("wave_height", 0.26 + _terrain_radius * 0.0014)
		material.set_shader_parameter("wave_speed", 0.72)
		material.set_shader_parameter("wave_scale", 0.09)
		ocean.material_override = material
	ocean_root.add_child(ocean)


func _build_terrain(size_profile: Dictionary) -> void:
	var terrain_mesh: ArrayMesh = _create_island_mesh(_terrain_radius, _terrain_resolution)
	terrain_mesh.surface_set_material(0, _terrain_material)
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = "SunnyIslandTerrain"
	terrain.mesh = terrain_mesh
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_generated_root.add_child(terrain)

	var terrain_body: StaticBody3D = StaticBody3D.new()
	terrain_body.name = TERRAIN_BODY_NAME
	terrain_body.collision_layer = WORLD_LAYER
	terrain_body.collision_mask = 0
	terrain_body.add_to_group(WALKABLE_COLLISION_GROUP_NAME)
	terrain_body.add_to_group(PROCEDURAL_WALKABLE_GROUP_NAME)
	terrain_body.set_meta("procedural_map", "sunny_island")
	_generated_root.add_child(terrain_body)
	var terrain_shape: CollisionShape3D = CollisionShape3D.new()
	terrain_shape.name = "SunnyIslandTerrainShape"
	terrain_shape.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(terrain_shape)

	var beach_mesh: ArrayMesh = _create_beach_ring_mesh(float(size_profile.get("radius", _terrain_radius)))
	beach_mesh.surface_set_material(0, _sand_material)
	var beach: MeshInstance3D = MeshInstance3D.new()
	beach.name = "SoftBeachRing"
	beach.mesh = beach_mesh
	beach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	beach.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_generated_root.add_child(beach)


func _create_island_mesh(radius: float, resolution: int) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var diameter: float = radius * 2.0
	var step: float = diameter / float(resolution)
	for z_index in range(resolution):
		var z0: float = -radius + float(z_index) * step
		var z1: float = z0 + step
		for x_index in range(resolution):
			var x0: float = -radius + float(x_index) * step
			var x1: float = x0 + step
			var center: Vector2 = Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if center.length() > radius * 0.985:
				continue
			var p00: Vector3 = _terrain_point(x0, z0, radius)
			var p10: Vector3 = _terrain_point(x1, z0, radius)
			var p11: Vector3 = _terrain_point(x1, z1, radius)
			var p01: Vector3 = _terrain_point(x0, z1, radius)
			_add_terrain_triangle(surface_tool, p00, p10, p11, radius)
			_add_terrain_triangle(surface_tool, p00, p11, p01, radius)
	surface_tool.generate_normals()
	return surface_tool.commit()


func _create_beach_ring_mesh(radius: float) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count: int = 96
	var inner_radius: float = radius * 0.78
	var outer_radius: float = radius * 1.015
	for index in range(segment_count):
		var a0: float = TAU * float(index) / float(segment_count)
		var a1: float = TAU * float(index + 1) / float(segment_count)
		var inner0: Vector3 = _terrain_point(cos(a0) * inner_radius, sin(a0) * inner_radius, radius) + Vector3.UP * 0.028
		var outer0: Vector3 = _terrain_point(cos(a0) * outer_radius, sin(a0) * outer_radius, radius) + Vector3.UP * 0.035
		var inner1: Vector3 = _terrain_point(cos(a1) * inner_radius, sin(a1) * inner_radius, radius) + Vector3.UP * 0.028
		var outer1: Vector3 = _terrain_point(cos(a1) * outer_radius, sin(a1) * outer_radius, radius) + Vector3.UP * 0.035
		_add_plain_vertex(surface_tool, inner0, radius)
		_add_plain_vertex(surface_tool, outer0, radius)
		_add_plain_vertex(surface_tool, outer1, radius)
		_add_plain_vertex(surface_tool, inner0, radius)
		_add_plain_vertex(surface_tool, outer1, radius)
		_add_plain_vertex(surface_tool, inner1, radius)
	surface_tool.generate_normals()
	return surface_tool.commit()


func _terrain_point(x: float, z: float, radius: float) -> Vector3:
	var local: Vector2 = Vector2(x, z)
	var radial: float = clampf(local.length() / maxf(radius, 0.001), 0.0, 1.4)
	var island_falloff: float = 1.0 - smoothstep(0.66, 0.985, radial)
	var center_hill: float = pow(maxf(1.0 - radial, 0.0), 1.55) * 4.8
	var broad_noise: float = _value_noise_2d(x * 0.025, z * 0.025, generation_seed) * 2.0 - 1.0
	var detail_noise: float = _value_noise_2d(x * 0.075 + 17.0, z * 0.075 - 31.0, generation_seed + 73) * 2.0 - 1.0
	var ridge_a: float = exp(-pow((local - Vector2(radius * 0.20, -radius * 0.15)).length() / (radius * 0.26), 2.0)) * 2.2
	var ridge_b: float = exp(-pow((local - Vector2(-radius * 0.24, radius * 0.18)).length() / (radius * 0.32), 2.0)) * 1.75
	var beach_blend: float = smoothstep(0.78, 0.98, radial)
	var height: float = 0.18 + center_hill + ridge_a + ridge_b + broad_noise * 1.05 + detail_noise * 0.32
	height = lerpf(0.08 + detail_noise * 0.05, height, island_falloff)
	height = lerpf(height, 0.09 + detail_noise * 0.035, beach_blend)
	var stream_depth: float = SunnyIslandStreamBuilder.stream_depth_at(local, radius) * SunnyIslandStreamBuilder.stream_bed_depth(radius)
	height -= stream_depth
	return Vector3(x, height, z)


func _add_terrain_triangle(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, radius: float) -> void:
	_add_terrain_vertex(surface_tool, a, radius)
	_add_terrain_vertex(surface_tool, b, radius)
	_add_terrain_vertex(surface_tool, c, radius)


func _add_terrain_vertex(surface_tool: SurfaceTool, vertex: Vector3, radius: float) -> void:
	surface_tool.set_color(_terrain_color(vertex, radius))
	surface_tool.set_uv(Vector2(vertex.x / (radius * 2.0) + 0.5, vertex.z / (radius * 2.0) + 0.5))
	surface_tool.add_vertex(vertex)


func _add_plain_vertex(surface_tool: SurfaceTool, vertex: Vector3, radius: float) -> void:
	surface_tool.set_uv(Vector2(vertex.x / (radius * 2.0) + 0.5, vertex.z / (radius * 2.0) + 0.5))
	surface_tool.add_vertex(vertex)


func _terrain_color(vertex: Vector3, radius: float) -> Color:
	var radial: float = clampf(Vector2(vertex.x, vertex.z).length() / maxf(radius, 0.001), 0.0, 1.2)
	var noise_value: float = _value_noise_2d(vertex.x * 0.09, vertex.z * 0.09, generation_seed + 991)
	var low_grass: Color = Color(0.40, 0.68, 0.25, 1.0)
	var high_grass: Color = Color(0.25, 0.50, 0.18, 1.0)
	var fresh_grass: Color = Color(0.55, 0.80, 0.30, 1.0)
	var beach_grass: Color = Color(0.56, 0.70, 0.32, 1.0)
	var base: Color = low_grass.lerp(high_grass, clampf(vertex.y / 7.5, 0.0, 1.0))
	base = base.lerp(fresh_grass, clampf(noise_value * 0.42, 0.0, 0.42))
	base = base.lerp(beach_grass, smoothstep(0.72, 0.94, radial) * 0.60)
	return base


func _build_stream_channels(_size_profile: Dictionary) -> void:
	_stream_material = SunnyIslandStreamBuilder.build(
		_generated_root,
		_terrain_radius,
		generation_seed,
		STREAM_SHADER_PATH,
		_sand_material,
		ROCK_SCENES,
		Callable(self, "_terrain_point"),
		Callable(self, "_spawn_asset")
	)


func _build_paths(_size_profile: Dictionary) -> void:
	var path_root: Node3D = Node3D.new()
	path_root.name = "IslandPaths"
	_generated_root.add_child(path_root)
	_add_path_segment(path_root, Vector3(-_terrain_radius * 0.20, 0.0, -_terrain_radius * 0.10), Vector3(_terrain_radius * 0.56, 0.0, -_terrain_radius * 0.82), 4.6)
	_add_path_segment(path_root, Vector3(-_terrain_radius * 0.20, 0.0, -_terrain_radius * 0.10), Vector3(-_terrain_radius * 0.68, 0.0, _terrain_radius * 0.44), 3.8)
	_add_path_segment(path_root, Vector3(-_terrain_radius * 0.20, 0.0, -_terrain_radius * 0.10), Vector3(_terrain_radius * 0.64, 0.0, _terrain_radius * 0.40), 3.5)
	_add_path_segment(path_root, Vector3(-_terrain_radius * 0.34, 0.0, -_terrain_radius * 0.18), Vector3(_terrain_radius * 0.22, 0.0, _terrain_radius * 0.12), 4.1)


func _add_path_segment(parent: Node3D, from: Vector3, to: Vector3, width: float) -> void:
	var delta: Vector3 = to - from
	var length: float = Vector2(delta.x, delta.z).length()
	if length < 0.01:
		return
	var center_x: float = (from.x + to.x) * 0.5
	var center_z: float = (from.z + to.z) * 0.5
	var center_y: float = _terrain_point(center_x, center_z, _terrain_radius).y + 0.085
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(width, 0.055, length)
	var segment: MeshInstance3D = MeshInstance3D.new()
	segment.name = "PathSegment"
	segment.mesh = mesh
	segment.material_override = _path_material
	segment.position = Vector3(center_x, center_y, center_z)
	segment.rotation.y = atan2(delta.x, delta.z)
	segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(segment)


func _build_landmarks(_size_profile: Dictionary) -> void:
	var village_root: Node3D = Node3D.new()
	village_root.name = "IslandVillage"
	_generated_root.add_child(village_root)
	_add_cabana(village_root, Vector3(-8.0, 0.0, -6.0), 0.35, Vector3(4.8, 2.4, 4.2), _roof_material)
	_add_cabana(village_root, Vector3(4.5, 0.0, -9.5), -0.45, Vector3(4.3, 2.1, 3.8), _cloth_material)
	_add_cabana(village_root, Vector3(-14.0, 0.0, 5.5), 1.05, Vector3(4.0, 2.0, 3.5), _roof_material)
	_add_cabana(village_root, Vector3(10.5, 0.0, 4.5), -1.0, Vector3(3.9, 2.0, 3.6), _cloth_material)
	_add_box_prop(village_root, "CentralCrateStack", Vector3(0.4, 0.0, -1.4), Vector3(2.5, 1.5, 1.9), 0.18, _wood_material, true)
	_add_box_prop(village_root, "MarketAwning", Vector3(-3.0, 0.0, 2.5), Vector3(6.5, 0.35, 3.4), -0.12, _cloth_material, false, 2.85)

	var dock_root: Node3D = Node3D.new()
	dock_root.name = "BeachDock"
	_generated_root.add_child(dock_root)
	_spawn_asset(dock_root, DOCK_SCENE, "SouthDock", Vector3(0.0, 0.0, -_terrain_radius * 0.92), 0.0, Vector3(2.3, 2.3, 2.3), true)
	_spawn_asset(dock_root, DOCK_SMALL_SCENE, "EastDock", Vector3(_terrain_radius * 0.78, 0.0, _terrain_radius * 0.18), -PI * 0.48, Vector3(1.7, 1.7, 1.7), true)
	_add_box_prop(dock_root, "SouthDockCollision", Vector3(0.0, 0.0, -_terrain_radius * 0.93), Vector3(7.0, 0.6, 9.5), 0.0, _wood_material, true, 0.38)
	_spawn_asset(dock_root, BOAT_SMALL_SCENE, "SmallRowBoat", Vector3(-7.2, _water_y + 0.05, -_terrain_radius * 1.05), 0.35, Vector3(2.2, 2.2, 2.2), false)
	_spawn_asset(dock_root, BOAT_LARGE_SCENE, "LargeRowBoat", Vector3(9.0, _water_y + 0.05, -_terrain_radius * 1.10), -0.28, Vector3(2.0, 2.0, 2.0), false)


func _add_cabana(parent: Node3D, base_position: Vector3, yaw: float, size: Vector3, roof_material: Material) -> void:
	var surface_y: float = _terrain_point(base_position.x, base_position.z, _terrain_radius).y
	var body_position: Vector3 = Vector3(base_position.x, surface_y + size.y * 0.5, base_position.z)
	_add_box_visual(parent, "CabanaBody", body_position, size, yaw, _wood_material)
	_add_box_collision(parent, "CabanaBodyCollision", body_position, size, yaw)
	var roof_size: Vector3 = Vector3(size.x * 1.18, size.y * 0.34, size.z * 1.18)
	var roof_position: Vector3 = Vector3(base_position.x, surface_y + size.y + roof_size.y * 0.55, base_position.z)
	_add_box_visual(parent, "CabanaRoof", roof_position, roof_size, yaw, roof_material)
	var post_size: Vector3 = Vector3(0.32, size.y * 0.95, 0.32)
	var offsets: Array[Vector3] = [
		Vector3(size.x * 0.43, 0.0, size.z * 0.43),
		Vector3(-size.x * 0.43, 0.0, size.z * 0.43),
		Vector3(size.x * 0.43, 0.0, -size.z * 0.43),
		Vector3(-size.x * 0.43, 0.0, -size.z * 0.43),
	]
	var yaw_basis: Basis = Basis(Vector3.UP, yaw)
	for index in range(offsets.size()):
		var local_offset: Vector3 = yaw_basis * offsets[index]
		var post_position: Vector3 = Vector3(base_position.x + local_offset.x, surface_y + post_size.y * 0.5, base_position.z + local_offset.z)
		_add_box_visual(parent, "CabanaPost_%02d" % index, post_position, post_size, yaw, _wood_material)


func _add_box_prop(parent: Node3D, prop_name: String, base_position: Vector3, size: Vector3, yaw: float, material: Material, collision_enabled: bool, y_offset: float = 0.0) -> void:
	var surface_y: float = _terrain_point(base_position.x, base_position.z, _terrain_radius).y + y_offset
	var center: Vector3 = Vector3(base_position.x, surface_y + size.y * 0.5, base_position.z)
	_add_box_visual(parent, prop_name, center, size, yaw, material)
	if collision_enabled:
		_add_box_collision(parent, prop_name + "Collision", center, size, yaw)


func _add_box_visual(parent: Node3D, node_name: String, center: Vector3, size: Vector3, yaw: float, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	instance.rotation.y = yaw
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


func _add_box_collision(parent: Node3D, node_name: String, center: Vector3, size: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = center
	body.rotation.y = yaw
	parent.add_child(body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)


func _build_decorations(size_profile: Dictionary) -> void:
	var decor_root: Node3D = Node3D.new()
	decor_root.name = "BeachDecorations"
	_generated_root.add_child(decor_root)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(generation_seed) + int(_terrain_radius * 17.0)
	var decor_count: int = int(size_profile.get("decor_count", 18))
	for index in range(decor_count):
		var angle: float = TAU * float(index) / float(decor_count) + rng.randf_range(-0.16, 0.16)
		var radius: float = _terrain_radius * rng.randf_range(0.78, 0.98)
		var decor_position: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var rock_scene: String = ROCK_SCENES[index % ROCK_SCENES.size()]
		var rock_scale: float = rng.randf_range(1.1, 2.6)
		_spawn_asset(decor_root, rock_scene, "BeachRock_%02d" % index, decor_position, rng.randf_range(-PI, PI), Vector3(rock_scale, rock_scale, rock_scale), true)


func _build_temple_ruins(size_profile: Dictionary) -> void:
	var temple_root: Node3D = Node3D.new()
	temple_root.name = "TempleRuinsDecorations"
	_generated_root.add_child(temple_root)
	var tier_name: String = str(size_profile.get("tier_name", "24_player"))
	var tier_index: int = 2
	if tier_name == "8_player":
		tier_index = 0
	elif tier_name == "12_player":
		tier_index = 1
	var radius_scale: float = clampf(_terrain_radius / 84.0, 0.72, 1.0)
	var target_count: int = 6
	var site_specs: Array[Dictionary] = _temple_site_specs(tier_index)
	var spawned: int = 0
	for index in range(site_specs.size()):
		if spawned >= target_count:
			break
		var spec: Dictionary = site_specs[index]
		var local_position: Vector2 = spec.get("p", Vector2.ZERO) * _terrain_radius
		var footprint: float = float(spec.get("footprint", 10.5)) * radius_scale
		var stream_bank_site: bool = bool(spec.get("stream_bank", false))
		var placement_passed: bool = _can_place_temple_ruin(local_position, footprint, stream_bank_site)
		var site: Node3D = Node3D.new()
		site.name = "TempleRuinSite_%02d" % spawned
		site.set_meta("temple_kind", str(spec.get("kind", "central_courtyard")))
		site.set_meta("placement_passed", placement_passed)
		site.position = Vector3(local_position.x, _terrain_point(local_position.x, local_position.y, _terrain_radius).y + 0.06, local_position.y)
		site.rotation.y = float(spec.get("yaw", 0.0))
		temple_root.add_child(site)
		_build_temple_ruin_site(site, spawned, radius_scale, spec)
		spawned += 1


func _temple_site_specs(tier_index: int) -> Array[Dictionary]:
	var base_specs: Array[Dictionary] = [
		{"p": Vector2(-0.04, 0.14), "yaw": -0.36, "footprint": 13.2, "tile": 4.25},
		{"p": Vector2(-0.42, 0.24), "yaw": -0.92, "footprint": 10.8, "tile": 3.45, "stream_bank": true},
		{"p": Vector2(0.42, -0.23), "yaw": 2.30, "footprint": 10.4, "tile": 3.30, "stream_bank": true},
		{"p": Vector2(0.58, 0.10), "yaw": 0.38, "footprint": 10.0, "tile": 3.25, "stream_bank": true},
		{"p": Vector2(-0.17, 0.38), "yaw": 0.94, "footprint": 9.8, "tile": 3.20},
		{"p": Vector2(0.34, -0.52), "yaw": 2.20, "footprint": 9.6, "tile": 3.15, "stream_bank": true},
	]
	var tier_kinds: Array[String] = ["central_courtyard", "river_gate", "stepping_terrace", "watch_tower", "colonnade", "small_shrine"]
	var tile_multiplier: float = 1.0
	if tier_index <= 0:
		tier_kinds = ["small_shrine", "river_gate", "stepping_terrace", "colonnade", "small_shrine", "river_gate"]
		tile_multiplier = 0.84
	elif tier_index == 1:
		tier_kinds = ["central_courtyard", "river_gate", "stepping_terrace", "colonnade", "watch_tower", "small_shrine"]
		tile_multiplier = 0.94
	else:
		tier_kinds = ["central_courtyard", "river_gate", "stepping_terrace", "watch_tower", "colonnade", "central_courtyard"]
		tile_multiplier = 1.0
	var result: Array[Dictionary] = []
	for index in range(base_specs.size()):
		var spec: Dictionary = base_specs[index].duplicate()
		spec["kind"] = tier_kinds[index]
		spec["tile"] = float(spec.get("tile", 3.5)) * tile_multiplier
		spec["footprint"] = float(spec.get("footprint", 10.0)) * tile_multiplier
		result.append(spec)
	return result


func _temple_tier_index_from_radius() -> int:
	if _terrain_radius <= 50.0:
		return 0
	if _terrain_radius <= 70.0:
		return 1
	return 2


func _can_place_temple_ruin(local_position: Vector2, footprint: float, stream_bank_site: bool) -> bool:
	if local_position.length() > _terrain_radius * 0.70:
		return false
	var stream_depth: float = SunnyIslandStreamBuilder.stream_depth_at(local_position, _terrain_radius)
	if stream_bank_site:
		if stream_depth > 0.72:
			return false
	else:
		if stream_depth > 0.04:
			return false
	if _distance_to_path_network(local_position) < maxf(2.8, footprint * 0.22):
		return false
	var village_centers: Array[Vector2] = [Vector2(-8.0, -6.0), Vector2(4.5, -9.5), Vector2(-14.0, 5.5), Vector2(10.5, 4.5), Vector2(0.4, -1.4)]
	for center in village_centers:
		if local_position.distance_to(center) < footprint * 0.55:
			return false
	return true


func _build_temple_ruin_site(parent: Node3D, site_index: int, radius_scale: float, spec: Dictionary) -> void:
	var site_kind: String = str(spec.get("kind", "central_courtyard"))
	match site_kind:
		"river_gate":
			_build_temple_river_gate_site(parent, site_index, radius_scale, spec)
		"stepping_terrace":
			_build_temple_stepping_terrace_site(parent, site_index, radius_scale, spec)
		"watch_tower":
			_build_temple_watch_tower_site(parent, site_index, radius_scale, spec)
		"colonnade":
			_build_temple_colonnade_site(parent, site_index, radius_scale, spec)
		"small_shrine":
			_build_temple_small_shrine_site(parent, site_index, radius_scale, spec)
		_:
			_build_temple_central_courtyard_site(parent, site_index, radius_scale, spec)


func _build_temple_central_courtyard_site(parent: Node3D, site_index: int, radius_scale: float, spec: Dictionary) -> void:
	var tile_size: float = float(spec.get("tile", 4.2)) * radius_scale
	var floor_top_y: float = 0.18
	var floor_offsets: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(-tile_size, 0.0, 0.0),
		Vector3(tile_size, 0.0, 0.0),
		Vector3(0.0, 0.0, -tile_size),
		Vector3(0.0, 0.0, tile_size),
	]
	for floor_index in range(floor_offsets.size()):
		var floor_offset: Vector3 = floor_offsets[floor_index] + Vector3.UP * floor_top_y
		var floor_mesh: String = TEMPLE_FLOOR_MESH if floor_index == 0 else TEMPLE_RUINED_FLOOR_MESH
		_spawn_temple_mesh(parent, floor_mesh, "TempleCourtyardFloor_%d_%d" % [site_index, floor_index], floor_offset, float(floor_index) * 0.35, Vector3(tile_size, 0.9 * radius_scale, tile_size))

	var wall_height: float = 1.62 * radius_scale
	var tall_wall_height: float = 2.28 * radius_scale
	var wall_thickness: float = 0.54 * radius_scale
	_add_temple_wall(parent, "TempleCourtyardBackWall_%d" % site_index, TEMPLE_RUINED_WALL_FULL_MESH, Vector3(0.0, floor_top_y, -tile_size * 1.32), 0.0, tile_size * 2.15, tall_wall_height, wall_thickness, 1.0, 0.2)
	_add_temple_wall(parent, "TempleCourtyardLeftWall_%d" % site_index, TEMPLE_RUINED_WALL_HALF_MESH, Vector3(-tile_size * 1.26, floor_top_y, -tile_size * 0.06), PI * 0.5, tile_size * 1.42, wall_height, wall_thickness, 0.740669, 0.2)
	_add_temple_wall(parent, "TempleCourtyardRightWall_%d" % site_index, TEMPLE_RUINED_WALL_HALF_MESH, Vector3(tile_size * 1.26, floor_top_y, -tile_size * 0.16), PI * 0.5, tile_size * 1.20, wall_height, wall_thickness, 0.740669, 0.2)
	_add_temple_arch(parent, "TempleCourtyardArch_%d" % site_index, Vector3(0.0, floor_top_y, tile_size * 1.28), PI, tile_size * 1.05, 2.75 * radius_scale, 0.78 * radius_scale)

	var pillar_height: float = 2.18 * radius_scale
	var pillar_size: float = 0.72 * radius_scale
	var pillar_positions: Array[Vector3] = [
		Vector3(-tile_size * 0.72, floor_top_y, -tile_size * 0.72),
		Vector3(tile_size * 0.72, floor_top_y, -tile_size * 0.72),
		Vector3(-tile_size * 0.78, floor_top_y, tile_size * 0.50),
		Vector3(tile_size * 0.78, floor_top_y, tile_size * 0.50),
	]
	for pillar_index in range(pillar_positions.size()):
		_add_temple_pillar(parent, "TempleCourtyardPillar_%d_%d" % [site_index, pillar_index], pillar_positions[pillar_index], pillar_size, pillar_height)
	_spawn_temple_mesh(parent, TEMPLE_RUG_MESHES[site_index % TEMPLE_RUG_MESHES.size()], "TempleCourtyardRug_%d" % site_index, Vector3(0.0, floor_top_y + 0.03, 0.0), 0.0, Vector3.ONE * (tile_size * 1.35))
	_spawn_temple_mesh(parent, TEMPLE_PRESSURE_PLATE_MESH, "TempleCourtyardPlate_%d" % site_index, Vector3(0.0, floor_top_y + 0.08, 0.0), 0.0, Vector3.ONE * (1.55 * radius_scale))
	_add_temple_tower(parent, "TempleCourtyardTower_%d" % site_index, Vector3(tile_size * 1.55, floor_top_y, -tile_size * 1.28), -0.18, 0.95 * radius_scale)
	_spawn_temple_mesh(parent, TEMPLE_RUBBLE_MESHES[site_index % TEMPLE_RUBBLE_MESHES.size()], "TempleCourtyardRubble_%d" % site_index, Vector3(-tile_size * 1.44, floor_top_y + 0.02, tile_size * 0.86), 0.35, Vector3.ONE * (1.45 * radius_scale))
	_add_temple_box_collision(parent, "TempleCourtyardRubbleCollision_%d" % site_index, Vector3(-tile_size * 1.44, floor_top_y + 0.18 * radius_scale, tile_size * 0.86), Vector3(0.82, 0.36, 0.68) * radius_scale, 0.35)
	_spawn_temple_mesh(parent, TEMPLE_VASE_MESHES[site_index % TEMPLE_VASE_MESHES.size()], "TempleCourtyardVase_%d" % site_index, Vector3(-tile_size * 0.36, floor_top_y, tile_size * 1.18), -0.45, Vector3.ONE * (2.2 * radius_scale))


func _build_temple_river_gate_site(parent: Node3D, site_index: int, radius_scale: float, spec: Dictionary) -> void:
	var tile_size: float = float(spec.get("tile", 3.4)) * radius_scale
	var floor_top_y: float = 0.16
	_spawn_temple_mesh(parent, TEMPLE_FLOOR_MESH, "TempleRiverGatePlatform_%d_A" % site_index, Vector3(0.0, floor_top_y, 0.0), 0.0, Vector3(tile_size * 1.25, 0.86 * radius_scale, tile_size * 1.25))
	_spawn_temple_mesh(parent, TEMPLE_RUINED_FLOOR_MESH, "TempleRiverGatePlatform_%d_B" % site_index, Vector3(0.0, floor_top_y + 0.02, -tile_size * 0.92), 0.0, Vector3(tile_size * 1.05, 0.86 * radius_scale, tile_size * 0.82))
	_add_temple_arch(parent, "TempleRiverGateArch_%d" % site_index, Vector3(0.0, floor_top_y, tile_size * 0.72), PI, tile_size * 1.18, 2.55 * radius_scale, 0.82 * radius_scale)
	_add_temple_wall(parent, "TempleRiverGateLeftWing_%d" % site_index, TEMPLE_RUINED_WALL_HALF_MESH, Vector3(-tile_size * 0.98, floor_top_y, -tile_size * 0.26), PI * 0.5, tile_size * 0.92, 1.28 * radius_scale, 0.42 * radius_scale, 0.740669, 0.2)
	_add_temple_wall(parent, "TempleRiverGateRightWing_%d" % site_index, TEMPLE_RUINED_WALL_HALF_MESH, Vector3(tile_size * 0.98, floor_top_y, -tile_size * 0.12), PI * 0.5, tile_size * 0.72, 1.14 * radius_scale, 0.42 * radius_scale, 0.740669, 0.2)
	_add_temple_pillar(parent, "TempleRiverGatePillarA_%d" % site_index, Vector3(-tile_size * 0.62, floor_top_y, tile_size * 1.02), 0.62 * radius_scale, 1.95 * radius_scale)
	_add_temple_pillar(parent, "TempleRiverGatePillarB_%d" % site_index, Vector3(tile_size * 0.62, floor_top_y, tile_size * 1.02), 0.62 * radius_scale, 1.95 * radius_scale)
	_spawn_temple_mesh(parent, TEMPLE_BRIDGE_RAMP_MESH, "TempleRiverGateRamp_%d" % site_index, Vector3(0.0, floor_top_y - 0.10, -tile_size * 1.54), 0.0, Vector3(tile_size * 0.94, 0.52 * radius_scale, tile_size * 0.74))
	_spawn_temple_mesh(parent, TEMPLE_BALCONY_RAMP_MESH, "TempleRiverGateBrokenRail_%d" % site_index, Vector3(tile_size * 0.72, floor_top_y + 0.02, -tile_size * 1.20), PI * 0.5, Vector3(tile_size * 0.62, 0.42 * radius_scale, 0.62 * radius_scale))
	_spawn_temple_mesh(parent, TEMPLE_RUBBLE_MESHES[(site_index + 1) % TEMPLE_RUBBLE_MESHES.size()], "TempleRiverGateRubble_%d" % site_index, Vector3(-tile_size * 1.12, floor_top_y + 0.02, -tile_size * 1.08), -0.45, Vector3.ONE * (1.18 * radius_scale))


func _build_temple_stepping_terrace_site(parent: Node3D, site_index: int, radius_scale: float, spec: Dictionary) -> void:
	var tile_size: float = float(spec.get("tile", 3.3)) * radius_scale
	var floor_top_y: float = 0.15
	for step_index in range(3):
		var z_offset: float = (float(step_index) - 1.0) * tile_size * 0.84
		var y_offset: float = floor_top_y + float(step_index) * 0.13 * radius_scale
		_spawn_temple_mesh(parent, TEMPLE_RUINED_FLOOR_MESH, "TempleTerraceFloor_%d_%d" % [site_index, step_index], Vector3(0.0, y_offset, z_offset), 0.08 * float(step_index), Vector3(tile_size * (1.35 - float(step_index) * 0.12), 0.78 * radius_scale, tile_size * 0.86))
	_spawn_temple_mesh(parent, TEMPLE_STAIRS_MESH, "TempleTerraceSteps_%d" % site_index, Vector3(0.0, floor_top_y - 0.04, tile_size * 1.42), PI, Vector3(tile_size * 0.86, 0.48 * radius_scale, tile_size * 0.78))
	_add_temple_wall(parent, "TempleTerraceBackWall_%d" % site_index, TEMPLE_RUINED_WALL_HALF_MESH, Vector3(0.0, floor_top_y + 0.20, -tile_size * 1.38), 0.0, tile_size * 1.64, 1.26 * radius_scale, 0.42 * radius_scale, 0.740669, 0.2)
	_add_temple_curved_wall(parent, "TempleTerraceCurveA_%d" % site_index, TEMPLE_CURVED_SMALL_WALL_MESH, Vector3(-tile_size * 0.82, floor_top_y + 0.12, tile_size * 0.34), -0.15, 1.15 * radius_scale)
	_add_temple_curved_wall(parent, "TempleTerraceCurveB_%d" % site_index, TEMPLE_CURVED_SMALL_WALL_MESH, Vector3(tile_size * 0.82, floor_top_y + 0.12, -tile_size * 0.16), PI + 0.24, 1.05 * radius_scale)
	_spawn_temple_mesh(parent, TEMPLE_LEVER_MESH, "TempleTerraceLever_%d" % site_index, Vector3(tile_size * 0.36, floor_top_y + 0.08, -tile_size * 0.42), -0.70, Vector3.ONE * (1.55 * radius_scale))
	_spawn_temple_mesh(parent, TEMPLE_VASE_MESHES[(site_index + 1) % TEMPLE_VASE_MESHES.size()], "TempleTerraceVase_%d" % site_index, Vector3(-tile_size * 0.42, floor_top_y, tile_size * 0.66), 0.30, Vector3.ONE * (1.85 * radius_scale))


func _build_temple_watch_tower_site(parent: Node3D, site_index: int, radius_scale: float, spec: Dictionary) -> void:
	var tile_size: float = float(spec.get("tile", 3.25)) * radius_scale
	var floor_top_y: float = 0.16
	_spawn_temple_mesh(parent, TEMPLE_CURVED_FLOOR_MESH, "TempleWatchFloor_%d_A" % site_index, Vector3(0.0, floor_top_y, 0.0), 0.0, Vector3(tile_size * 1.36, 0.86 * radius_scale, tile_size * 1.36))
	_add_temple_tower(parent, "TempleWatchTower_%d" % site_index, Vector3(0.0, floor_top_y, -tile_size * 0.36), 0.20, 0.82 * radius_scale)
	_spawn_temple_mesh(parent, TEMPLE_TOWER_TOP_MESH, "TempleWatchTowerTop_%d" % site_index, Vector3(0.0, floor_top_y + 2.54 * radius_scale, -tile_size * 0.36), 0.20, Vector3.ONE * (0.70 * radius_scale))
	_add_temple_wall(parent, "TempleWatchBrokenWallA_%d" % site_index, TEMPLE_RUINED_WALL_HALF_MESH, Vector3(-tile_size * 1.04, floor_top_y, tile_size * 0.36), PI * 0.5, tile_size * 0.98, 1.18 * radius_scale, 0.42 * radius_scale, 0.740669, 0.2)
	_add_temple_wall(parent, "TempleWatchBrokenWallB_%d" % site_index, TEMPLE_RUINED_WALL_HALF_MESH, Vector3(tile_size * 1.02, floor_top_y, tile_size * 0.24), PI * 0.5, tile_size * 0.78, 1.05 * radius_scale, 0.42 * radius_scale, 0.740669, 0.2)
	_spawn_temple_mesh(parent, TEMPLE_STAIRS_MESH, "TempleWatchSteps_%d" % site_index, Vector3(0.0, floor_top_y - 0.08, tile_size * 1.30), PI, Vector3(tile_size * 0.78, 0.42 * radius_scale, tile_size * 0.70))
	_spawn_temple_mesh(parent, TEMPLE_FLAG_MESHES[site_index % TEMPLE_FLAG_MESHES.size()], "TempleWatchFlag_%d" % site_index, Vector3(tile_size * 0.86, floor_top_y + 0.06, -tile_size * 1.24), 0.35, Vector3.ONE * (1.45 * radius_scale))


func _build_temple_colonnade_site(parent: Node3D, site_index: int, radius_scale: float, spec: Dictionary) -> void:
	var tile_size: float = float(spec.get("tile", 3.2)) * radius_scale
	var floor_top_y: float = 0.15
	for floor_index in range(3):
		_spawn_temple_mesh(parent, TEMPLE_RUINED_FLOOR_MESH, "TempleColonnadeFloor_%d_%d" % [site_index, floor_index], Vector3((float(floor_index) - 1.0) * tile_size * 0.82, floor_top_y, 0.0), 0.0, Vector3(tile_size * 0.88, 0.80 * radius_scale, tile_size * 1.05))
	for pillar_index in range(6):
		var column: int = pillar_index % 3
		var row: int = int(float(pillar_index) / 3.0)
		var x_offset: float = (float(column) - 1.0) * tile_size * 0.82
		var z_offset: float = -tile_size * 0.58 if row == 0 else tile_size * 0.58
		_add_temple_pillar(parent, "TempleColonnadePillar_%d_%d" % [site_index, pillar_index], Vector3(x_offset, floor_top_y, z_offset), 0.58 * radius_scale, 1.95 * radius_scale)
	_add_temple_arch(parent, "TempleColonnadeArch_%d" % site_index, Vector3(0.0, floor_top_y, -tile_size * 1.08), 0.0, tile_size * 1.02, 2.36 * radius_scale, 0.72 * radius_scale)
	_spawn_temple_mesh(parent, TEMPLE_RUG_MESHES[(site_index + 2) % TEMPLE_RUG_MESHES.size()], "TempleColonnadeRug_%d" % site_index, Vector3(0.0, floor_top_y + 0.03, 0.0), PI * 0.5, Vector3(tile_size * 1.55, 1.0, tile_size * 0.84))
	_spawn_temple_mesh(parent, TEMPLE_RUBBLE_MESHES[site_index % TEMPLE_RUBBLE_MESHES.size()], "TempleColonnadeRubble_%d" % site_index, Vector3(tile_size * 1.32, floor_top_y + 0.02, tile_size * 0.86), 0.62, Vector3.ONE * (1.15 * radius_scale))
	_add_temple_box_collision(parent, "TempleColonnadeRubbleCollision_%d" % site_index, Vector3(tile_size * 1.32, floor_top_y + 0.16 * radius_scale, tile_size * 0.86), Vector3(0.68, 0.30, 0.58) * radius_scale, 0.62)


func _build_temple_small_shrine_site(parent: Node3D, site_index: int, radius_scale: float, spec: Dictionary) -> void:
	var tile_size: float = float(spec.get("tile", 3.15)) * radius_scale
	var floor_top_y: float = 0.15
	_spawn_temple_mesh(parent, TEMPLE_CURVED_FLOOR_MESH, "TempleShrineFloor_%d" % site_index, Vector3(0.0, floor_top_y, 0.0), 0.0, Vector3(tile_size * 1.24, 0.84 * radius_scale, tile_size * 1.24))
	_add_temple_curved_wall(parent, "TempleShrineCurveA_%d" % site_index, TEMPLE_CURVED_LARGE_WALL_MESH, Vector3(-tile_size * 0.54, floor_top_y + 0.08, -tile_size * 0.46), 0.14, 0.82 * radius_scale)
	_add_temple_curved_wall(parent, "TempleShrineCurveB_%d" % site_index, TEMPLE_CURVED_SMALL_WALL_MESH, Vector3(tile_size * 0.58, floor_top_y + 0.08, -tile_size * 0.34), PI + 0.44, 0.92 * radius_scale)
	_add_temple_pillar(parent, "TempleShrinePillarA_%d" % site_index, Vector3(-tile_size * 0.52, floor_top_y, tile_size * 0.70), 0.54 * radius_scale, 1.62 * radius_scale)
	_add_temple_pillar(parent, "TempleShrinePillarB_%d" % site_index, Vector3(tile_size * 0.52, floor_top_y, tile_size * 0.70), 0.54 * radius_scale, 1.62 * radius_scale)
	_spawn_temple_mesh(parent, TEMPLE_PRESSURE_PLATE_MESH, "TempleShrinePlate_%d" % site_index, Vector3(0.0, floor_top_y + 0.08, -tile_size * 0.08), 0.0, Vector3.ONE * (1.35 * radius_scale))
	_spawn_temple_mesh(parent, TEMPLE_LEVER_MESH, "TempleShrineLever_%d" % site_index, Vector3(tile_size * 0.34, floor_top_y + 0.06, -tile_size * 0.52), -0.36, Vector3.ONE * (1.32 * radius_scale))
	_spawn_temple_mesh(parent, TEMPLE_STAIRS_MESH, "TempleShrineSteps_%d" % site_index, Vector3(0.0, floor_top_y - 0.08, tile_size * 1.16), PI, Vector3(tile_size * 0.72, 0.40 * radius_scale, tile_size * 0.58))


func _add_temple_arch(parent: Node3D, node_name: String, base_position: Vector3, yaw: float, width: float, height: float, depth: float) -> void:
	_spawn_temple_mesh(parent, TEMPLE_ARCH_MESH, node_name, base_position, yaw, Vector3(width, height / 2.0, depth / 1.1))
	var side_width: float = maxf(0.28, width * 0.18)
	var side_height: float = height * 0.72
	var side_offset: float = width * 0.5 - side_width * 0.5
	var left_center: Vector3 = base_position + _rotated_local_offset(Vector3(-side_offset, side_height * 0.5, 0.0), yaw)
	var right_center: Vector3 = base_position + _rotated_local_offset(Vector3(side_offset, side_height * 0.5, 0.0), yaw)
	var top_center: Vector3 = base_position + Vector3.UP * (height * 0.88)
	_add_temple_box_collision(parent, node_name + "LeftCollision", left_center, Vector3(side_width, side_height, depth * 0.76), yaw)
	_add_temple_box_collision(parent, node_name + "RightCollision", right_center, Vector3(side_width, side_height, depth * 0.76), yaw)
	_add_temple_box_collision(parent, node_name + "TopCollision", top_center, Vector3(width * 0.82, height * 0.18, depth * 0.70), yaw)


func _add_temple_curved_wall(parent: Node3D, node_name: String, mesh_path: String, base_position: Vector3, yaw: float, scale_value: float) -> void:
	_spawn_temple_mesh(parent, mesh_path, node_name, base_position, yaw, Vector3.ONE * scale_value)
	var source_span: float = 1.1
	if mesh_path == TEMPLE_CURVED_LARGE_WALL_MESH:
		source_span = 2.1
	var span: float = source_span * scale_value
	var height: float = 1.0 * scale_value
	var segment_size: Vector3 = Vector3(span * 0.42, height, 0.36 * scale_value)
	var left_center: Vector3 = base_position + _rotated_local_offset(Vector3(-span * 0.22, height * 0.5, 0.06 * scale_value), yaw)
	var right_center: Vector3 = base_position + _rotated_local_offset(Vector3(span * 0.22, height * 0.5, -0.06 * scale_value), yaw)
	_add_temple_box_collision(parent, node_name + "LeftCollision", left_center, segment_size, yaw - 0.28)
	_add_temple_box_collision(parent, node_name + "RightCollision", right_center, segment_size, yaw + 0.28)


func _add_temple_wall(parent: Node3D, node_name: String, mesh_path: String, base_position: Vector3, yaw: float, length: float, height: float, thickness: float, source_height: float, source_depth: float) -> void:
	var mesh_scale: Vector3 = Vector3(length, height / maxf(source_height, 0.05), thickness / maxf(source_depth, 0.05))
	_spawn_temple_mesh(parent, mesh_path, node_name, base_position, yaw, mesh_scale)
	_add_temple_box_collision(parent, node_name + "Collision", base_position + Vector3.UP * (height * 0.5), Vector3(length * 0.94, height, thickness), yaw)


func _add_temple_doorway(parent: Node3D, node_name: String, base_position: Vector3, yaw: float, width: float, height: float, depth: float) -> void:
	_spawn_temple_mesh(parent, TEMPLE_DOORWAY_MESH, node_name, base_position, yaw, Vector3(width / 1.2, height / 2.0, depth / 0.4))
	var side_width: float = maxf(0.34, width * 0.18)
	var side_height: float = height * 0.82
	var side_offset: float = width * 0.5 - side_width * 0.5
	var left_center: Vector3 = base_position + _rotated_local_offset(Vector3(-side_offset, side_height * 0.5, 0.0), yaw)
	var right_center: Vector3 = base_position + _rotated_local_offset(Vector3(side_offset, side_height * 0.5, 0.0), yaw)
	_add_temple_box_collision(parent, node_name + "LeftCollision", left_center, Vector3(side_width, side_height, depth * 0.85), yaw)
	_add_temple_box_collision(parent, node_name + "RightCollision", right_center, Vector3(side_width, side_height, depth * 0.85), yaw)


func _add_temple_pillar(parent: Node3D, node_name: String, base_position: Vector3, width: float, height: float) -> void:
	_spawn_temple_mesh(parent, TEMPLE_PILLAR_MESH, node_name, base_position, 0.0, Vector3(width / 0.6, height, width / 0.6))
	_add_temple_box_collision(parent, node_name + "Collision", base_position + Vector3.UP * (height * 0.5), Vector3(width, height, width), 0.0)


func _add_temple_tower(parent: Node3D, node_name: String, base_position: Vector3, yaw: float, scale_value: float) -> void:
	_spawn_temple_mesh(parent, TEMPLE_TOWER_MESH, node_name, base_position, yaw, Vector3.ONE * scale_value)
	_add_temple_box_collision(parent, node_name + "Collision", base_position + Vector3.UP * (1.55 * scale_value), Vector3(2.65, 3.10, 2.65) * scale_value, yaw)


func _spawn_temple_mesh(parent: Node3D, mesh_path: String, node_name: String, local_position: Vector3, yaw: float, scale_value: Vector3) -> MeshInstance3D:
	if not ResourceLoader.exists(mesh_path):
		return null
	var resource: Resource = ResourceLoader.load(mesh_path)
	if resource == null or not resource is Mesh:
		return null
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = resource as Mesh
	instance.position = local_position
	instance.rotation.y = yaw
	instance.scale = scale_value
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(instance)
	return instance


func _add_temple_box_collision(parent: Node3D, node_name: String, local_center: Vector3, size: Vector3, yaw: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = local_center
	body.rotation.y = yaw
	parent.add_child(body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "Shape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	shape.margin = 0.01
	shape_node.shape = shape
	body.add_child(shape_node)


func _rotated_local_offset(offset: Vector3, yaw: float) -> Vector3:
	var rotated: Vector3 = Basis(Vector3.UP, yaw) * Vector3(offset.x, 0.0, offset.z)
	rotated.y = offset.y
	return rotated


func _is_near_temple_ruin(local_position: Vector2, clearance: float) -> bool:
	var radius_scale: float = clampf(_terrain_radius / 84.0, 0.72, 1.0)
	for spec: Dictionary in _temple_site_specs(_temple_tier_index_from_radius()):
		var center: Vector2 = spec.get("p", Vector2.ZERO) * _terrain_radius
		var footprint: float = float(spec.get("footprint", 10.5)) * radius_scale
		if local_position.distance_to(center) < footprint + clearance:
			return true
	return false


func _build_inner_grove_decorations(size_profile: Dictionary) -> void:
	var grove_root: Node3D = Node3D.new()
	grove_root.name = "InnerGroveDecorations"
	_generated_root.add_child(grove_root)
	var tier_name: String = str(size_profile.get("tier_name", "24_player"))
	var tier_index: int = 2
	if tier_name == "8_player":
		tier_index = 0
	elif tier_name == "12_player":
		tier_index = 1
	var radius_scale: float = clampf(_terrain_radius / 84.0, 0.72, 1.0)
	var tree_target: int = [7, 12, 18][tier_index]
	var rock_target: int = [8, 12, 18][tier_index]
	var bush_target: int = [5, 8, 13][tier_index]
	_spawn_inner_trees(grove_root, tree_target, radius_scale)
	_spawn_inner_rocks(grove_root, rock_target, radius_scale)
	_spawn_inner_bushes(grove_root, bush_target, radius_scale)


func _spawn_inner_trees(parent: Node3D, target_count: int, radius_scale: float) -> void:
	var tree_specs: Array[Dictionary] = [
		{"p": Vector2(-0.46, -0.29), "variant": 0, "scale": 2.05, "yaw": 0.20},
		{"p": Vector2(-0.39, 0.20), "variant": 1, "scale": 1.82, "yaw": -0.55},
		{"p": Vector2(-0.26, 0.36), "variant": 2, "scale": 1.92, "yaw": 1.30},
		{"p": Vector2(-0.14, -0.43), "variant": 3, "scale": 1.72, "yaw": -1.00},
		{"p": Vector2(0.21, -0.35), "variant": 4, "scale": 1.76, "yaw": 0.85},
		{"p": Vector2(0.42, -0.21), "variant": 5, "scale": 1.98, "yaw": -2.20},
		{"p": Vector2(0.53, 0.10), "variant": 0, "scale": 1.84, "yaw": 2.65},
		{"p": Vector2(0.35, 0.34), "variant": 1, "scale": 2.12, "yaw": -0.25},
		{"p": Vector2(-0.55, 0.02), "variant": 2, "scale": 1.70, "yaw": 0.45},
		{"p": Vector2(0.10, 0.50), "variant": 3, "scale": 1.82, "yaw": -1.55},
		{"p": Vector2(-0.31, -0.12), "variant": 4, "scale": 1.68, "yaw": 2.05},
		{"p": Vector2(0.57, -0.39), "variant": 5, "scale": 1.74, "yaw": 1.70},
		{"p": Vector2(-0.08, 0.27), "variant": 0, "scale": 1.55, "yaw": -2.75},
		{"p": Vector2(0.29, 0.05), "variant": 2, "scale": 1.66, "yaw": 0.10},
		{"p": Vector2(-0.60, -0.36), "variant": 3, "scale": 1.88, "yaw": 2.34},
		{"p": Vector2(0.48, 0.43), "variant": 4, "scale": 1.82, "yaw": -0.92},
		{"p": Vector2(-0.18, 0.55), "variant": 5, "scale": 1.64, "yaw": 1.10},
		{"p": Vector2(0.03, -0.56), "variant": 1, "scale": 1.78, "yaw": -1.88},
	]
	var spawned: int = 0
	for index in range(tree_specs.size()):
		if spawned >= target_count:
			return
		var spec: Dictionary = tree_specs[index]
		var local_position: Vector2 = spec.get("p", Vector2.ZERO) * _terrain_radius
		if not _can_place_inner_decor(local_position, 5.8 * radius_scale):
			continue
		var variant: int = clampi(int(spec.get("variant", index)), 0, CENTRAL_TREE_SCENES.size() - 1)
		var tree_scale: float = float(spec.get("scale", 1.7)) * radius_scale
		var tree_position: Vector3 = Vector3(local_position.x, 0.0, local_position.y)
		var tree: Node3D = _spawn_asset(parent, CENTRAL_TREE_SCENES[variant], "InnerTree_%02d" % spawned, tree_position, float(spec.get("yaw", 0.0)), Vector3.ONE * tree_scale, true)
		if tree != null:
			_add_tree_trunk_collision(parent, "InnerTreeCollision_%02d" % spawned, tree.global_position, tree_scale)
			spawned += 1


func _spawn_inner_rocks(parent: Node3D, target_count: int, radius_scale: float) -> void:
	var rock_specs: Array[Dictionary] = [
		{"p": Vector2(-0.50, -0.05), "variant": 0, "scale": 1.45, "yaw": 0.80},
		{"p": Vector2(-0.36, -0.38), "variant": 1, "scale": 1.18, "yaw": -0.35},
		{"p": Vector2(-0.22, 0.10), "variant": 2, "scale": 1.26, "yaw": 1.90},
		{"p": Vector2(0.17, -0.18), "variant": 0, "scale": 1.12, "yaw": -1.20},
		{"p": Vector2(0.33, 0.21), "variant": 1, "scale": 1.38, "yaw": 2.60},
		{"p": Vector2(0.49, -0.02), "variant": 2, "scale": 1.20, "yaw": -2.15},
		{"p": Vector2(-0.10, 0.43), "variant": 0, "scale": 1.28, "yaw": 0.25},
		{"p": Vector2(0.03, -0.35), "variant": 1, "scale": 1.08, "yaw": 1.10},
		{"p": Vector2(-0.58, 0.31), "variant": 2, "scale": 1.36, "yaw": -0.70},
		{"p": Vector2(0.59, 0.31), "variant": 0, "scale": 1.34, "yaw": 2.20},
		{"p": Vector2(-0.43, 0.43), "variant": 1, "scale": 1.10, "yaw": -1.45},
		{"p": Vector2(0.41, -0.48), "variant": 2, "scale": 1.18, "yaw": 0.55},
		{"p": Vector2(-0.67, -0.18), "variant": 0, "scale": 1.22, "yaw": 1.55},
		{"p": Vector2(0.67, -0.16), "variant": 1, "scale": 1.26, "yaw": -0.15},
		{"p": Vector2(-0.02, 0.60), "variant": 2, "scale": 1.16, "yaw": 0.95},
		{"p": Vector2(0.24, 0.49), "variant": 0, "scale": 1.18, "yaw": -2.70},
		{"p": Vector2(-0.24, -0.55), "variant": 1, "scale": 1.24, "yaw": 2.95},
		{"p": Vector2(0.54, 0.51), "variant": 2, "scale": 1.18, "yaw": -0.38},
	]
	var spawned: int = 0
	for index in range(rock_specs.size()):
		if spawned >= target_count:
			return
		var spec: Dictionary = rock_specs[index]
		var local_position: Vector2 = spec.get("p", Vector2.ZERO) * _terrain_radius
		if not _can_place_inner_decor(local_position, 3.2 * radius_scale):
			continue
		var variant: int = clampi(int(spec.get("variant", index)), 0, CENTRAL_ROCK_SCENES.size() - 1)
		var rock_scale: float = float(spec.get("scale", 1.0)) * radius_scale
		var rock_position: Vector3 = Vector3(local_position.x, 0.0, local_position.y)
		var rock: Node3D = _spawn_asset(parent, CENTRAL_ROCK_SCENES[variant], "InnerRock_%02d" % spawned, rock_position, float(spec.get("yaw", 0.0)), Vector3.ONE * rock_scale, true)
		if rock != null:
			_add_rock_collision(parent, "InnerRockCollision_%02d" % spawned, rock.global_position, rock_scale)
			spawned += 1


func _spawn_inner_bushes(parent: Node3D, target_count: int, radius_scale: float) -> void:
	var bush_specs: Array[Dictionary] = [
		{"p": Vector2(-0.48, 0.12), "variant": 0, "scale": 1.18, "yaw": 0.40},
		{"p": Vector2(-0.18, -0.24), "variant": 1, "scale": 1.08, "yaw": -0.35},
		{"p": Vector2(0.12, 0.18), "variant": 0, "scale": 1.12, "yaw": 1.70},
		{"p": Vector2(0.38, -0.06), "variant": 1, "scale": 1.05, "yaw": -2.10},
		{"p": Vector2(-0.07, 0.46), "variant": 0, "scale": 1.16, "yaw": 0.15},
		{"p": Vector2(0.50, 0.23), "variant": 1, "scale": 1.10, "yaw": 2.85},
		{"p": Vector2(-0.55, -0.25), "variant": 0, "scale": 1.08, "yaw": -1.40},
		{"p": Vector2(0.24, -0.49), "variant": 1, "scale": 1.02, "yaw": 1.22},
		{"p": Vector2(-0.33, 0.33), "variant": 0, "scale": 1.14, "yaw": -2.55},
		{"p": Vector2(0.63, 0.03), "variant": 1, "scale": 1.08, "yaw": 0.75},
		{"p": Vector2(-0.63, 0.18), "variant": 0, "scale": 1.10, "yaw": 2.40},
		{"p": Vector2(0.04, -0.61), "variant": 1, "scale": 1.04, "yaw": -0.86},
		{"p": Vector2(0.30, 0.43), "variant": 0, "scale": 1.16, "yaw": 1.95},
	]
	var spawned: int = 0
	for index in range(bush_specs.size()):
		if spawned >= target_count:
			return
		var spec: Dictionary = bush_specs[index]
		var local_position: Vector2 = spec.get("p", Vector2.ZERO) * _terrain_radius
		if not _can_place_inner_decor(local_position, 2.4 * radius_scale):
			continue
		var variant: int = clampi(int(spec.get("variant", index)), 0, CENTRAL_BUSH_SCENES.size() - 1)
		var bush_scale: float = float(spec.get("scale", 1.0)) * radius_scale
		var bush_position: Vector3 = Vector3(local_position.x, 0.0, local_position.y)
		_spawn_asset(parent, CENTRAL_BUSH_SCENES[variant], "InnerBush_%02d" % spawned, bush_position, float(spec.get("yaw", 0.0)), Vector3.ONE * bush_scale, true)
		spawned += 1


func _can_place_inner_decor(local_position: Vector2, clearance: float) -> bool:
	if local_position.length() > _terrain_radius * 0.72:
		return false
	if SunnyIslandStreamBuilder.stream_depth_at(local_position, _terrain_radius) > 0.04:
		return false
	if _distance_to_path_network(local_position) < clearance:
		return false
	if _is_near_temple_ruin(local_position, clearance):
		return false
	var village_centers: Array[Vector2] = [Vector2(-8.0, -6.0), Vector2(4.5, -9.5), Vector2(-14.0, 5.5), Vector2(10.5, 4.5), Vector2(0.4, -1.4)]
	for center in village_centers:
		if local_position.distance_to(center) < clearance + 4.8:
			return false
	return true


func _distance_to_path_network(point: Vector2) -> float:
	var segments: Array[Vector4] = [
		Vector4(-_terrain_radius * 0.20, -_terrain_radius * 0.10, _terrain_radius * 0.56, -_terrain_radius * 0.82),
		Vector4(-_terrain_radius * 0.20, -_terrain_radius * 0.10, -_terrain_radius * 0.68, _terrain_radius * 0.44),
		Vector4(-_terrain_radius * 0.20, -_terrain_radius * 0.10, _terrain_radius * 0.64, _terrain_radius * 0.40),
		Vector4(-_terrain_radius * 0.34, -_terrain_radius * 0.18, _terrain_radius * 0.22, _terrain_radius * 0.12),
	]
	var closest: float = 1000000.0
	for segment in segments:
		closest = minf(closest, _distance_to_segment_2d(point, Vector2(segment.x, segment.y), Vector2(segment.z, segment.w)))
	return closest


func _distance_to_segment_2d(point: Vector2, from_point: Vector2, to_point: Vector2) -> float:
	var segment: Vector2 = to_point - from_point
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(from_point)
	var t: float = clampf((point - from_point).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(from_point + segment * t)


func _add_tree_trunk_collision(parent: Node3D, node_name: String, base_position: Vector3, scale_value: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = base_position + Vector3.UP * (2.15 * scale_value)
	parent.add_child(body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "TrunkShape"
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.height = 4.3 * scale_value
	shape.radius = 0.33 * scale_value
	shape_node.shape = shape
	body.add_child(shape_node)


func _add_rock_collision(parent: Node3D, node_name: String, base_position: Vector3, scale_value: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.position = base_position + Vector3.UP * (0.45 * scale_value)
	parent.add_child(body)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = "RockShape"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.55, 0.90, 1.55) * scale_value
	shape_node.shape = shape
	body.add_child(shape_node)


func _spawn_asset(parent: Node3D, scene_path: String, node_name: String, asset_position: Vector3, yaw: float, scale_value: Vector3, align_to_terrain: bool) -> Node3D:
	if not ResourceLoader.exists(scene_path):
		return null
	var packed_scene: PackedScene = load(scene_path) as PackedScene
	if packed_scene == null:
		return null
	var instance: Node3D = packed_scene.instantiate() as Node3D
	if instance == null:
		return null
	instance.name = node_name
	var final_position: Vector3 = asset_position
	if align_to_terrain:
		final_position.y = _terrain_point(asset_position.x, asset_position.z, _terrain_radius).y + 0.04
	instance.position = final_position
	instance.rotation.y = yaw
	instance.scale = scale_value
	_set_shadow_recursive(instance, true)
	parent.add_child(instance)
	return instance


func _set_shadow_recursive(node: Node, shadow_enabled: bool) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	for child in node.get_children():
		_set_shadow_recursive(child, shadow_enabled)


func _build_spawn_points(size_profile: Dictionary) -> void:
	var spawn_root: Node3D = Node3D.new()
	spawn_root.name = String(SPAWN_POINTS_NODE)
	_generated_root.add_child(spawn_root)
	var spawn_count: int = int(size_profile.get("spawn_count", 12))
	var spawn_ring: float = float(size_profile.get("spawn_ring", 28.0))
	for index in range(spawn_count):
		var angle: float = TAU * float(index) / float(spawn_count)
		var ring_noise: float = _value_noise_2d(cos(angle) * 3.0, sin(angle) * 3.0, generation_seed + 404)
		var radius: float = spawn_ring * lerpf(0.82, 1.14, ring_noise)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var marker: Marker3D = Marker3D.new()
		marker.name = "Spawn%02d" % (index + 1)
		marker.position = Vector3(x, _terrain_point(x, z, _terrain_radius).y + 1.15, z)
		marker.rotation.y = angle + PI
		spawn_root.add_child(marker)


func _build_vegetation_controller(size_profile: Dictionary) -> void:
	var vegetation: VegetationController = VegetationController.new()
	vegetation.name = "SunnyIslandVegetation"
	vegetation.install_wait_frames = 1
	vegetation.async_build_enabled = true
	vegetation.projection_batch_size = 768
	vegetation.chunk_builds_per_frame = 6
	vegetation.profile = _make_vegetation_profile(size_profile)
	_generated_root.add_child(vegetation)


func _make_vegetation_profile(size_profile: Dictionary) -> VegetationProfile:
	var profile: VegetationProfile = VegetationProfile.new()
	profile.profile_id = "sunny_island_%s" % str(size_profile.get("tier_name", "large"))
	profile.generation_seed = VegetationProfile.stable_seed(profile.profile_id + str(generation_seed))
	profile.build_visuals_in_headless = false
	profile.use_prebaked_vegetation = true
	profile.prebaked_vegetation_path = "res://resources/vegetation/sunny_island/%s_vegetation_bake.tres" % str(size_profile.get("tier_name", "large"))
	profile.enable_grass = true
	profile.grass_instance_count = int(size_profile.get("grass_count", 21000))
	profile.grass_chunk_size = 16.0
	profile.grass_min_height = 0.34
	profile.grass_max_height = 0.84
	profile.grass_min_width = 0.90
	profile.grass_max_width = 1.55
	profile.grass_patch_frequency = 0.026
	profile.grass_edge_bias = 0.035
	profile.grass_lane_clearance = 0.0
	profile.vegetation_exclusion_segments = SunnyIslandStreamBuilder.make_exclusion_segments(_terrain_radius)
	profile.vegetation_exclusion_radius = SunnyIslandStreamBuilder.stream_clearance_radius(_terrain_radius)
	profile.vegetation_exclusion_center_density = 0.012
	profile.grass_base_color = Color(0.22, 0.64, 0.20, 1.0)
	profile.grass_tip_color = Color(0.58, 0.88, 0.34, 1.0)
	profile.grass_shadow_color = Color(0.06, 0.28, 0.08, 1.0)
	profile.wind_direction = Vector2(0.88, 0.42)
	profile.grass_wind_strength = 0.52
	profile.tree_wind_strength = 0.70
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
	profile.flower_instance_count = int(size_profile.get("flower_count", 620))
	profile.flower_chunk_size = 16.0
	profile.flower_min_height = 0.62
	profile.flower_max_height = 1.12
	profile.flower_min_width = 0.86
	profile.flower_max_width = 1.48
	profile.flower_patch_frequency = 0.018
	profile.flower_density = 0.28
	profile.flower_cluster_count = int(maxf(8.0, float(profile.flower_instance_count) / 18.0))
	profile.flower_cluster_min_flowers = 10
	profile.flower_cluster_max_flowers = 28
	profile.flower_cluster_min_radius = 0.85
	profile.flower_cluster_max_radius = 2.45
	profile.flower_cluster_min_spacing = 5.4
	profile.flower_cluster_height_variation = 0.30
	profile.flower_heads_per_instance = 6
	profile.flower_shape_variety = 1.0
	profile.flower_stem_color = Color(0.18, 0.54, 0.16, 1.0)
	profile.flower_stem_shadow_color = Color(0.06, 0.24, 0.07, 1.0)
	profile.flower_petal_color_a = Color(0.94, 0.97, 0.88, 1.0)
	profile.flower_petal_color_b = Color(0.96, 0.82, 0.93, 1.0)
	profile.flower_petal_color_c = Color(0.70, 0.88, 1.0, 1.0)
	profile.flower_petal_color_d = Color(0.99, 0.86, 0.42, 1.0)
	profile.flower_petal_color_e = Color(0.76, 0.68, 1.0, 1.0)
	profile.flower_center_color = Color(0.98, 0.76, 0.24, 1.0)
	profile.enable_trees = true
	profile.tree_count = int(size_profile.get("tree_count", 56))
	profile.tree_collision_enabled = false
	profile.tree_min_scale = 1.20
	profile.tree_max_scale = 2.05
	profile.tree_edge_margin = 0.24
	profile.tree_trunk_color = Color(0.48, 0.29, 0.15, 1.0)
	profile.tree_leaf_color = Color(0.28, 0.68, 0.28, 1.0)
	profile.tree_leaf_tip_color = Color(0.64, 0.88, 0.32, 1.0)
	profile.tree_scene_paths = PackedStringArray(PALM_SCENES)
	profile.fallback_support_center = Vector3.ZERO
	profile.fallback_support_size = Vector2(_terrain_radius * 1.72, _terrain_radius * 1.72)
	profile.fallback_support_top_y = ground_y
	return profile


func _build_preview_camera(_size_profile: Dictionary) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "SunnyIslandPreviewCamera"
	var camera_distance: float = _terrain_radius * 1.22
	var camera_height: float = _terrain_radius * 0.62
	camera.look_at_from_position(Vector3(_terrain_radius * 0.58, camera_height, camera_distance), Vector3(0.0, 2.2, 0.0), Vector3.UP)
	camera.fov = 54.0
	camera.far = _terrain_radius * 5.0
	camera.current = false
	_generated_root.add_child(camera)


func _value_noise_2d(x: float, y: float, seed_value: int) -> float:
	var xi: int = int(floor(x))
	var yi: int = int(floor(y))
	var xf: float = x - float(xi)
	var yf: float = y - float(yi)
	var sx: float = xf * xf * (3.0 - 2.0 * xf)
	var sy: float = yf * yf * (3.0 - 2.0 * yf)
	var a: float = _hash01(xi, yi, seed_value)
	var b: float = _hash01(xi + 1, yi, seed_value)
	var c: float = _hash01(xi, yi + 1, seed_value)
	var d: float = _hash01(xi + 1, yi + 1, seed_value)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


func _hash01(x: int, y: int, seed_value: int) -> float:
	var value: int = _mix_hash(seed_value, x * 374761393 + y * 668265263)
	return float(value % 1000003) / 1000003.0


func _mix_hash(a: int, b: int) -> int:
	var value: int = int(a) ^ int(b + 0x9e3779b9 + (int(a) << 6) + (int(a) >> 2))
	value = int((value ^ (value >> 16)) * 2246822519) & 0x7fffffff
	return max(value, 1)
