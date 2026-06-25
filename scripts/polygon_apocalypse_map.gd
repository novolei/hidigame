extends Node3D
class_name PolygonApocalypseMap

@export_enum("building_interior_dressing", "bunker", "city_standard", "city_urp") var map_id := "bunker"
@export_enum("full", "downtown_core", "quarantine_crossing", "market_row", "overpass_camp", "warehouse_ward") var sector_id := "full"
@export var collision_budget: int = 1800

const WORLD_LAYER := 2
const GAMEPLAY_SUPPORT_NAME := "PolygonApocalypseGameplaySupport"
const GAMEPLAY_SUPPORT_TOP_Y_CITY := -8.0
const GAMEPLAY_SUPPORT_TOP_Y_DEFAULT := 0.0
const GAMEPLAY_SUPPORT_THICKNESS := 0.18
const GAMEPLAY_SUPPORT_MARGIN := 18.0
const GAMEPLAY_SUPPORT_MIN_SIZE := Vector2(90.0, 90.0)
const WALKABLE_COLLISION_BUDGET := 2600
const BLOCKER_COLLISION_MIN_SIZE := Vector3(0.35, 0.35, 0.35)
const BLOCKER_COLLISION_INSET := Vector3(0.34, 0.04, 0.34)
const STALKER_SHADOW_ZONE_GROUP := "stalker_shadow_zone"
const LAYOUTS := {
	"building_interior_dressing": "res://assets/unity_migrated/polygon_apocalypse/layouts/building_interior_dressing.json",
	"bunker": "res://assets/unity_migrated/polygon_apocalypse/layouts/bunker.json",
	"city_standard": "res://assets/unity_migrated/polygon_apocalypse/layouts/city_standard.json",
	"city_urp": "res://assets/unity_migrated/polygon_apocalypse/layouts/city_urp.json",
}
const MATERIAL_GUID_MAP_PATH := "res://assets/unity_migrated/polygon_apocalypse/material_guid_map.json"
const CITY_URP_MATERIAL_TINTS := {
	"5bb68a94905ffc0418608fc7e572ea42": Color(0.55, 0.66, 0.62, 1.0), # Main ground/sidewalk
	"84db59bbbc7c6b9448e1322ab91e08b9": Color(0.55, 0.66, 0.62, 1.0), # Temp ground
	"dfab048ce97a1b844bef2e7d0899a02f": Color(0.53, 0.64, 0.6, 1.0), # Material 02 A
	"5e8fc9c7c99b13c42a3462f542806e21": Color(0.53, 0.64, 0.6, 1.0), # Material 03 A
	"2bf2f69a5c3f9eb45b1db58fb7f33a00": Color(0.53, 0.64, 0.6, 1.0), # Material 04 A
	"0258a4f857570cf47a2c58eb2421fa13": Color(0.58, 0.52, 0.36, 1.0), # Road triplanar
	"21c1e0845fe50de4bacf0970b304729c": Color(0.58, 0.52, 0.36, 1.0), # Road standard
	"26f067e9e8c4bbb4eb122a5fe9073531": Color(0.46, 0.54, 0.28, 1.0), # Overgrowth
	"9807de85c52c6af4a8fc548e1765e6df": Color(0.52, 0.48, 0.32, 1.0), # Rubble
	"e53ee67879a38444fa41d9568a485e70": Color(0.5, 0.45, 0.31, 1.0), # Dirty road
	"da308fa8ec821e449a18115a733d5a74": Color(0.9, 0.98, 0.75, 1.0), # Ocean
	"ee711fe130d526443ac4f86b63f9e978": Color(0.83, 1.08, 0.75, 1.0), # Water
	"d95a681695d427e47a1f637e82acd420": Color(0.92, 1.0, 0.75, 1.0), # Swamp water
	"cae48a5b627bc1f44863e62ff5e40125": Color(0.98, 0.86, 0.69, 1.0), # Background mountains 01
	"8e84f04f3ad7d044c99fc05756606cc0": Color(0.98, 0.86, 0.69, 1.0), # Background mountains 02
	"a1836274c62afa74eae8271ec157fa2a": Color(0.98, 0.86, 0.69, 1.0), # Background mountains 03
}
const WALKABLE_COLLISION_TOKENS := [
	"road",
	"sidewalk",
	"pavement",
	"ground",
	"dirt_flat",
	"dirt_slope",
	"stormcanal_floor",
	"floor",
	"bridge",
	"ramp",
	"motorway",
	"parking",
	"asphalt",
	"concrete",
	"terrain",
	"water",
	"ocean",
	"swamp",
]
const NON_BLOCKING_COLLISION_TOKENS := [
	"background",
	"decal",
	"poster",
	"billboard",
	"wire",
	"cable",
	"lamp",
	"light",
	"fx",
	"vfx",
	"fence",
	"barbed",
	"railing",
	"sign",
	"signage",
	"line",
	"marking",
	"leaf",
	"foliage",
	"grass",
	"bush",
	"tree",
	"plant",
	"cloud",
	"mountain",
]
const BLOCKER_COLLISION_TOKENS := [
	"building",
	"wall",
	"house",
	"container",
	"bus",
	"car",
	"truck",
	"vehicle",
	"van",
	"barrier",
	"barricade",
	"blockade",
	"crate",
	"box",
	"dumpster",
	"skip",
	"tank",
	"rock",
	"boulder",
	"pillar",
	"column",
	"stairs",
	"stair",
	"warehouse",
	"shed",
	"store",
	"shop",
	"garage",
	"counter",
	"table",
]
const CITY_SECTORS := {
	"downtown_core": {
		"label": "Downtown Escape",
		"bounds": [-40.0, 150.0, -120.0, 40.0],
		"recommended_players": "8-12",
		"theme": "dense shops, wrecked cars, short third-person sight lines, and multiple alley escapes",
	},
	"quarantine_crossing": {
		"label": "Quarantine Crossing",
		"bounds": [105.0, 230.0, -70.0, 70.0],
		"recommended_players": "6-10",
		"theme": "checkpoint walls, bus cover, hospital props, and tense hunter choke points with side exits",
	},
	"market_row": {
		"label": "Market Row",
		"bounds": [-220.0, 45.0, -80.0, 110.0],
		"recommended_players": "6-10",
		"theme": "prop-rich storefront lanes for disguise chains and emergency rotations",
	},
	"overpass_camp": {
		"label": "Overpass Camp",
		"bounds": [-25.0, 220.0, -260.0, -120.0],
		"recommended_players": "8-12",
		"theme": "bridge silhouettes, caravans, army trucks, and shadow cover for risky escapes",
	},
	"warehouse_ward": {
		"label": "Warehouse Ward",
		"bounds": [-70.0, 120.0, -230.0, -50.0],
		"recommended_players": "8-12",
		"theme": "industrial clutter, burned houses, water tanks, and looping interior-to-street routes",
	},
}
const CITY_SECTOR_ALWAYS_INCLUDE_TOKENS := [
	"cloudring",
	"mountains",
	"sm_env_semicircle",
	"ocean",
	"swamp",
	"background",
]

