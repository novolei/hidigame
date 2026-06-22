extends Node3D
class_name TankDemoMap

@export_enum("desert", "jungle", "moon") var map_id := "desert"

const WORLD_LAYER := 2
const MAP_SIZE := 92.0
const MODEL_ROOT := "res://assets/unity_migrated/tanks_complete/Art/Models/"
const AUDIO_ROOT := "res://assets/unity_migrated/tanks_complete/Audio/"

const LAYOUTS := {
	"desert": "res://assets/unity_migrated/tanks_complete/layouts/desert.json",
	"jungle": "res://assets/unity_migrated/tanks_complete/layouts/jungle.json",
	"moon": "res://assets/unity_migrated/tanks_complete/layouts/moon.json",
}

const MATERIALS := {
	"desert_ground": "res://Materials/M_tank_demo_desert_ground.tres",
	"jungle_ground": "res://Materials/M_tank_demo_jungle_ground.tres",
	"moon_ground": "res://Materials/M_tank_demo_moon_ground.tres",
	"brown": "res://Materials/M_tank_demo_brown.tres",
	"green": "res://Materials/M_tank_demo_green.tres",
	"flower": "res://Materials/M_tank_demo_flower.tres",
	"building_white": "res://Materials/M_tank_demo_building_white.tres",
	"building_grey": "res://Materials/M_tank_demo_building_grey.tres",
	"building_metal": "res://Materials/M_tank_demo_building_metal.tres",
	"building_glass": "res://Materials/M_tank_demo_building_glass.tres",
	"white": "res://Materials/M_tank_demo_white.tres",
	"yellow_bright": "res://Materials/M_tank_demo_yellow_bright.tres",
	"yellow_light": "res://Materials/M_tank_demo_yellow_light.tres",
	"yellow_mid": "res://Materials/M_tank_demo_yellow_mid.tres",
	"water": "res://Materials/M_tank_demo_water.tres",
	"hippo": "res://Materials/M_tank_demo_hippo.tres",
	"green_doors": "res://Materials/M_tank_demo_green_doors.tres",
	"green_dark": "res://Materials/M_tank_demo_green_dark.tres",
	"stone": "res://Materials/M_tank_demo_stone.tres",
	"jungle_rock": "res://Materials/M_tank_demo_jungle_rock.tres",
	"moon_rock": "res://Materials/M_tank_demo_moon_rock.tres",
	"oil": "res://Materials/M_tank_demo_oil.tres",
	"tank_color": "res://Materials/M_tank_demo_tank_color.tres",
	"tank_blue": "res://Materials/M_tank_demo_tank_blue.tres",
	"tank_grey": "res://Materials/M_tank_demo_tank_grey.tres",
	"tank_lights": "res://Materials/M_tank_demo_tank_lights.tres",
}

