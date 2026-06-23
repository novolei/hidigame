class_name ChameleonPropCatalog
extends RefCounted

const CATALOG_PATH := "res://assets/camouflage_props/catalog.json"
const DEFAULT_HAND_SIZE := 5
const VALID_MESH_TYPES := ["scene", "box", "cylinder", "sphere", "cactus", "runtime_gltf"]
const MIN_PLAYABLE_HEIGHT := 0.25
const MAX_PLAYABLE_HEIGHT := 4.0
const MIN_PLAYABLE_RADIUS := 0.08
const MAX_PLAYABLE_RADIUS := 2.2

static var _cached_items: Array = []


static func load_catalog() -> Array:
	if _cached_items.is_empty():
		_cached_items = _load_items_from_manifest()
	if _cached_items.is_empty():
		_cached_items = _fallback_items()
	return _duplicate_items(_cached_items)


static func get_hand_size() -> int:
	var manifest := _read_manifest()
	if manifest.has("hand_size"):
		return clampi(int(manifest.get("hand_size", DEFAULT_HAND_SIZE)), 1, 12)
	return DEFAULT_HAND_SIZE


static func random_hand_for_player(player_id: int, session_seed: String = "", count: int = DEFAULT_HAND_SIZE) -> Array:
	var items := load_catalog()
	if items.is_empty():
		return []
	var target_count := clampi(count, 1, items.size())
	var rng := RandomNumberGenerator.new()
	var seed_source := "%s|%d|%d" % [session_seed, player_id, items.size()]
	rng.seed = int(abs(seed_source.hash()))
	var pool := items.duplicate(true)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = pool[i]
		pool[i] = pool[j]
		pool[j] = temp
	return pool.slice(0, target_count)


static func get_preset_by_id(preset_id: String) -> Dictionary:
	for item in load_catalog():
		var preset := item as Dictionary
		if str(preset.get("id", "")) == preset_id:
			return preset.duplicate(true)
	return {}


static func build_qa_report(validate_scene_loads: bool = true) -> Dictionary:
	var items := load_catalog()
	var errors := []
	var warnings := []
	var entries := []
	var id_counts := {}
	var hand_size := get_hand_size()
	if items.is_empty():
		errors.append("Catalog has no playable prop items.")
	if hand_size > items.size():
		errors.append("Catalog hand_size %d is larger than item count %d." % [hand_size, items.size()])
	for item in items:
		if not item is Dictionary:
			errors.append("Catalog item is not a Dictionary.")
			continue
		var preset := normalize_preset(item as Dictionary)
		var id := str(preset.get("id", ""))
		id_counts[id] = int(id_counts.get(id, 0)) + 1
		var entry := _qa_entry_for_preset(preset, validate_scene_loads)
		entries.append(entry)
		for message in entry.get("errors", []):
			errors.append("%s: %s" % [id, str(message)])
		for message in entry.get("warnings", []):
			warnings.append("%s: %s" % [id, str(message)])
	for id in id_counts.keys():
		if id.is_empty():
			errors.append("Catalog contains an item with an empty id.")
		elif int(id_counts[id]) > 1:
			errors.append("Duplicate prop id '%s' appears %d times." % [id, int(id_counts[id])])
	return {
		"ok": errors.is_empty(),
		"item_count": items.size(),
		"hand_size": hand_size,
		"errors": errors,
		"warnings": warnings,
		"entries": entries,
	}


static func normalize_preset(raw_preset: Dictionary) -> Dictionary:
	var preset := raw_preset.duplicate(true)
	preset["id"] = str(preset.get("id", "custom_prop"))
	preset["name"] = str(preset.get("name", preset.get("id", "Prop")))
	preset["mesh"] = str(preset.get("mesh", "box"))
	preset["scene_path"] = str(preset.get("scene_path", ""))
	preset["material_path"] = str(preset.get("material_path", ""))
	preset["scale"] = _vector3_from_value(preset.get("scale", Vector3.ONE), Vector3.ONE)
	preset["size"] = _vector3_from_value(preset.get("size", Vector3.ONE), Vector3.ONE)
	preset["offset"] = _vector3_from_value(preset.get("offset", Vector3.ZERO), Vector3.ZERO)
	preset["rotation"] = _vector3_from_value(preset.get("rotation", Vector3.ZERO), Vector3.ZERO)
	preset["color"] = _color_from_value(preset.get("color", Color.WHITE), Color.WHITE)
	preset["collision_radius"] = float(preset.get("collision_radius", maxf(preset["size"].x, preset["size"].z) * 0.42))
	preset["collision_height"] = float(preset.get("collision_height", maxf(preset["size"].y * 0.82, preset["collision_radius"] * 0.75)))
	preset["drop_height"] = float(preset.get("drop_height", 0.0))
	if not preset.has("tags") or not preset.get("tags") is Array:
		preset["tags"] = []
	return preset