var _root: Node3D
var _packed_scene_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _material_guid_map: Dictionary = {}
var _collisions_created: int = 0
var _walkable_collisions_created: int = 0


func _ready() -> void:
	build()


func build() -> void:
	_clear_generated()
	_load_material_guid_map()
	_collisions_created = 0
	_walkable_collisions_created = 0
	_root = Node3D.new()
	_root.name = "GeneratedPolygonApocalypseMap"
	add_child(_root)

	var layout_path := str(LAYOUTS.get(map_id, ""))
	if layout_path.is_empty() or not FileAccess.file_exists(layout_path):
		push_warning("Polygon Apocalypse layout is missing: " + layout_path)
		return

	var text := FileAccess.get_file_as_string(layout_path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Polygon Apocalypse layout JSON did not parse: " + layout_path)
		return

	_build_environment((parsed as Dictionary).get("environment", {}))
	_build_layout((parsed as Dictionary).get("objects", []))
	_build_lights((parsed as Dictionary).get("lights", []))
	_calibrate_building_rendering()
	_calibrate_bunker_rendering()
	_calibrate_city_rendering()


func _clear_generated() -> void:
	for child in get_children():
		if child.name == "GeneratedPolygonApocalypseMap":
			child.free()


func _load_material_guid_map() -> void:
	_material_guid_map.clear()
	if not FileAccess.file_exists(MATERIAL_GUID_MAP_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MATERIAL_GUID_MAP_PATH))
	if not parsed is Dictionary:
		return
	var materials = (parsed as Dictionary).get("materials", {})
	if materials is Dictionary:
		for guid in (materials as Dictionary).keys():
			_material_guid_map[str(guid)] = str((materials as Dictionary)[guid])


func _build_layout(objects) -> void:
	var prop_root := Node3D.new()
	prop_root.name = "PolygonApocalypseLayout"
	_root.add_child(prop_root)

	if not objects is Array:
		return

	prop_root.set_meta("sector_id", sector_id)
	prop_root.set_meta("sector_label", _active_sector_label())
	var sector_bounds := _active_sector_bounds()
	if not sector_bounds.is_empty():
		prop_root.set_meta("sector_bounds", sector_bounds)
	for object_data in objects:
		if not object_data is Dictionary:
			continue
		if not _object_is_in_active_sector(object_data as Dictionary):
			continue
		_spawn_layout_object(prop_root, object_data as Dictionary)
	_finalize_layout_for_gameplay(prop_root)