const MATERIAL_GUID_MAP := {
	"65b34bd0b696fd64c809daa8ff1aac63": "brown",
	"c39933e60e73205419d1f79a2af1fdac": "green",
	"d725d1299e7bcb145acf1e059f85317d": "green",
	"416a0a4c58b972b479aa70e27a23707f": "green_dark",
	"f97c89fd8a47df347817320258da2bc4": "green_dark",
	"16ad2a62332d71e4faf6973d9f3daed4": "jungle_ground",
	"f81ff0a12607c164fa52fd3107764fea": "jungle_ground",
	"afd74380c9bb34d49ab95f80a7a4f465": "jungle_ground",
	"3d220fbf76698ca45a062bc0564ed8f7": "jungle_rock",
	"19f1ed20a8d2df946b5acdf7729f85f0": "moon_rock",
	"c6fc29d379b32be418c1261b64f8b47e": "moon_rock",
	"63657fd3af2ee4a4d8ec1b203282f46a": "moon_rock",
	"7471dc33846f1ba4796a5df18ee898bd": "moon_ground",
	"78630095e2f77d04ea99b56faf896276": "flower",
	"a2f931bbce4e3eb4993f9f0b7ad1efd9": "flower",
	"ced395ad3dc1d074d99d6b7ccafb09c7": "oil",
	"ec589a6713edc96499d941b21343565e": "oil",
	"e7df269b1d6121e4787b2f27aab18dbe": "building_metal",
	"00b91d76f655eaf488c0ca8bdd181a07": "building_white",
	"02a830f1d2fd1e545b31e9070db85502": "building_grey",
	"fe45be4ed17b56849afc17904e9a1028": "stone",
	"8409077f9ff512c4988a0ecd4bdf6827": "stone",
	"2adca53f00baf334aa34ff0eea351a62": "stone",
	"306d0bfefa4ca494faae1b7f01978af4": "stone",
	"b3a1f2f69b4c3a84cba5446e31e87c20": "oil",
	"3ce81f985292a6048b1983593b944b37": "yellow_mid",
	"df3167d6df0aba54bba9a1a40f79c38f": "yellow_light",
	"64f19a33efad19940a21774215e4c745": "yellow_bright",
	"c0d660c0333c4224098a02ecd84d6232": "white",
	"afcd8de4d9da6a045bd09b4f5cc84fa9": "water",
	"11ec0851f7ef8624cbdf43d6b3cfdd92": "hippo",
	"1597146e9ac5cf046a8fe924b128fdbb": "green_doors",
	"12c120f2400576c4f97a98bcca5529bc": "tank_color",
	"c4c5f95d06932564c8672b4bafeb1b28": "tank_grey",
	"574c4e070e5dd0a40a02b979f582a836": "tank_lights",
	"22102142cf4af6e4f9cbd386250608aa": "building_glass",
}

const COMMON_MATERIAL_MAP := {
	"Brown": "brown",
	"Green": "green",
	"GreenGround": "jungle_ground",
	"Flower": "flower",
	"BuildingWhite": "building_white",
	"BuildingGrey": "building_grey",
	"BuildingGray": "building_grey",
	"BuildingMetal": "building_metal",
	"BuildingGlass": "building_glass",
	"BuildingStone": "stone",
	"RockBrown": "stone",
	"RockStoneBeige": "stone",
	"OilDrums": "oil",
	"DarkShine": "oil",
	"MoonCrator": "moon_rock",
	"Pink": "flower",
}

const TANK_MATERIAL_MAP := {
	"TankColor": "tank_color",
	"TankRed": "tank_color",
	"TankGrey": "tank_grey",
	"TankLights": "tank_lights",
	"TankWindow": "building_glass",
	"Grey": "tank_grey",
}

var _root: Node3D


func _ready() -> void:
	build()


func build() -> void:
	_clear_generated()
	_root = Node3D.new()
	_root.name = "GeneratedTankDemoMap"
	add_child(_root)

	var config := _get_config()
	var has_prefab_layout := _layout_exists(str(config.get("layout", "")))
	_build_ground(str(config.get("ground_material", "desert_ground")), true)
	if has_prefab_layout:
		_build_prefab_layout(str(config.get("layout", "")))
	else:
		_build_scenery(config.get("props", []))
	_build_demo_tanks(config.get("tanks", []))
	_build_audio_nodes(config)


func _clear_generated() -> void:
	var existing := get_node_or_null("GeneratedTankDemoMap")
	if existing:
		existing.free()


func _get_config() -> Dictionary:
	match map_id:
		"jungle":
			return _jungle_config()
		"moon":
			return _moon_config()
		_:
			return _desert_config()