static func _qa_entry_for_preset(preset: Dictionary, validate_scene_loads: bool) -> Dictionary:
	var errors := []
	var warnings := []
	var mesh_type := str(preset.get("mesh", ""))
	if not VALID_MESH_TYPES.has(mesh_type):
		errors.append("Unsupported mesh type '%s'." % mesh_type)
	if str(preset.get("name", "")).strip_edges().is_empty():
		warnings.append("Display name is empty.")
	if str(preset.get("category", "")).strip_edges().is_empty():
		warnings.append("Category is empty.")
	var tags = preset.get("tags", [])
	if not tags is Array or (tags as Array).is_empty():
		warnings.append("Tags are empty; random selection and map-theme filtering will be weaker.")
	var scale: Vector3 = preset.get("scale", Vector3.ONE)
	var size: Vector3 = preset.get("size", Vector3.ONE)
	_validate_positive_vector(scale, "scale", errors)
	_validate_positive_vector(size, "size", errors)
	var collision_radius := float(preset.get("collision_radius", 0.0))
	var collision_height := float(preset.get("collision_height", 0.0))
	if collision_radius < MIN_PLAYABLE_RADIUS or collision_radius > MAX_PLAYABLE_RADIUS:
		errors.append("collision_radius %.3f is outside playable range %.2f..%.2f." % [collision_radius, MIN_PLAYABLE_RADIUS, MAX_PLAYABLE_RADIUS])
	if collision_height < MIN_PLAYABLE_HEIGHT or collision_height > MAX_PLAYABLE_HEIGHT:
		errors.append("collision_height %.3f is outside playable range %.2f..%.2f." % [collision_height, MIN_PLAYABLE_HEIGHT, MAX_PLAYABLE_HEIGHT])
	var estimated_diameter := collision_radius * 2.0
	var max_size_xz := maxf(absf(size.x), absf(size.z))
	if max_size_xz > 0.001 and estimated_diameter > max_size_xz * 1.35:
		warnings.append("Collision diameter %.3f is much wider than catalog size xz %.3f." % [estimated_diameter, max_size_xz])
	if size.y > 0.001 and collision_height < size.y * 0.35:
		warnings.append("Collision height %.3f is much shorter than catalog visual size y %.3f." % [collision_height, size.y])
	var visual := _qa_visual_summary_for_preset(preset, validate_scene_loads, errors, warnings)
	var visual_height := float(visual.get("height", size.y))
	if visual_height < MIN_PLAYABLE_HEIGHT:
		warnings.append("Visual height %.3f is very small for a readable disguise." % visual_height)
	elif visual_height > MAX_PLAYABLE_HEIGHT:
		warnings.append("Visual height %.3f is very tall for current Chameleon gameplay." % visual_height)
	return {
		"id": str(preset.get("id", "")),
		"name": str(preset.get("name", "")),
		"mesh": mesh_type,
		"scene_path": str(preset.get("scene_path", "")),
		"mesh_count": int(visual.get("mesh_count", 0)),
		"visual_bounds": visual.get("bounds", AABB()),
		"height": visual_height,
		"loadable": bool(visual.get("loadable", mesh_type != "scene")),
		"errors": errors,
		"warnings": warnings,
	}


static func _qa_visual_summary_for_preset(preset: Dictionary, validate_scene_loads: bool, errors: Array, warnings: Array) -> Dictionary:
	var mesh_type := str(preset.get("mesh", "box"))
	if mesh_type != "scene":
		var size: Vector3 = preset.get("size", Vector3.ONE)
		return {
			"loadable": true,
			"mesh_count": 1,
			"bounds": AABB(-size * 0.5, size),
			"height": size.y,
		}
	var scene_path := str(preset.get("scene_path", ""))
	if scene_path.is_empty():
		errors.append("Scene mesh has an empty scene_path.")
		return {"loadable": false, "mesh_count": 0, "bounds": AABB(), "height": 0.0}
	if not FileAccess.file_exists(scene_path) and not ResourceLoader.exists(scene_path):
		errors.append("Scene path does not exist: %s" % scene_path)
		return {"loadable": false, "mesh_count": 0, "bounds": AABB(), "height": 0.0}
	if not validate_scene_loads:
		return {"loadable": true, "mesh_count": 0, "bounds": AABB(), "height": 0.0}
	var scene := load(scene_path)
	if not scene is PackedScene:
		errors.append("Scene path does not load as PackedScene: %s" % scene_path)
		return {"loadable": false, "mesh_count": 0, "bounds": AABB(), "height": 0.0}
	var root := (scene as PackedScene).instantiate() as Node3D
	if not root:
		errors.append("PackedScene did not instantiate as Node3D: %s" % scene_path)
		return {"loadable": false, "mesh_count": 0, "bounds": AABB(), "height": 0.0}
	root.scale = preset.get("scale", Vector3.ONE)
	var bounds_payload := _collect_visual_bounds(root)
	root.free()
	var mesh_count := int(bounds_payload.get("mesh_count", 0))
	if mesh_count <= 0:
		warnings.append("Scene has no MeshInstance3D nodes.")
	var bounds: AABB = bounds_payload.get("bounds", AABB())
	return {
		"loadable": true,
		"mesh_count": mesh_count,
		"bounds": bounds,
		"height": bounds.size.y,
	}