func _finalize_layout_for_gameplay(prop_root: Node3D) -> void:
	var support_center := Vector3.ZERO
	var support_size := GAMEPLAY_SUPPORT_MIN_SIZE
	var sector_bounds := _active_sector_bounds()
	if not sector_bounds.is_empty():
		var min_x := float(sector_bounds[0])
		var max_x := float(sector_bounds[1])
		var min_z := float(sector_bounds[2])
		var max_z := float(sector_bounds[3])
		var center := Vector3((min_x + max_x) * 0.5, 0.0, (min_z + max_z) * 0.5)
		prop_root.position -= center
		support_size = Vector2(absf(max_x - min_x) + GAMEPLAY_SUPPORT_MARGIN * 2.0, absf(max_z - min_z) + GAMEPLAY_SUPPORT_MARGIN * 2.0)
	else:
		var layout_bounds := _calculate_bounds(prop_root)
		if layout_bounds.size != Vector3.ZERO:
			var layout_center := layout_bounds.get_center()
			support_center = Vector3(layout_center.x, 0.0, layout_center.z)
			support_size = Vector2(layout_bounds.size.x + GAMEPLAY_SUPPORT_MARGIN * 2.0, layout_bounds.size.z + GAMEPLAY_SUPPORT_MARGIN * 2.0)
	support_size = Vector2(maxf(support_size.x, GAMEPLAY_SUPPORT_MIN_SIZE.x), maxf(support_size.y, GAMEPLAY_SUPPORT_MIN_SIZE.y))
	_add_gameplay_support_floor(support_center, support_size)


func _add_gameplay_support_floor(center: Vector3, size_xz: Vector2) -> void:
	if not _root:
		return
	var body := StaticBody3D.new()
	body.name = GAMEPLAY_SUPPORT_NAME
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var support_top_y := GAMEPLAY_SUPPORT_TOP_Y_CITY if map_id.begins_with("city_") else GAMEPLAY_SUPPORT_TOP_Y_DEFAULT
	body.set_meta("support_size_xz", size_xz)
	body.set_meta("support_top_y", support_top_y)
	_root.add_child(body, true)
	body.global_position = Vector3(center.x, support_top_y - GAMEPLAY_SUPPORT_THICKNESS * 0.5, center.z)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "GameplaySupportShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(size_xz.x, GAMEPLAY_SUPPORT_THICKNESS, size_xz.y)
	shape_node.shape = shape
	body.add_child(shape_node)


func _active_sector_label() -> String:
	if not _has_active_city_sector():
		return ""
	var sector := CITY_SECTORS[sector_id] as Dictionary
	return str(sector.get("label", sector_id))


func _active_sector_bounds() -> Array[float]:
	if not _has_active_city_sector():
		return []
	var sector := CITY_SECTORS[sector_id] as Dictionary
	var bounds_value: Variant = sector.get("bounds", [])
	if not bounds_value is Array or (bounds_value as Array).size() < 4:
		return []
	var bounds := bounds_value as Array
	return [float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3])]


func _has_active_city_sector() -> bool:
	return map_id.begins_with("city_") and sector_id != "full" and CITY_SECTORS.has(sector_id)


func _object_is_in_active_sector(object_data: Dictionary) -> bool:
	if not _has_active_city_sector():
		return true
	if _city_object_should_ignore_sector_bounds(object_data):
		return true
	var sector := CITY_SECTORS[sector_id] as Dictionary
	var bounds_value: Variant = sector.get("bounds", [])
	if not bounds_value is Array or (bounds_value as Array).size() < 4:
		return true
	var bounds := bounds_value as Array
	var object_position := _vector3_from_array(object_data.get("position", []))
	return (
		object_position.x >= float(bounds[0])
		and object_position.x <= float(bounds[1])
		and object_position.z >= float(bounds[2])
		and object_position.z <= float(bounds[3])
	)


func _city_object_should_ignore_sector_bounds(object_data: Dictionary) -> bool:
	var combined := (
		str(object_data.get("name", ""))
		+ " "
		+ str(object_data.get("source_asset", ""))
		+ " "
		+ str(object_data.get("hierarchy_path", ""))
	).to_lower()
	for token in CITY_SECTOR_ALWAYS_INCLUDE_TOKENS:
		if combined.contains(token):
			return true
	return false


func _spawn_layout_object(parent: Node3D, object_data: Dictionary) -> Node3D:
	var scene_path := str(object_data.get("scene", ""))
	var builtin_mesh := str(object_data.get("builtin_mesh", ""))
	var node: Node3D = null
	if not scene_path.is_empty():
		var packed := _load_packed_scene(scene_path)
		if not packed:
			push_warning("Polygon Apocalypse model failed to load: " + scene_path)
			return null
		node = packed.instantiate() as Node3D
	elif not builtin_mesh.is_empty():
		node = _create_builtin_mesh_node(builtin_mesh)
	else:
		return null
	if not node:
		push_warning("Polygon Apocalypse model did not instantiate as Node3D: " + str(object_data.get("name", scene_path)))
		return null

	node = _extract_imported_renderer_node(node, str(object_data.get("name", "")))
	var placeholder_node := _create_empty_import_placeholder(node, object_data)
	if placeholder_node:
		node.free()
		node = placeholder_node
	node.name = _safe_node_name(str(object_data.get("name", scene_path.get_file().get_basename())))
	node.set_meta("unity_name", str(object_data.get("name", node.name)))
	node.set_meta("unity_transform_id", str(object_data.get("transform_id", "")))
	parent.add_child(node, true)
	node.global_position = _vector3_from_array(object_data.get("position", []))
	node.quaternion = _quaternion_from_array(object_data.get("rotation", []))
	node.scale = _vector3_from_array(object_data.get("scale", []), Vector3.ONE)
	_apply_scene_transform_variants(node, object_data)
	_apply_surface_materials(node, object_data.get("material_guids", []))
	_apply_scene_material_variants(node, object_data)
	_align_to_unity_renderer_bounds(node, object_data)
	_disable_imported_collisions(node)
	if _layout_object_should_use_walkable_collision(object_data):
		_add_walkable_collision_for(parent, node)
	elif _layout_object_should_collide(object_data):
		_add_static_collision_for(parent, node, object_data)
	return node