func _desert_config() -> Dictionary:
	return {
		"ground_material": "desert_ground",
		"layout": LAYOUTS["desert"],
		"music": AUDIO_ROOT + "Music/Music_Western.ogg",
		"props": [
			_prop("Dunes01", "Environment/Dunes01.glb", Vector3(-18, 0, -18), -20, Vector3.ONE * 1.2, "stone", false),
			_prop("Dunes02", "Environment/Dunes02.glb", Vector3(21, 0, 12), 26, Vector3.ONE * 1.1, "stone", false),
			_prop("PalmTreeA", "Environment/PalmTree.glb", Vector3(-24, 0, 18), 15, Vector3.ONE * 1.35, "green", true),
			_prop("PalmTreeB", "Environment/PalmTree02.glb", Vector3(-28, 0, 10), -20, Vector3.ONE * 1.1, "green", true),
			_prop("PalmTreeC", "Environment/PalmTree03.glb", Vector3(18, 0, -20), 38, Vector3.ONE * 1.2, "green", true),
			_prop("PumpJack", "Environment/PumpJack.glb", Vector3(24, 0, -12), -35, Vector3.ONE * 1.0, "oil", true, {}, true),
			_prop("Refinery", "Environment/Refinery.glb", Vector3(30, 0, 20), 42, Vector3.ONE * 0.9, "oil", true),
			_prop("OilStorage", "Environment/OilStorage.glb", Vector3(12, 0, -28), 10, Vector3.ONE * 1.4, "oil", true),
			_prop("Column01", "Environment/Column01.glb", Vector3(-14, 0, 25), -12, Vector3.ONE * 1.15, "stone", true),
			_prop("Rocks01", "Environment/Rocks01.glb", Vector3(-8, 0, -25), 44, Vector3.ONE * 1.45, "stone", true),
			_prop("CactusA", "Environment/Cactus.glb", Vector3(6, 0, 30), 18, Vector3.ONE * 1.35, "green", true),
			_prop("CactusB", "Environment/Cactus.glb", Vector3(-30, 0, -8), -26, Vector3.ONE * 1.15, "green", true),
		],
		"tanks": [
			_tank("DemoTankOriginal", "Tanks/Tank_Original_Model.glb", Vector3(-8, 0, 8), 32, Vector3.ONE * 1.2, "tank_color"),
			_tank("DemoTankHeavy", "Tanks/Tank_Heavy_Model.glb", Vector3(8, 0, -6), -142, Vector3.ONE * 1.05, "tank_blue"),
		],
	}


func _jungle_config() -> Dictionary:
	return {
		"ground_material": "jungle_ground",
		"layout": LAYOUTS["jungle"],
		"music": AUDIO_ROOT + "Music/Music_Mysterious.ogg",
		"props": [
			_prop("JungleTemple", "Environment/Jungle Temple.glb", Vector3(22, 0, 6), 35, Vector3.ONE * 0.92, "jungle_rock", true),
			_prop("JungleTempleSmall", "Environment/Jungle Temple 02.glb", Vector3(-22, 0, -16), -35, Vector3.ONE * 1.05, "jungle_rock", true),
			_prop("MudPatchA", "Environment/Mud 01.glb", Vector3(4, 0.02, 18), 25, Vector3.ONE * 1.55, "jungle_ground", false),
			_prop("BushA", "Environment/Bush 01.glb", Vector3(-18, 0, 17), 25, Vector3.ONE * 1.5, "green", true),
			_prop("BushB", "Environment/Bush 02.glb", Vector3(-26, 0, 5), -15, Vector3.ONE * 1.3, "green", true),
			_prop("BushC", "Environment/Bush 03.glb", Vector3(20, 0, -20), 38, Vector3.ONE * 1.4, "green", true),
			_prop("TreeA", "Environment/Tree.glb", Vector3(0, 0, -28), 0, Vector3.ONE * 1.55, "green", true),
			_prop("PalmTreeJungle", "Environment/PalmTree01.glb", Vector3(30, 0, 23), 24, Vector3.ONE * 1.3, "green", true),
			_prop("FlowerA", "Environment/Jungle Flower.glb", Vector3(-5, 0, 28), -30, Vector3.ONE * 1.4, "flower", true),
			_prop("Hippo", "Environment/Hippo.glb", Vector3(-31, 0, -26), 32, Vector3.ONE * 0.95, "building_grey", true),
			_prop("RockyPath", "Environment/RockyPath.glb", Vector3(2, 0.01, -8), 20, Vector3.ONE * 1.25, "jungle_rock", false),
		],
		"tanks": [
			_tank("DemoTankUTV", "Tanks/Tank_UTV_Model.glb", Vector3(-8, 0, 8), -20, Vector3.ONE * 1.12, "tank_color"),
			_tank("DemoTankShark", "Tanks/Tank_Shark_Model.glb", Vector3(10, 0, -7), 160, Vector3.ONE * 1.1, "tank_blue"),
		],
	}