static func _collect_visual_bounds(root: Node3D) -> Dictionary:
	var state := {
		"mesh_count": 0,
		"has_bounds": false,
		"bounds": AABB(),
	}
	_collect_mesh_bounds(root, root.transform, state)
	return {
		"mesh_count": int(state.get("mesh_count", 0)),
		"bounds": state.get("bounds", AABB()) if bool(state.get("has_bounds", false)) else AABB(),
	}


static func _collect_mesh_bounds(node: Node3D, node_transform: Transform3D, state: Dictionary) -> void:
	if node is MeshInstance3D:
		state["mesh_count"] = int(state.get("mesh_count", 0)) + 1
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			var local_bounds := _transform_aabb(node_transform, mesh_instance.get_aabb())
			if bool(state.get("has_bounds", false)):
				state["bounds"] = (state.get("bounds", AABB()) as AABB).merge(local_bounds)
			else:
				state["bounds"] = local_bounds
				state["has_bounds"] = true
	for child in node.get_children():
		if child is Node3D:
			var child_node := child as Node3D
			_collect_mesh_bounds(child_node, node_transform * child_node.transform, state)


static func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var point := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
				var transformed := transform * point
				min_corner = min_corner.min(transformed)
				max_corner = max_corner.max(transformed)
	return AABB(min_corner, max_corner - min_corner)


static func _validate_positive_vector(value: Vector3, label: String, errors: Array) -> void:
	if value.x <= 0.0 or value.y <= 0.0 or value.z <= 0.0:
		errors.append("%s must be positive, got %s." % [label, str(value)])


static func build_cloud_placeholder_preset(name: String = "Generated Prop") -> Dictionary:
	return normalize_preset({
		"id": "cloud_generated_placeholder",
		"name": name,
		"mesh": "box",
		"size": [1.15, 1.2, 1.15],
		"scale": [1.0, 1.0, 1.0],
		"collision_radius": 0.52,
		"collision_height": 1.05,
		"color": "#f4f0e9",
		"tags": ["cloud", "white_model"]
	})


static func _load_items_from_manifest() -> Array:
	var manifest := _read_manifest()
	var raw_items = manifest.get("items", [])
	if not raw_items is Array:
		return []
	var items := []
	for raw in raw_items:
		if raw is Dictionary:
			items.append(normalize_preset(raw as Dictionary))
	return items


static func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(CATALOG_PATH):
		return {}
	var json_text := FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed = JSON.parse_string(json_text)
	return parsed as Dictionary if parsed is Dictionary else {}


static func _fallback_items() -> Array:
	return [
		normalize_preset({
			"id": "fallback_crate",
			"name": "Crate",
			"mesh": "box",
			"size": [1.15, 1.15, 1.15],
			"color": "#8f6545",
			"tags": ["fallback", "box"]
		}),
		normalize_preset({
			"id": "fallback_barrel",
			"name": "Barrel",
			"mesh": "cylinder",
			"size": [0.85, 1.45, 0.85],
			"color": "#7f6f5d",
			"tags": ["fallback", "round"]
		}),
		normalize_preset({
			"id": "fallback_rock",
			"name": "Rock",
			"mesh": "sphere",
			"size": [1.15, 0.75, 1.0],
			"color": "#686a63",
			"tags": ["fallback", "rock"]
		})
	]


static func _duplicate_items(items: Array) -> Array:
	var copy := []
	for item in items:
		copy.append((item as Dictionary).duplicate(true) if item is Dictionary else item)
	return copy


static func _vector3_from_value(value, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)), float(value.get("z", fallback.z)))
	return fallback


static func _color_from_value(value, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		var text := str(value)
		if text.begins_with("#") and (text.length() == 7 or text.length() == 9):
			return Color.html(text)
	if value is Array and value.size() >= 3:
		var alpha := float(value[3]) if value.size() > 3 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	if value is Dictionary:
		return Color(
			float(value.get("r", fallback.r)),
			float(value.get("g", fallback.g)),
			float(value.get("b", fallback.b)),
			float(value.get("a", fallback.a))
		)
	return fallback