func _create_empty_import_placeholder(_node: Node3D, object_data: Dictionary) -> Node3D:
	var renderer_name := str(object_data.get("name", ""))
	var source_scene_name := str(object_data.get("scene", "")).get_file().get_basename()
	var known_empty_body_import := source_scene_name in [
		"SM_Prop_DeadBody_Hanging_Female_01",
		"SM_Prop_DeadBody_Hanging_Female_02",
		"SM_Prop_DeadBody_Hanging_Male_01",
	]
	if not known_empty_body_import and not renderer_name.begins_with("SM_Prop_HangingRope_"):
		return null
	var bounds_data = object_data.get("unity_bounds", {})
	if not bounds_data is Dictionary:
		return null
	var size := _vector3_from_array((bounds_data as Dictionary).get("size", []))
	if size.x <= 0.00001 and size.y <= 0.00001 and size.z <= 0.00001:
		return null
	var mesh_instance := MeshInstance3D.new()
	if renderer_name.begins_with("SM_Prop_HangingRope_"):
		var rope_mesh := CylinderMesh.new()
		var rope_radius := maxf(maxf(size.x, size.z) * 0.5, 0.01)
		rope_mesh.top_radius = rope_radius
		rope_mesh.bottom_radius = rope_radius
		rope_mesh.height = maxf(size.y, 0.01)
		rope_mesh.radial_segments = 8
		mesh_instance.mesh = rope_mesh
		return mesh_instance
	if renderer_name.begins_with("SM_Prop_DeadBody_Hanging_"):
		var body_mesh := CapsuleMesh.new()
		var body_radius := maxf(minf(maxf(size.x, size.z) * 0.35, size.y * 0.45), 0.08)
		body_mesh.radius = body_radius
		body_mesh.height = maxf(size.y, body_radius * 2.0)
		body_mesh.radial_segments = 10
		body_mesh.rings = 4
		mesh_instance.mesh = body_mesh
		return mesh_instance
	return null


func _create_builtin_mesh_node(kind: String) -> Node3D:
	if kind == "quad":
		var mesh_instance := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		mesh_instance.mesh = mesh
		return mesh_instance
	if kind == "unity_plane_10":
		var mesh_instance := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(10.0, 10.0)
		mesh_instance.mesh = mesh
		return mesh_instance
	return null


func _load_packed_scene(scene_path: String) -> PackedScene:
	if _packed_scene_cache.has(scene_path):
		return _packed_scene_cache[scene_path] as PackedScene
	var loaded := load(scene_path)
	if loaded is PackedScene:
		_packed_scene_cache[scene_path] = loaded
		return loaded as PackedScene
	return null


func _extract_imported_renderer_node(instance: Node3D, renderer_name: String) -> Node3D:
	if renderer_name.is_empty():
		return instance
	var matches: Array[MeshInstance3D] = []
	_find_meshes_by_name(instance, renderer_name, matches)
	if matches.is_empty():
		return instance
	var selected := matches[0]
	if selected == instance:
		return instance

	var wrapper := Node3D.new()
	var selected_relative_transform := _relative_transform_to_root(instance, selected)
	var selected_copy := selected.duplicate() as MeshInstance3D
	if selected_copy == null:
		instance.free()
		return wrapper
	for child in selected_copy.get_children():
		child.free()
	selected_copy.transform = selected_relative_transform
	wrapper.add_child(selected_copy)
	instance.free()
	return wrapper