func _moon_config() -> Dictionary:
	return {
		"ground_material": "moon_ground",
		"layout": LAYOUTS["moon"],
		"music": AUDIO_ROOT + "Music/Music_Steady.ogg",
		"props": [
			_prop("MoonBaseA", "Environment/MoonBuilding01.glb", Vector3(24, 0, -8), 20, Vector3.ONE * 0.9, "building_white", true),
			_prop("MoonBaseB", "Environment/MoonBuilding02.glb", Vector3(-24, 0, 14), -36, Vector3.ONE * 0.82, "building_white", true),
			_prop("MoonCraterA", "Environment/CratorsMoon01.glb", Vector3(2, 0.02, 24), 0, Vector3.ONE * 1.8, "moon_rock", false),
			_prop("MoonCraterB", "Environment/CratorsMoon02.glb", Vector3(-8, 0.02, -24), 45, Vector3.ONE * 1.6, "moon_rock", false),
			_prop("Crater01", "Environment/Crater01.glb", Vector3(18, 0.02, 22), -18, Vector3.ONE * 1.5, "moon_rock", false),
			_prop("Crater02", "Environment/Crater02.glb", Vector3(-28, 0.02, -18), 24, Vector3.ONE * 1.45, "moon_rock", false),
			_prop("CliffA", "Environment/Cliff.glb", Vector3(32, 0, 18), -12, Vector3.ONE * 0.75, "moon_rock", true),
			_prop("CliffB", "Environment/Cliff.glb", Vector3(-33, 0, -12), 148, Vector3.ONE * 0.7, "moon_rock", true),
			_prop("RadarSphere", "Environment/RadarSphere.glb", Vector3(0, 0, -31), 15, Vector3.ONE * 1.2, "building_metal", true),
			_prop("Building01", "Environment/Building01.glb", Vector3(30, 0, -28), 50, Vector3.ONE * 0.9, "building_white", true),
		],
		"tanks": [
			_tank("DemoTankHeavyMoon", "Tanks/Tank_Heavy_Model.glb", Vector3(-8, 0, 8), 12, Vector3.ONE * 1.08, "tank_blue"),
			_tank("DemoTankOriginalMoon", "Tanks/Tank_Original_Model.glb", Vector3(10, 0, -8), -158, Vector3.ONE * 1.18, "tank_color"),
		],
	}


func _prop(name: String, path: String, position: Vector3, yaw_degrees: float, scale: Vector3, fallback_material: String, collision: bool, material_map: Dictionary = {}, play_animation: bool = false) -> Dictionary:
	return {
		"name": name,
		"path": MODEL_ROOT + path,
		"position": position,
		"yaw": yaw_degrees,
		"scale": scale,
		"fallback": fallback_material,
		"collision": collision,
		"material_map": material_map,
		"play_animation": play_animation,
	}


func _tank(name: String, path: String, position: Vector3, yaw_degrees: float, scale: Vector3, body_material: String) -> Dictionary:
	var material_map := TANK_MATERIAL_MAP.duplicate()
	material_map["TankColor"] = body_material
	material_map["TankRed"] = body_material
	return _prop(name, path, position, yaw_degrees, scale, body_material, true, material_map)


