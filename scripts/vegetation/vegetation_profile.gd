class_name VegetationProfile
extends Resource

@export var profile_id: String = "warehouse_default"
@export var generation_seed: int = 704217
@export var build_visuals_in_headless: bool = false

@export_group("Grass")
@export var enable_grass: bool = true
@export_range(0, 30000, 100) var grass_instance_count: int = 9600
@export_range(8.0, 64.0, 1.0) var grass_chunk_size: float = 18.0
@export_range(0.2, 3.0, 0.05) var grass_min_height: float = 0.72
@export_range(0.2, 3.0, 0.05) var grass_max_height: float = 1.58
@export_range(0.04, 0.7, 0.01) var grass_min_width: float = 0.12
@export_range(0.04, 0.7, 0.01) var grass_max_width: float = 0.28
@export_range(0.0005, 0.08, 0.0005) var grass_patch_frequency: float = 0.022
@export_range(0.0, 1.0, 0.01) var grass_edge_bias: float = 0.36
@export var grass_base_color: Color = Color(0.40, 0.74, 0.22, 1.0)
@export var grass_tip_color: Color = Color(0.82, 1.0, 0.35, 1.0)
@export var grass_shadow_color: Color = Color(0.20, 0.42, 0.12, 1.0)

@export_group("Wind")
@export var wind_direction: Vector2 = Vector2(1.0, 0.38)
@export_range(0.0, 3.0, 0.01) var grass_wind_strength: float = 0.58
@export_range(0.0, 4.0, 0.01) var tree_wind_strength: float = 0.42
@export_range(0.01, 4.0, 0.01) var wind_speed: float = 0.82
@export_range(0.001, 1.0, 0.001) var wind_noise_scale: float = 0.055
@export_range(0.0, 2.0, 0.01) var gust_strength: float = 0.55

@export_group("Touch")
@export_range(0.1, 8.0, 0.05) var touch_radius: float = 2.85
@export_range(0.0, 3.0, 0.01) var touch_push_strength: float = 1.18
@export_range(0.0, 2.0, 0.01) var touch_crush_strength: float = 0.34
@export_range(0.1, 8.0, 0.05) var touch_recovery_speed: float = 1.28
@export_range(1, 12, 1) var touch_slot_count: int = 8
@export_range(0.05, 2.0, 0.05) var touch_min_move_distance: float = 0.18

@export_group("Trees")
@export var enable_trees: bool = true
@export_range(0, 256, 1) var tree_count: int = 26
@export var tree_collision_enabled: bool = false
@export_range(0.2, 8.0, 0.05) var tree_min_scale: float = 0.82
@export_range(0.2, 8.0, 0.05) var tree_max_scale: float = 1.38
@export_range(0.1, 3.0, 0.05) var tree_trunk_radius: float = 0.55
@export_range(0.2, 8.0, 0.05) var tree_trunk_height: float = 2.8
@export_range(0.0, 0.5, 0.01) var tree_edge_margin: float = 0.16
@export var tree_trunk_color: Color = Color(0.46, 0.31, 0.18, 1.0)
@export var tree_leaf_color: Color = Color(0.30, 0.72, 0.25, 1.0)
@export var tree_leaf_tip_color: Color = Color(0.62, 0.92, 0.28, 1.0)
@export var tree_scene_paths: PackedStringArray = PackedStringArray([
	"res://assets/unity_migrated/polygon_apocalypse/Models/SM_Env_Tree_01.glb",
	"res://assets/unity_migrated/polygon_apocalypse/Models/SM_Env_Tree_02.glb",
	"res://assets/unity_migrated/polygon_apocalypse/Models/SM_Env_Tree_03.glb",
	"res://assets/unity_migrated/polygon_apocalypse/Models/SM_Env_Tree_04.glb",
	"res://assets/unity_migrated/polygon_apocalypse/Models/SM_Env_Tree_Pine_Tall_01.glb",
	"res://assets/unity_migrated/polygon_apocalypse/Models/SM_Generic_Tree_01.glb"
])

@export_group("Fallback Support")
@export var fallback_support_center: Vector3 = Vector3.ZERO
@export var fallback_support_size: Vector2 = Vector2(230.0, 220.0)
@export var fallback_support_top_y: float = -8.0


static func for_polygon_warehouse(map_id: String, sector_id: String) -> VegetationProfile:
	var profile := VegetationProfile.new()
	profile.profile_id = "%s_%s_vegetation" % [map_id, sector_id]
	profile.generation_seed = VegetationProfile.stable_seed(profile.profile_id)
	profile.fallback_support_top_y = -8.0 if map_id.begins_with("city_") else 0.0

	if map_id == "city_urp":
		profile.grass_instance_count = 12800
		profile.tree_count = 34
		profile.grass_wind_strength = 0.64
		profile.tree_wind_strength = 0.50
	else:
		profile.grass_instance_count = 9400
		profile.tree_count = 24
		profile.grass_wind_strength = 0.52
		profile.tree_wind_strength = 0.36

	if sector_id == "warehouse_ward":
		profile.grass_patch_frequency = 0.026
		profile.grass_edge_bias = 0.46
		profile.tree_edge_margin = 0.20
		profile.fallback_support_size = Vector2(230.0, 220.0)

	return profile


static func stable_seed(text: String) -> int:
	var hash_value: int = 2166136261
	for byte_value in text.to_utf8_buffer():
		hash_value = int((hash_value ^ int(byte_value)) * 16777619) & 0x7fffffff
	return max(hash_value, 1)