func _relative_transform_to_root(root_node: Node3D, target: Node3D) -> Transform3D:
	var result := target.transform
	var current := target.get_parent()
	while current != null and current != root_node:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _find_meshes_by_name(node: Node, renderer_name: String, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and String(node.name) == renderer_name:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes_by_name(child, renderer_name, result)


func _safe_node_name(value: String) -> String:
	var cleaned := value.replace("/", "_").replace("\\", "_").replace(":", "_")
	return cleaned if not cleaned.is_empty() else "PolygonApocalypseAsset"


func _vector3_from_array(value, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


func _quaternion_from_array(value) -> Quaternion:
	if value is Array and (value as Array).size() >= 4:
		return Quaternion(float(value[0]), float(value[1]), float(value[2]), float(value[3])).normalized()
	return Quaternion.IDENTITY


func _apply_surface_materials(node: Node, material_guids) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var material := _match_guid_material(material_guids, i)
				if material:
					mesh_instance.set_surface_override_material(i, material)
	for child in node.get_children():
		_apply_surface_materials(child, material_guids)


func _match_guid_material(material_guids, surface_index: int) -> Material:
	if not material_guids is Array:
		return null
	var guids := material_guids as Array
	if surface_index >= guids.size():
		return null
	var guid := str(guids[surface_index])
	if not _material_guid_map.has(guid):
		return null
	var material_path := str(_material_guid_map[guid])
	if material_path.is_empty():
		return null
	var cache_key := material_path
	if map_id == "city_urp":
		cache_key = map_id + "::" + guid + "::" + material_path
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as Material
	var loaded := load(material_path)
	if loaded is Material:
		var material := _variant_material_for_current_map(loaded as Material, guid)
		_material_cache[cache_key] = material
		return material
	return null


func _variant_material_for_current_map(material: Material, guid: String) -> Material:
	if map_id != "city_urp":
		return material
	if not CITY_URP_MATERIAL_TINTS.has(guid):
		return material
	if not material is StandardMaterial3D:
		return material
	var variant := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
	variant.albedo_color = variant.albedo_color * (CITY_URP_MATERIAL_TINTS[guid] as Color)
	variant.roughness = maxf(variant.roughness, 0.88)
	return variant


func _apply_scene_transform_variants(node: Node3D, object_data: Dictionary) -> void:
	if map_id != "city_urp":
		return
	if str(object_data.get("name", "")) != "SM_Generic_CloudRing_01":
		return
	node.scale.x *= -1.0


func _apply_scene_material_variants(node: Node3D, object_data: Dictionary) -> void:
	if map_id != "city_urp":
		return
	var object_name := str(object_data.get("name", ""))
	if object_name.contains("SM_Env_SemiCircle_01"):
		_tint_standard_materials(node, Color(0.72, 0.74, 0.66, 1.0))
		_set_standard_material_alpha(node, 0.82)
	if object_name.contains("BackgroundCard"):
		_tint_standard_materials(node, Color(1.1236, 1.5376, 2.4025, 1.0))
	if not object_name.contains("CloudRing"):
		return
	_tint_cloud_ring_for_urp(node)


func _align_to_unity_renderer_bounds(node: Node3D, object_data: Dictionary) -> void:
	var bounds_data = object_data.get("unity_bounds", {})
	if not bounds_data is Dictionary:
		return
	var center_data = (bounds_data as Dictionary).get("center", [])
	if not center_data is Array or (center_data as Array).size() < 3:
		return
	var current_bounds := _calculate_bounds(node)
	if current_bounds.size == Vector3.ZERO:
		return
	var delta := _vector3_from_array(center_data) - current_bounds.get_center()
	if delta.length_squared() < 0.000001:
		return
	_offset_mesh_instances(node, delta)


func _offset_mesh_instances(node: Node, delta: Vector3) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.global_position += delta
		return
	for child in node.get_children():
		_offset_mesh_instances(child, delta)


func _tint_cloud_ring_for_urp(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(i)
				if material is StandardMaterial3D:
					var variant := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.albedo_color = Color(1.332408, 1.121516928, 0.51349248, 1.0)
					variant.emission_enabled = true
					variant.emission = Color(1.332408, 1.05142212, 0.47070144, 1.0)
					variant.emission_energy_multiplier = 0.28
					variant.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_instance.set_surface_override_material(i, variant)
	for child in node.get_children():
		_tint_cloud_ring_for_urp(child)


func _layout_object_should_collide(object_data: Dictionary) -> bool:
	if collision_budget >= 0 and _collisions_created >= collision_budget:
		return false
	var combined := _object_data_search_text(object_data)
	if _contains_any_token(combined, WALKABLE_COLLISION_TOKENS):
		return false
	if _contains_any_token(combined, NON_BLOCKING_COLLISION_TOKENS):
		return false
	return _contains_any_token(combined, BLOCKER_COLLISION_TOKENS)


func _layout_object_should_use_walkable_collision(object_data: Dictionary) -> bool:
	if _walkable_collisions_created >= WALKABLE_COLLISION_BUDGET:
		return false
	var combined := _object_data_search_text(object_data)
	return _contains_any_token(combined, WALKABLE_COLLISION_TOKENS)


func _object_data_search_text(object_data: Dictionary) -> String:
	return (
		str(object_data.get("name", ""))
		+ " "
		+ str(object_data.get("source_asset", ""))
		+ " "
		+ str(object_data.get("scene", ""))
		+ " "
		+ str(object_data.get("hierarchy_path", ""))
	).to_lower()


func _contains_any_token(text: String, tokens: Array) -> bool:
	for token in tokens:
		if text.contains(str(token)):
			return true
	return false


func _add_walkable_collision_for(parent: Node3D, visual_node: Node3D) -> void:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(visual_node, meshes)
	for mesh_instance in meshes:
		if _walkable_collisions_created >= WALKABLE_COLLISION_BUDGET:
			return
		if not mesh_instance.mesh:
			continue
		var bounds := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if bounds.size.x < 0.2 or bounds.size.z < 0.2:
			continue
		var shape: Shape3D = mesh_instance.mesh.create_trimesh_shape()
		if not shape:
			continue
		var body := StaticBody3D.new()
		body.name = mesh_instance.name + "_Walkable"
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 0
		body.add_to_group("polygon_apocalypse_walkable_collision")
		parent.add_child(body, true)
		body.global_transform = mesh_instance.global_transform

		var shape_node := CollisionShape3D.new()
		shape_node.name = "WalkableShape"
		shape_node.shape = shape
		body.add_child(shape_node)
		_walkable_collisions_created += 1


func _add_static_collision_for(parent: Node3D, visual_node: Node3D, object_data: Dictionary = {}) -> void:
	var bounds := _calculate_bounds(visual_node)
	if bounds.size == Vector3.ZERO:
		return
	if bounds.size.x < BLOCKER_COLLISION_MIN_SIZE.x and bounds.size.y < BLOCKER_COLLISION_MIN_SIZE.y and bounds.size.z < BLOCKER_COLLISION_MIN_SIZE.z:
		return
	var combined := _object_data_search_text(object_data)
	if bounds.size.x > 24.0 and bounds.size.z > 24.0 and not combined.contains("building") and not combined.contains("wall"):
		return
	var shape_size := Vector3(
		maxf(bounds.size.x - BLOCKER_COLLISION_INSET.x * 2.0, 0.3),
		maxf(bounds.size.y - BLOCKER_COLLISION_INSET.y * 2.0, 0.3),
		maxf(bounds.size.z - BLOCKER_COLLISION_INSET.z * 2.0, 0.3)
	)
	var body := StaticBody3D.new()
	body.name = visual_node.name + "_Blocker"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.add_to_group("polygon_apocalypse_blocker_collision")
	parent.add_child(body, true)
	body.global_position = Vector3(bounds.get_center().x, bounds.position.y + shape_size.y * 0.5, bounds.get_center().z)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "BlockerShape"
	var shape := BoxShape3D.new()
	shape.size = shape_size
	shape_node.shape = shape
	body.add_child(shape_node)
	_collisions_created += 1


func _disable_imported_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_imported_collisions(child)


func _calculate_bounds(root: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(root, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var box := _transform_aabb(mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = box
			has_bounds = true
		else:
			bounds = bounds.merge(box)
	return bounds if has_bounds else AABB()


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, result)


func _transform_aabb(world_transform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := world_transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)


func _build_environment(environment_data) -> void:
	if not environment_data is Dictionary:
		return
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.22, 0.22, 0.22, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = _color_from_array((environment_data as Dictionary).get("ambient_sky_color", []))
	environment.ambient_light_energy = clampf(float((environment_data as Dictionary).get("ambient_intensity", 1.0)), 0.0, 4.0)
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	if bool((environment_data as Dictionary).get("fog_enabled", false)):
		environment.fog_enabled = true
		environment.fog_light_color = _color_from_array((environment_data as Dictionary).get("fog_color", []))
		environment.fog_density = maxf(float((environment_data as Dictionary).get("fog_density", 0.01)), 0.0)

	var world_environment := WorldEnvironment.new()
	world_environment.name = "PolygonApocalypseEnvironment"
	world_environment.environment = environment
	_root.add_child(world_environment)


func _build_lights(lights) -> void:
	var light_root := Node3D.new()
	light_root.name = "PolygonApocalypseLights"
	_root.add_child(light_root)

	if not lights is Array:
		_add_default_light(light_root)
		return

	var count := 0
	for light_data in lights:
		if light_data is Dictionary:
			if _spawn_light(light_root, light_data as Dictionary):
				count += 1
	if count == 0:
		_add_default_light(light_root)


func _calibrate_city_rendering() -> void:
	if not map_id.begins_with("city_"):
		return
	var layout := _root.get_node_or_null("PolygonApocalypseLayout") as Node3D
	if not layout:
		return
	var bounds := _calculate_bounds(layout)
	if bounds.size == Vector3.ZERO:
		return
	var center := bounds.get_center()
	var max_size := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var environment_node := _root.get_node_or_null("PolygonApocalypseEnvironment") as WorldEnvironment
	if environment_node and environment_node.environment:
		environment_node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment_node.environment.tonemap_exposure = 0.92 if map_id == "city_urp" else 0.62
		if map_id == "city_urp":
			environment_node.environment.ambient_light_energy = maxf(environment_node.environment.ambient_light_energy, 2.2)
		var sky_color := environment_node.environment.ambient_light_color
		var warm_lerp := 0.04 if map_id == "city_urp" else 0.1
		environment_node.environment.ambient_light_color = sky_color.lerp(Color(1.0, 0.84, 0.58, 1.0), warm_lerp)
	_tune_directional_lights_for_city(_root, center, max_size)
	if map_id == "city_urp":
		_tint_standard_materials(layout, Color(0.7426188, 0.6167212128, 0.486864, 1.0))
	else:
		_tint_standard_materials(layout, Color(0.98496, 0.89148, 0.83538, 1.0))
	_add_city_gameplay_lighting(layout, bounds)


func _add_city_gameplay_lighting(layout: Node3D, bounds: AABB) -> void:
	if not layout or bounds.size == Vector3.ZERO:
		return
	var existing := _root.get_node_or_null("PolygonApocalypseGameplayLighting")
	if existing:
		existing.queue_free()
	var lighting_root := Node3D.new()
	lighting_root.name = "PolygonApocalypseGameplayLighting"
	_root.add_child(lighting_root)

	var center := bounds.get_center()
	var half_x := bounds.size.x * 0.5
	var half_z := bounds.size.z * 0.5
	var light_points := [
		{"name": "QuarantineAmberLamp", "offset": Vector2(-0.32, -0.18), "height": 5.5, "range": 15.0, "energy": 1.25, "color": Color(1.0, 0.66, 0.36, 1.0)},
		{"name": "MarketBlueWorkLight", "offset": Vector2(0.26, 0.20), "height": 4.6, "range": 13.0, "energy": 0.95, "color": Color(0.46, 0.70, 1.0, 1.0)},
		{"name": "WarehouseColdLamp", "offset": Vector2(-0.08, 0.36), "height": 5.2, "range": 14.0, "energy": 0.85, "color": Color(0.64, 0.78, 1.0, 1.0)},
		{"name": "OverpassHazardLamp", "offset": Vector2(0.38, -0.34), "height": 4.8, "range": 12.0, "energy": 1.05, "color": Color(1.0, 0.44, 0.22, 1.0)},
	]
	for entry in light_points:
		var data := entry as Dictionary
		var light := OmniLight3D.new()
		light.name = str(data.get("name", "GameplayLamp"))
		light.omni_range = float(data.get("range", 12.0))
		light.light_energy = float(data.get("energy", 1.0))
		light.light_color = data.get("color", Color.WHITE)
		light.shadow_enabled = false
		var offset := data.get("offset", Vector2.ZERO) as Vector2
		light.position = center + Vector3(offset.x * half_x, float(data.get("height", 5.0)), offset.y * half_z)
		lighting_root.add_child(light, true)

	var shadow_zones := [
		{"name": "StalkerAlleyShadowA", "offset": Vector2(-0.44, -0.10), "size": Vector3(12.0, 2.8, 9.0), "yaw": 0.35},
		{"name": "StalkerCarShadowB", "offset": Vector2(0.10, -0.36), "size": Vector3(14.0, 2.8, 8.0), "yaw": -0.22},
		{"name": "StalkerWarehouseShadowC", "offset": Vector2(0.36, 0.08), "size": Vector3(11.0, 2.8, 11.0), "yaw": 0.7},
		{"name": "StalkerCanalShadowD", "offset": Vector2(-0.12, 0.42), "size": Vector3(16.0, 2.8, 7.5), "yaw": -0.5},
	]
	for entry in shadow_zones:
		var data := entry as Dictionary
		var offset := data.get("offset", Vector2.ZERO) as Vector2
		var zone_center := center + Vector3(offset.x * half_x, 1.2, offset.y * half_z)
		_add_stalker_shadow_zone(lighting_root, str(data.get("name", "StalkerShadowZone")), zone_center, data.get("size", Vector3(10.0, 2.8, 8.0)), float(data.get("yaw", 0.0)))


func _add_stalker_shadow_zone(parent: Node, zone_name: String, zone_position: Vector3, size, yaw: float) -> void:
	var area := Area3D.new()
	area.name = zone_name
	area.collision_layer = 0
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.add_to_group(STALKER_SHADOW_ZONE_GROUP)
	area.position = zone_position
	area.rotation.y = yaw
	parent.add_child(area, true)

	var shape_node := CollisionShape3D.new()
	shape_node.name = "ShadowZoneShape"
	var shape := BoxShape3D.new()
	shape.size = size as Vector3
	shape_node.shape = shape
	area.add_child(shape_node)


func _tune_directional_lights_for_city(node: Node, center: Vector3, max_size: float) -> void:
	if node is DirectionalLight3D:
		var light := node as DirectionalLight3D
		var warm_lerp := 0.3 if map_id == "city_urp" else 0.45
		light.light_color = light.light_color.lerp(Color(1.0, 0.84, 0.58, 1.0), warm_lerp)
		light.light_energy = maxf(light.light_energy, 2.0 if map_id == "city_urp" else 1.25)
		var light_direction := Vector3(-1.5, 1.5, 1.0) if map_id == "city_urp" else Vector3(0.75, 1.7, 0.75)
		light.look_at_from_position(
			center + light_direction.normalized() * max_size,
			center,
			Vector3.UP
		)
	for child in node.get_children():
		_tune_directional_lights_for_city(child, center, max_size)


func _tint_standard_materials(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.albedo_color = variant.albedo_color * tint
					if variant.emission_enabled:
						variant.emission = variant.emission * tint
					mesh_instance.set_surface_override_material(surface_index, variant)
	for child in node.get_children():
		_tint_standard_materials(child, tint)


func _set_standard_material_alpha(node: Node, alpha_value: float) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.albedo_color.a = clampf(alpha_value, 0.0, 1.0)
					variant.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if variant.albedo_color.a < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
					mesh_instance.set_surface_override_material(surface_index, variant)
	for child in node.get_children():
		_set_standard_material_alpha(child, alpha_value)


func _calibrate_building_rendering() -> void:
	if map_id != "building_interior_dressing":
		return
	var environment_node := _root.get_node_or_null("PolygonApocalypseEnvironment") as WorldEnvironment
	if environment_node and environment_node.environment:
		environment_node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment_node.environment.tonemap_exposure = 1.12
		environment_node.environment.ambient_light_energy = maxf(environment_node.environment.ambient_light_energy, 3.0)
		var sky_color := environment_node.environment.ambient_light_color
		environment_node.environment.ambient_light_color = sky_color.lerp(Color(1.0, 0.86, 0.62, 1.0), 0.22)
	var layout := _root.get_node_or_null("PolygonApocalypseLayout") as Node3D
	if layout:
		_tint_standard_materials(layout, Color(0.533413125, 0.5252625, 0.566015625, 1.0))
		_set_standard_material_normal_maps_enabled(layout, false)
	var bounds := _calculate_bounds(layout) if layout else AABB()
	_tune_lights_for_building(_root, bounds.get_center(), maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)))


func _tune_lights_for_building(node: Node, center: Vector3, max_size: float) -> void:
	if node is Light3D:
		var light := node as Light3D
		light.light_color = light.light_color.lerp(Color(1.0, 0.86, 0.62, 1.0), 0.25)
		if light is DirectionalLight3D and max_size > 0.0:
			light.light_energy = 0.8
			(light as DirectionalLight3D).look_at_from_position(
				center + Vector3(1.75, 1.5, -0.5).normalized() * max_size,
				center,
				Vector3.UP
			)
		else:
			light.light_energy = maxf(light.light_energy, 2.0)
	for child in node.get_children():
		_tune_lights_for_building(child, center, max_size)


func _set_standard_material_normal_maps_enabled(node: Node, enabled: bool) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_index)
				if material is StandardMaterial3D:
					var variant := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
					variant.normal_enabled = enabled
					mesh_instance.set_surface_override_material(surface_index, variant)
	for child in node.get_children():
		_set_standard_material_normal_maps_enabled(child, enabled)


func _calibrate_bunker_rendering() -> void:
	if map_id != "bunker":
		return
	var environment_node := _root.get_node_or_null("PolygonApocalypseEnvironment") as WorldEnvironment
	if environment_node and environment_node.environment:
		environment_node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment_node.environment.tonemap_exposure = 0.85
	var layout := _root.get_node_or_null("PolygonApocalypseLayout") as Node3D
	if layout:
		_tint_standard_materials(layout, Color(0.6, 0.52, 0.42, 1.0))


func _spawn_light(parent: Node3D, light_data: Dictionary) -> Light3D:
	var unity_type := int(light_data.get("type", 1))
	var light: Light3D
	match unity_type:
		0:
			light = SpotLight3D.new()
			(light as SpotLight3D).spot_angle = float(light_data.get("spot_angle", 30.0))
			(light as SpotLight3D).spot_range = float(light_data.get("range", 10.0))
		2:
			light = OmniLight3D.new()
			(light as OmniLight3D).omni_range = float(light_data.get("range", 10.0))
		_:
			light = DirectionalLight3D.new()
			(light as DirectionalLight3D).shadow_enabled = true
	light.name = _safe_node_name(str(light_data.get("name", "UnityLight")))
	parent.add_child(light, true)
	light.global_position = _vector3_from_array(light_data.get("position", []))
	light.quaternion = _quaternion_from_array(light_data.get("rotation", []))
	light.light_color = _color_from_array(light_data.get("color", []))
	light.light_energy = clampf(float(light_data.get("intensity", 1.0)), 0.05, 8.0)
	return light


func _color_from_array(value) -> Color:
	if value is Array and (value as Array).size() >= 4:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return Color.WHITE


func _add_default_light(parent: Node3D) -> void:
	var light := DirectionalLight3D.new()
	light.name = "DefaultSun"
	light.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	parent.add_child(light)