func _build_ground(material_key: String, show_visual: bool = true) -> void:
	var body := StaticBody3D.new()
	body.name = "TankDemoGround"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	_root.add_child(body)

	if show_visual:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "GroundVisual"
		var plane := PlaneMesh.new()
		plane.size = Vector2(MAP_SIZE, MAP_SIZE)
		mesh_instance.mesh = plane
		mesh_instance.material_override = _load_material_key(material_key)
		body.add_child(mesh_instance)

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(MAP_SIZE, 0.08, MAP_SIZE)
	shape_node.shape = shape
	shape_node.position.y = -0.04
	body.add_child(shape_node)


func _layout_exists(layout_path: String) -> bool:
	return not layout_path.is_empty() and FileAccess.file_exists(layout_path)


func _build_prefab_layout(layout_path: String) -> void:
	var prop_root := Node3D.new()
	prop_root.name = "TankDemoPrefabLayout"
	_root.add_child(prop_root)

	var text := FileAccess.get_file_as_string(layout_path)
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Tank demo layout JSON did not parse: " + layout_path)
		return
	for object_data in (parsed as Dictionary).get("objects", []):
		if not object_data is Dictionary:
			continue
		var data := _layout_object_to_spawn_data(object_data as Dictionary)
		if data.is_empty():
			continue
		_spawn_model(prop_root, data)
	_align_bottom_to_ground(prop_root)


func _layout_object_to_spawn_data(object_data: Dictionary) -> Dictionary:
	var scene_path := str(object_data.get("scene", ""))
	if scene_path.is_empty():
		return {}
	var name := str(object_data.get("name", scene_path.get_file().get_basename()))
	var fallback := _fallback_material_for_layout_object(object_data)
	return {
		"name": name,
		"path": scene_path,
		"position": _vector3_from_array(object_data.get("position", [])),
		"rotation_quat": _quaternion_from_array(object_data.get("rotation", [])),
		"scale": _vector3_from_array(object_data.get("scale", []), Vector3.ONE),
		"fallback": fallback,
		"collision": _layout_object_should_collide(object_data),
		"align_bottom": false,
		"material_guids": object_data.get("material_guids", []),
	}


func _vector3_from_array(value, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


func _quaternion_from_array(value) -> Quaternion:
	if value is Array and (value as Array).size() >= 4:
		return Quaternion(float(value[0]), float(value[1]), float(value[2]), float(value[3])).normalized()
	return Quaternion.IDENTITY


func _fallback_material_for_layout_object(object_data: Dictionary) -> String:
	var material_guids = object_data.get("material_guids", [])
	if material_guids is Array:
		for guid in material_guids:
			var guid_string := str(guid)
			if MATERIAL_GUID_MAP.has(guid_string):
				return str(MATERIAL_GUID_MAP[guid_string])
	var combined := (str(object_data.get("name", "")) + " " + str(object_data.get("source_asset", ""))).to_lower()
	if combined.contains("ground") or combined.contains("sand"):
		return "desert_ground"
	if combined.contains("jungle") or combined.contains("mud") or combined.contains("grass"):
		return "jungle_ground"
	if combined.contains("moon") or combined.contains("crator") or combined.contains("crater"):
		return "moon_rock"
	if combined.contains("building"):
		return "building_white"
	if combined.contains("oil") or combined.contains("refinery") or combined.contains("pump"):
		return "oil"
	if combined.contains("rock") or combined.contains("cliff") or combined.contains("column"):
		return "stone"
	if combined.contains("palm") or combined.contains("tree") or combined.contains("bush") or combined.contains("cactus"):
		return "green"
	return "brown"


func _layout_object_should_collide(object_data: Dictionary) -> bool:
	var combined := (str(object_data.get("name", "")) + " " + str(object_data.get("source_asset", ""))).to_lower()
	for token in ["ground", "path", "mud", "oasis", "crator", "crater", "helipad", "grass"]:
		if combined.contains(token):
			return false
	return true


func _build_scenery(props: Array) -> void:
	var prop_root := Node3D.new()
	prop_root.name = "TankDemoScenery"
	_root.add_child(prop_root)
	for data in props:
		_spawn_model(prop_root, data)


func _build_demo_tanks(tanks: Array) -> void:
	var tank_root := Node3D.new()
	tank_root.name = "TankDemoTanks"
	_root.add_child(tank_root)
	for data in tanks:
		var tank := _spawn_model(tank_root, data)
		if tank:
			tank.add_to_group("tank_demo_showcase")
			_animate_tank(tank)


func _spawn_model(parent: Node3D, data: Dictionary) -> Node3D:
	var path := str(data.get("path", ""))
	var packed := load(path)
	if not packed is PackedScene:
		push_warning("Tank demo model failed to load: " + path)
		return null

	var node := (packed as PackedScene).instantiate() as Node3D
	if not node:
		push_warning("Tank demo model did not instantiate as Node3D: " + path)
		return null

	node.name = str(data.get("name", "TankDemoAsset"))
	parent.add_child(node, true)
	node.global_position = data.get("position", Vector3.ZERO)
	if data.has("rotation_quat"):
		node.quaternion = data["rotation_quat"]
	else:
		node.rotation.y = deg_to_rad(float(data.get("yaw", 0.0)))
	node.scale = data.get("scale", Vector3.ONE)

	var material_map := COMMON_MATERIAL_MAP.duplicate()
	var custom_map = data.get("material_map", {})
	if custom_map is Dictionary:
		for key in (custom_map as Dictionary).keys():
			material_map[key] = custom_map[key]
	_apply_surface_materials(node, str(data.get("fallback", "")), material_map, data.get("material_guids", []))
	if bool(data.get("align_bottom", true)):
		_align_bottom_to_ground(node)
	_play_imported_animation(node, bool(data.get("play_animation", false)))
	_disable_imported_collisions(node)
	if bool(data.get("collision", true)):
		_add_static_collision_for(parent, node)
	return node


func _apply_surface_materials(node: Node, fallback_key: String, material_map: Dictionary, material_guids = []) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh:
			for i in range(mesh_instance.mesh.get_surface_count()):
				var source_name := _surface_material_name(mesh_instance, i)
				var material := _match_guid_material(material_guids, i)
				if not material:
					material = _match_material(source_name, mesh_instance.name, material_map)
				if not material:
					material = _semantic_mesh_material(mesh_instance, i, fallback_key)
				if not material:
					material = _load_material_key(fallback_key)
				if material:
					mesh_instance.set_surface_override_material(i, material)
	for child in node.get_children():
		_apply_surface_materials(child, fallback_key, material_map, material_guids)


func _surface_material_name(mesh_instance: MeshInstance3D, surface_index: int) -> String:
	var material := mesh_instance.get_surface_override_material(surface_index)
	if not material and mesh_instance.mesh:
		material = mesh_instance.mesh.surface_get_material(surface_index)
	if material:
		if not material.resource_name.is_empty():
			return material.resource_name
		if not material.resource_path.is_empty():
			return material.resource_path.get_file().get_basename()
	return ""


func _match_material(source_name: String, mesh_name: String, material_map: Dictionary) -> Material:
	for key in material_map.keys():
		var needle := str(key)
		if source_name.contains(needle) or mesh_name.contains(needle):
			return _load_material_key(str(material_map[key]))
	return null


func _match_guid_material(material_guids, surface_index: int) -> Material:
	if not material_guids is Array:
		return null
	var guids := material_guids as Array
	if surface_index >= guids.size():
		return null
	var guid := str(guids[surface_index])
	if not MATERIAL_GUID_MAP.has(guid):
		return null
	return _load_material_key(str(MATERIAL_GUID_MAP[guid]))


func _semantic_mesh_material(mesh_instance: MeshInstance3D, surface_index: int, fallback_key: String) -> Material:
	var mesh_name := mesh_instance.name.to_lower()
	var fallback := fallback_key.to_lower()
	if fallback.begins_with("tank"):
		if mesh_name.contains("track") or mesh_name.contains("tread"):
			return _load_material_key("tank_grey")
		if mesh_name.contains("light") or mesh_name.contains("lamp"):
			return _load_material_key("tank_lights")
		if mesh_name.contains("window") or mesh_name.contains("glass"):
			return _load_material_key("building_glass")
		if mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 1:
			if surface_index == 1:
				return _load_material_key("tank_grey")
			if surface_index >= 2:
				return _load_material_key("tank_lights")
		return _load_material_key(fallback_key)
	if mesh_name.contains("glass") or mesh_name.contains("window"):
		return _load_material_key("building_glass")
	if mesh_name.contains("metal"):
		return _load_material_key("building_metal")
	return null


func _load_material_key(key: String) -> Material:
	var path := key
	if MATERIALS.has(key):
		path = str(MATERIALS[key])
	if path.is_empty():
		return null
	var loaded := load(path)
	return loaded as Material if loaded is Material else null


func _play_imported_animation(node: Node, should_play: bool) -> void:
	if not should_play:
		return
	if node is AnimationPlayer:
		var player := node as AnimationPlayer
		var animations := player.get_animation_list()
		if not animations.is_empty():
			player.play(animations[0])
			return
	for child in node.get_children():
		_play_imported_animation(child, should_play)


func _animate_tank(tank: Node3D) -> void:
	var turret := _find_first_node_containing(tank, "Turret") as Node3D
	var target := turret if turret else tank
	var base_y := target.rotation.y
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(target, "rotation:y", base_y + deg_to_rad(7.0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "rotation:y", base_y - deg_to_rad(7.0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _find_first_node_containing(node: Node, needle: String) -> Node:
	if node.name.contains(needle):
		return node
	for child in node.get_children():
		var found := _find_first_node_containing(child, needle)
		if found:
			return found
	return null


func _align_bottom_to_ground(node: Node3D) -> void:
	var bounds := _calculate_bounds(node)
	if bounds.size == Vector3.ZERO:
		return
	node.global_position.y += -bounds.position.y


func _add_static_collision_for(parent: Node3D, visual_node: Node3D) -> void:
	var bounds := _calculate_bounds(visual_node)
	if bounds.size == Vector3.ZERO:
		return
	var body := StaticBody3D.new()
	body.name = visual_node.name + "_Blocker"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	parent.add_child(body, true)
	body.global_position = bounds.get_center()

	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(bounds.size.x, 0.4),
		maxf(bounds.size.y, 0.4),
		maxf(bounds.size.z, 0.4)
	)
	shape_node.shape = shape
	body.add_child(shape_node)


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


func _transform_aabb(transform: Transform3D, box: AABB) -> AABB:
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


func _build_audio_nodes(config: Dictionary) -> void:
	var audio_root := Node3D.new()
	audio_root.name = "TankDemoAudio"
	_root.add_child(audio_root)

	var music_path := str(config.get("music", ""))
	if not music_path.is_empty():
		var music := AudioStreamPlayer3D.new()
		music.name = "ThemeMusicPreview"
		music.stream = load(music_path) as AudioStream
		music.volume_db = -22.0
		music.unit_size = 22.0
		music.autoplay = false
		audio_root.add_child(music)

	for audio_data in [
		{"name": "ShotFiringSFX", "path": AUDIO_ROOT + "SFX/ShotFiring.wav", "position": Vector3(-8, 1.2, 8)},
		{"name": "ShellExplosionSFX", "path": AUDIO_ROOT + "SFX/ShellExplosion.wav", "position": Vector3(8, 1.2, -6)},
		{"name": "TankExplosionSFX", "path": AUDIO_ROOT + "SFX/TankExplosion.wav", "position": Vector3(0, 1.2, 0)},
	]:
		var player := AudioStreamPlayer3D.new()
		player.name = str(audio_data["name"])
		player.stream = load(str(audio_data["path"])) as AudioStream
		player.position = audio_data["position"]
		player.volume_db = -8.0
		player.unit_size = 12.0
		audio_root.add_child(player)
