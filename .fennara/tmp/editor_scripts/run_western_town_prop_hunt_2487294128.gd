@tool
extends RefCounted

const WORLD_LAYER: int = 2
const SHADOW_GROUP: String = "stalker_shadow_caster"
const SHADOW_ZONE_GROUP: String = "stalker_shadow_zone"

var _materials: Dictionary = {}

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		var new_root: Node3D = Node3D.new()
		new_root.name = "WesternTownMapRoot"
		ctx.set_scene_root(new_root)
		root = new_root
		ctx.log("Created WesternTownMapRoot")
	elif root is Node3D:
		root.name = "WesternTownMapRoot"
		ctx.clear_children(root)
		ctx.log("Cleared existing WesternTownMapRoot children")
	else:
		ctx.error("Scene root is not Node3D")
		return

	var root3d: Node3D = root as Node3D
	_build_materials()
	_add_world_environment(ctx, root3d)
	_add_ground(ctx, root3d)
	_add_main_street(ctx, root3d)
	_add_canyon_walls(ctx, root3d)
	_add_buildings(ctx, root3d)
	_add_wagons(ctx, root3d)
	_add_hide_props(ctx, root3d)
	_add_cacti_and_plants(ctx, root3d)
	_add_fences(ctx, root3d)
	_add_gameplay_markers(ctx, root3d)
	_add_preview_camera(ctx, root3d)
	ctx.log("Western town layout: playable floor 92m, dense cover inside LevelLayout 42m radius, 8 storefronts, 2 wagons, 58 hide props, 18 cacti")
	ctx.mark_modified()

func _build_materials() -> void:
	_materials.clear()
	_materials["sand"] = _mat("WarmToySand", Color(0.92, 0.62, 0.31, 1.0), 0.86)
	_materials["street"] = _mat("PackedMainStreetSand", Color(0.78, 0.48, 0.24, 1.0), 0.9)
	_materials["wood"] = _mat("HoneyCedarWood", Color(0.64, 0.32, 0.14, 1.0), 0.74)
	_materials["light_wood"] = _mat("SunlitPineWood", Color(0.92, 0.58, 0.28, 1.0), 0.68)
	_materials["dark_wood"] = _mat("DarkPorchWood", Color(0.36, 0.16, 0.08, 1.0), 0.8)
	_materials["red_wood"] = _mat("PaintedRedWood", Color(0.74, 0.22, 0.12, 1.0), 0.72)
	_materials["cream"] = _mat("CreamPaintedTrim", Color(0.96, 0.74, 0.44, 1.0), 0.62)
	_materials["sign"] = _mat("OldTownSignPaint", Color(0.78, 0.30, 0.13, 1.0), 0.7)
	_materials["white"] = _mat("PaintedSignLetters", Color(1.0, 0.9, 0.68, 1.0), 0.55)
	_materials["cactus"] = _mat("ToyCactusGreen", Color(0.22, 0.58, 0.16, 1.0), 0.7)
	_materials["cactus_light"] = _mat("CactusHighlight", Color(0.48, 0.72, 0.22, 1.0), 0.68)
	_materials["hay"] = _mat("GoldenHay", Color(0.96, 0.68, 0.20, 1.0), 0.92)
	_materials["barrel"] = _mat("BarrelBandWood", Color(0.46, 0.22, 0.10, 1.0), 0.74)
	_materials["metal"] = _mat("SoftToyMetalBand", Color(0.34, 0.30, 0.28, 1.0), 0.55)
	_materials["canvas"] = _mat("CoveredWagonCanvas", Color(0.98, 0.78, 0.52, 1.0), 0.82)
	_materials["rock"] = _mat("LayeredCanyonRock", Color(0.70, 0.28, 0.13, 1.0), 0.9)
	_materials["shadow"] = _mat("FixedWesternShadowCover", Color(0.22, 0.13, 0.08, 1.0), 0.95)

func _mat(name: String, color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.0
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return material

func _add_world_environment(ctx, root: Node3D) -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WesternTownWarmEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.88, 1.0, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.72, 0.43, 1.0)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 3.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.98, 0.68, 0.38, 1.0)
	env.fog_density = 0.01
	env.fog_depth_begin = 55.0
	env.fog_depth_end = 130.0
	world.environment = env
	root.add_child(world)
	ctx.own(world)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "LowWesternSun"
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.72, 0.42, 1.0)
	sun.light_energy = 3.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 96.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	root.add_child(sun)
	ctx.own(sun)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "SoftSkyFillLight"
	fill.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	fill.light_color = Color(0.60, 0.76, 1.0, 1.0)
	fill.light_energy = 0.65
	root.add_child(fill)
	ctx.own(fill)

func _add_ground(ctx, root: Node3D) -> void:
	_add_box(ctx, root, "WesternTownGameplaySupportFloor", Vector3(0.0, -0.08, 0.0), Vector3(92.0, 0.16, 92.0), _materials["sand"], true, [])
	_add_box(ctx, root, "MainStreetPackedSand", Vector3(0.0, 0.015, 0.0), Vector3(24.0, 0.05, 76.0), _materials["street"], false, [])
	_add_box(ctx, root, "SaloonSideDustLeft", Vector3(-25.0, 0.01, 0.0), Vector3(24.0, 0.04, 78.0), _materials["sand"], false, [])
	_add_box(ctx, root, "SaloonSideDustRight", Vector3(25.0, 0.01, 0.0), Vector3(24.0, 0.04, 78.0), _materials["sand"], false, [])

func _add_main_street(ctx, root: Node3D) -> void:
	for i: int in range(12):
		var z: float = -34.0 + float(i) * 6.2
		_add_box(ctx, root, "StreetPebbleCluster%d" % i, Vector3(sin(float(i) * 1.7) * 7.5, 0.08, z), Vector3(0.55 + float(i % 3) * 0.16, 0.12, 0.38), _materials["rock"], false, [])
		_add_box(ctx, root, "StreetWheelRut%dA" % i, Vector3(-5.6, 0.04, z), Vector3(0.22, 0.035, 3.2), _materials["shadow"], false, [])
		_add_box(ctx, root, "StreetWheelRut%dB" % i, Vector3(5.6, 0.04, z), Vector3(0.22, 0.035, 3.2), _materials["shadow"], false, [])

func _add_canyon_walls(ctx, root: Node3D) -> void:
	var wall_specs: Array[Dictionary] = [
		{"name":"NorthMesaWall", "pos":Vector3(0.0, 4.0, -47.0), "size":Vector3(96.0, 8.0, 4.0)},
		{"name":"SouthMesaWall", "pos":Vector3(0.0, 4.0, 47.0), "size":Vector3(96.0, 8.0, 4.0)},
		{"name":"WestCanyonRim", "pos":Vector3(-47.0, 4.0, 0.0), "size":Vector3(4.0, 8.0, 96.0)},
		{"name":"EastCanyonRim", "pos":Vector3(47.0, 4.0, 0.0), "size":Vector3(4.0, 8.0, 96.0)},
	]
	for spec: Dictionary in wall_specs:
		_add_box(ctx, root, str(spec["name"]), spec["pos"] as Vector3, spec["size"] as Vector3, _materials["rock"], true, [SHADOW_GROUP])
	for i: int in range(18):
		var angle: float = TAU * float(i) / 18.0
		var radius: float = 43.0 + float(i % 3)
		var pos: Vector3 = Vector3(cos(angle) * radius, 1.0 + float(i % 4) * 0.28, sin(angle) * radius)
		var size: Vector3 = Vector3(4.0 + float(i % 4), 2.0 + float(i % 3), 2.2 + float((i + 1) % 4))
		var rock: Node3D = _add_box(ctx, root, "RoundedMesaRock%d" % i, pos, size, _materials["rock"], true, [SHADOW_GROUP])
		rock.rotation_degrees.y = float(i * 17)

func _add_buildings(ctx, root: Node3D) -> void:
	var specs: Array[Dictionary] = [
		{"name":"SheriffOffice", "label":"SHERIFF", "x":-22.0, "z":-28.0, "w":9.5, "h":8.0, "d":8.0, "mat":"light_wood"},
		{"name":"DryGoodsStore", "label":"DRY GOODS", "x":-21.5, "z":-10.0, "w":10.0, "h":7.0, "d":8.5, "mat":"wood"},
		{"name":"OldSaloon", "label":"SALOON", "x":-22.5, "z":10.0, "w":11.0, "h":9.0, "d":9.0, "mat":"red_wood"},
		{"name":"MineWreckHotel", "label":"MINE WRECK", "x":-22.0, "z":29.0, "w":10.0, "h":8.5, "d":8.0, "mat":"dark_wood"},
		{"name":"Bank", "label":"BANK", "x":22.0, "z":-29.0, "w":9.0, "h":7.5, "d":8.0, "mat":"cream"},
		{"name":"GeneralStore", "label":"GENERAL", "x":22.0, "z":-10.0, "w":10.5, "h":7.0, "d":8.5, "mat":"wood"},
		{"name":"NewWorldsTheatre", "label":"NEW WORLDS", "x":22.5, "z":9.0, "w":11.5, "h":9.0, "d":9.0, "mat":"light_wood"},
		{"name":"Stable", "label":"STABLE", "x":22.0, "z":29.0, "w":10.0, "h":7.5, "d":9.5, "mat":"red_wood"},
	]
	for spec: Dictionary in specs:
		_add_storefront(ctx, root, spec)

func _add_storefront(ctx, root: Node3D, spec: Dictionary) -> void:
	var name: String = str(spec["name"])
	var x: float = float(spec["x"])
	var z: float = float(spec["z"])
	var side: float = -1.0 if x < 0.0 else 1.0
	var width: float = float(spec["w"])
	var height: float = float(spec["h"])
	var depth: float = float(spec["d"])
	var mat_key: String = str(spec["mat"])
	var group: Node3D = Node3D.new()
	group.name = name
	group.position = Vector3(x, 0.0, z)
	root.add_child(group)
	ctx.own(group)

	_add_box(ctx, group, name + "MainBlock", Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, depth), _materials[mat_key], true, [SHADOW_GROUP])
	_add_box(ctx, group, name + "TallFacade", Vector3(-side * (width * 0.12), height + 1.2, -side * 0.10), Vector3(width * 1.08, 2.4, 0.55), _materials[mat_key], true, [SHADOW_GROUP])
	_add_box(ctx, group, name + "TrimTop", Vector3(-side * (width * 0.12), height + 2.55, -side * 0.10), Vector3(width * 1.18, 0.45, 0.7), _materials["dark_wood"], false, [])
	_add_box(ctx, group, name + "PorchDeck", Vector3(-side * (width * 0.04), 0.22, side * (depth * 0.65)), Vector3(width * 1.15, 0.34, 4.0), _materials["dark_wood"], true, [SHADOW_GROUP])
	_add_box(ctx, group, name + "PorchRoof", Vector3(-side * (width * 0.04), 4.2, side * (depth * 0.7)), Vector3(width * 1.2, 0.38, 4.3), _materials["dark_wood"], true, [SHADOW_GROUP])
	for p: int in range(4):
		var px: float = lerpf(-width * 0.45, width * 0.45, float(p) / 3.0)
		_add_box(ctx, group, name + "PorchPost%d" % p, Vector3(px, 2.2, side * (depth * 0.95)), Vector3(0.32, 4.0, 0.32), _materials["dark_wood"], true, [SHADOW_GROUP])
	for b: int in range(5):
		var plank_z: float = side * (depth * 0.20 + float(b) * 0.72)
		_add_box(ctx, group, name + "PorchPlank%d" % b, Vector3(0.0, 0.45, plank_z), Vector3(width * 1.1, 0.08, 0.12), _materials["light_wood"], false, [])
	_add_box(ctx, group, name + "Door", Vector3(0.0, 1.45, side * (depth * 0.51)), Vector3(1.75, 2.9, 0.18), _materials["dark_wood"], false, [])
	_add_box(ctx, group, name + "WindowLeft", Vector3(-width * 0.3, 2.6, side * (depth * 0.52)), Vector3(1.3, 1.45, 0.16), _materials["shadow"], false, [])
	_add_box(ctx, group, name + "WindowRight", Vector3(width * 0.3, 2.6, side * (depth * 0.52)), Vector3(1.3, 1.45, 0.16), _materials["shadow"], false, [])
	_add_sign(ctx, group, name + "Sign", str(spec["label"]), Vector3(-side * (width * 0.05), height + 1.35, side * (depth * 0.68)), width * 0.64, 1.25, side)
	if height >= 8.0:
		_add_box(ctx, group, name + "SecondFloorBalcony", Vector3(-side * (width * 0.03), 5.35, side * (depth * 0.65)), Vector3(width * 0.95, 0.28, 2.2), _materials["dark_wood"], true, [SHADOW_GROUP])
		for rail: int in range(5):
			var rx: float = lerpf(-width * 0.42, width * 0.42, float(rail) / 4.0)
			_add_box(ctx, group, name + "BalconyRail%d" % rail, Vector3(rx, 6.05, side * (depth * 0.93)), Vector3(0.18, 1.15, 0.18), _materials["dark_wood"], true, [SHADOW_GROUP])
		_add_box(ctx, group, name + "BalconyCrossRail", Vector3(0.0, 6.35, side * (depth * 0.93)), Vector3(width * 0.95, 0.16, 0.16), _materials["dark_wood"], true, [SHADOW_GROUP])

func _add_sign(ctx, parent: Node3D, name: String, label_text: String, pos: Vector3, width: float, height: float, side: float) -> void:
	var sign_root: Node3D = Node3D.new()
	sign_root.name = name
	sign_root.position = pos
	sign_root.rotation_degrees.y = 0.0 if side > 0.0 else 180.0
	parent.add_child(sign_root)
	ctx.own(sign_root)
	_add_box(ctx, sign_root, name + "Board", Vector3.ZERO, Vector3(width, height, 0.24), _materials["sign"], false, [])
	_add_box(ctx, sign_root, name + "TopTrim", Vector3(0.0, height * 0.5 + 0.12, 0.0), Vector3(width + 0.45, 0.16, 0.32), _materials["cream"], false, [])
	_add_box(ctx, sign_root, name + "BottomTrim", Vector3(0.0, -height * 0.5 - 0.12, 0.0), Vector3(width + 0.45, 0.16, 0.32), _materials["cream"], false, [])
	var label: Label3D = Label3D.new()
	label.name = name + "Text"
	label.text = label_text
	label.font_size = 64
	label.pixel_size = 0.013
	label.modulate = Color(1.0, 0.86, 0.60, 1.0)
	label.outline_modulate = Color(0.30, 0.12, 0.04, 1.0)
	label.outline_size = 8
	label.position = Vector3(0.0, -0.05, -0.16)
	sign_root.add_child(label)
	ctx.own(label)

func _add_wagons(ctx, root: Node3D) -> void:
	_add_wagon(ctx, root, "NorthCoveredWagon", Vector3(-4.0, 0.0, -17.0), 18.0)
	_add_wagon(ctx, root, "SouthCoveredWagon", Vector3(6.5, 0.0, 21.0), -22.0)

func _add_wagon(ctx, parent: Node3D, name: String, pos: Vector3, yaw: float) -> void:
	var wagon: Node3D = Node3D.new()
	wagon.name = name
	wagon.position = pos
	wagon.rotation_degrees.y = yaw
	parent.add_child(wagon)
	ctx.own(wagon)
	_add_box(ctx, wagon, name + "Box", Vector3(0.0, 1.05, 0.0), Vector3(3.4, 1.4, 5.2), _materials["wood"], true, [SHADOW_GROUP])
	_add_box(ctx, wagon, name + "CanvasCanopy", Vector3(0.0, 2.35, 0.0), Vector3(3.6, 1.8, 5.0), _materials["canvas"], true, [SHADOW_GROUP])
	for i: int in range(4):
		var wx: float = -2.05 if i < 2 else 2.05
		var wz: float = -1.75 if i % 2 == 0 else 1.75
		_add_wheel(ctx, wagon, name + "Wheel%d" % i, Vector3(wx, 0.78, wz))
	_add_box(ctx, wagon, name + "Tongue", Vector3(0.0, 0.65, -3.75), Vector3(0.28, 0.28, 2.3), _materials["dark_wood"], true, [SHADOW_GROUP])

func _add_wheel(ctx, parent: Node3D, name: String, pos: Vector3) -> void:
	var wheel: MeshInstance3D = MeshInstance3D.new()
	wheel.name = name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.resource_name = name + "Mesh"
	mesh.top_radius = 0.62
	mesh.bottom_radius = 0.62
	mesh.height = 0.28
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.material = _materials["dark_wood"]
	wheel.mesh = mesh
	wheel.position = pos
	wheel.rotation_degrees.z = 90.0
	parent.add_child(wheel)
	ctx.own(wheel)

func _add_hide_props(ctx, root: Node3D) -> void:
	var crate_positions: Array[Vector3] = [
		Vector3(-8.0,0.55,-26.0), Vector3(-2.5,0.55,-24.0), Vector3(8.5,0.55,-25.0), Vector3(12.0,0.55,-18.5),
		Vector3(-12.0,0.55,-14.0), Vector3(-6.0,0.55,-8.5), Vector3(7.0,0.55,-7.5), Vector3(13.5,0.55,-2.0),
		Vector3(-14.0,0.55,2.5), Vector3(-7.5,0.55,7.5), Vector3(3.0,0.55,6.0), Vector3(11.5,0.55,10.0),
		Vector3(-11.5,0.55,17.5), Vector3(-3.0,0.55,20.0), Vector3(9.0,0.55,18.0), Vector3(14.0,0.55,29.0)
	]
	for i: int in range(crate_positions.size()):
		var scale: float = 1.0 + float(i % 4) * 0.16
		var crate: Node3D = _add_box(ctx, root, "HideCrate%d" % i, crate_positions[i], Vector3(1.65 * scale, 1.1 * scale, 1.65 * scale), _materials["wood"], true, [SHADOW_GROUP])
		crate.rotation_degrees.y = float((i * 19) % 90)
		_add_box(ctx, crate, "HideCrate%dCrossA" % i, Vector3(0.0, 0.0, -0.84 * scale), Vector3(1.8 * scale, 0.14, 0.12), _materials["light_wood"], false, [])
		_add_box(ctx, crate, "HideCrate%dCrossB" % i, Vector3(0.0, 0.0, 0.84 * scale), Vector3(1.8 * scale, 0.14, 0.12), _materials["light_wood"], false, [])

	for i: int in range(18):
		var x: float = -16.5 if i % 2 == 0 else 16.5
		var z: float = -34.0 + float(i) * 4.0
		_add_barrel(ctx, root, "PorchBarrel%d" % i, Vector3(x + sin(float(i)) * 1.4, 0.75, z), float(i * 21))
	for i: int in range(12):
		var x: float = lerpf(-13.0, 13.0, float(i % 6) / 5.0)
		var z: float = -31.0 if i < 6 else 31.0
		_add_hay(ctx, root, "HayStack%d" % i, Vector3(x, 0.55, z + cos(float(i)) * 2.0), 1.0 + float(i % 3) * 0.18)
	for i: int in range(12):
		var x: float = -34.0 + float(i % 6) * 13.6
		var z: float = -40.0 if i < 6 else 40.0
		_add_box(ctx, root, "OuterSupplyBox%d" % i, Vector3(x, 0.45, z), Vector3(2.4, 0.9, 1.4), _materials["wood"], true, [SHADOW_GROUP])

func _add_barrel(ctx, parent: Node3D, name: String, pos: Vector3, yaw: float) -> void:
	var barrel: Node3D = Node3D.new()
	barrel.name = name
	barrel.position = pos
	barrel.rotation_degrees.y = yaw
	parent.add_child(barrel)
	ctx.own(barrel)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = name + "Visual"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.resource_name = name + "Mesh"
	mesh.top_radius = 0.58
	mesh.bottom_radius = 0.58
	mesh.height = 1.5
	mesh.radial_segments = 18
	mesh.material = _materials["barrel"]
	body.mesh = mesh
	barrel.add_child(body)
	ctx.own(body)
	_add_box(ctx, barrel, name + "Collision", Vector3.ZERO, Vector3(1.15, 1.55, 1.15), _materials["barrel"], true, [SHADOW_GROUP])
	_add_box(ctx, barrel, name + "BandTop", Vector3(0.0, 0.48, 0.0), Vector3(1.22, 0.12, 1.22), _materials["metal"], false, [])
	_add_box(ctx, barrel, name + "BandBottom", Vector3(0.0, -0.48, 0.0), Vector3(1.22, 0.12, 1.22), _materials["metal"], false, [])

func _add_hay(ctx, parent: Node3D, name: String, pos: Vector3, scale_value: float) -> void:
	var hay: Node3D = _add_box(ctx, parent, name, pos, Vector3(2.4 * scale_value, 1.1 * scale_value, 1.6 * scale_value), _materials["hay"], true, [SHADOW_GROUP])
	hay.rotation_degrees.y = float(name.hash() % 40) - 20.0
	for stripe: int in range(3):
		_add_box(ctx, hay, name + "Band%d" % stripe, Vector3(-0.75 + float(stripe) * 0.75, 0.0, 0.0), Vector3(0.08, 1.18 * scale_value, 1.7 * scale_value), _materials["dark_wood"], false, [])

func _add_cacti_and_plants(ctx, root: Node3D) -> void:
	var positions: Array[Vector3] = [
		Vector3(-33.0,0.0,-33.0), Vector3(-29.0,0.0,-18.0), Vector3(-32.0,0.0,8.0), Vector3(-35.0,0.0,26.0),
		Vector3(34.0,0.0,-34.0), Vector3(31.0,0.0,-16.0), Vector3(34.0,0.0,6.0), Vector3(32.0,0.0,27.0),
		Vector3(-9.0,0.0,-35.0), Vector3(5.0,0.0,-33.0), Vector3(-4.5,0.0,33.0), Vector3(12.0,0.0,34.0),
		Vector3(-13.0,0.0,-2.5), Vector3(13.0,0.0,3.5), Vector3(-1.5,0.0,13.0), Vector3(2.5,0.0,-13.0),
		Vector3(-38.5,0.0,-3.0), Vector3(38.0,0.0,18.0)
	]
	for i: int in range(positions.size()):
		_add_cactus(ctx, root, "ToyCactus%d" % i, positions[i], 1.0 + float(i % 4) * 0.18)
	for i: int in range(34):
		var angle: float = float(i) * 2.399
		var radius: float = 10.0 + float((i * 7) % 27)
		var pos: Vector3 = Vector3(cos(angle) * radius, 0.12, sin(angle) * radius)
		_add_box(ctx, root, "DesertGrassTuft%d" % i, pos, Vector3(0.28, 0.24 + float(i % 3) * 0.08, 0.28), _materials["cactus_light"], false, [])

func _add_cactus(ctx, parent: Node3D, name: String, pos: Vector3, scale_value: float) -> void:
	var cactus: Node3D = Node3D.new()
	cactus.name = name
	cactus.position = pos
	parent.add_child(cactus)
	ctx.own(cactus)
	_add_box(ctx, cactus, name + "Collision", Vector3(0.0, 1.65 * scale_value, 0.0), Vector3(0.9 * scale_value, 3.3 * scale_value, 0.9 * scale_value), _materials["cactus"], true, [SHADOW_GROUP])
	_add_cylinder_mesh(ctx, cactus, name + "Trunk", Vector3(0.0, 1.75 * scale_value, 0.0), 0.34 * scale_value, 3.5 * scale_value, _materials["cactus"], 14, Vector3.ZERO)
	_add_cylinder_mesh(ctx, cactus, name + "LeftArm", Vector3(-0.52 * scale_value, 2.05 * scale_value, 0.0), 0.18 * scale_value, 1.2 * scale_value, _materials["cactus"], 12, Vector3(0.0, 0.0, 90.0))
	_add_cylinder_mesh(ctx, cactus, name + "RightArm", Vector3(0.58 * scale_value, 2.35 * scale_value, 0.0), 0.16 * scale_value, 1.0 * scale_value, _materials["cactus"], 12, Vector3(0.0, 0.0, 90.0))
	_add_sphere_mesh(ctx, cactus, name + "Flower", Vector3(0.0, 3.7 * scale_value, 0.0), 0.16 * scale_value, _materials["hay"])

func _add_fences(ctx, root: Node3D) -> void:
	for row: int in range(2):
		var z: float = -38.0 if row == 0 else 38.0
		for i: int in range(11):
			var x: float = -35.0 + float(i) * 7.0
			_add_box(ctx, root, "FencePost%d_%d" % [row, i], Vector3(x, 0.85, z), Vector3(0.35, 1.7, 0.35), _materials["dark_wood"], true, [SHADOW_GROUP])
			if i < 10:
				_add_box(ctx, root, "FenceRailLow%d_%d" % [row, i], Vector3(x + 3.5, 0.68, z), Vector3(6.7, 0.18, 0.25), _materials["wood"], true, [SHADOW_GROUP])
				_add_box(ctx, root, "FenceRailHigh%d_%d" % [row, i], Vector3(x + 3.5, 1.18, z), Vector3(6.7, 0.18, 0.25), _materials["wood"], true, [SHADOW_GROUP])
	for side_index: int in range(2):
		var x_side: float = -38.0 if side_index == 0 else 38.0
		for i: int in range(9):
			var z_side: float = -28.0 + float(i) * 7.0
			_add_box(ctx, root, "SideFencePost%d_%d" % [side_index, i], Vector3(x_side, 0.85, z_side), Vector3(0.35, 1.7, 0.35), _materials["dark_wood"], true, [SHADOW_GROUP])

func _add_gameplay_markers(ctx, root: Node3D) -> void:
	var zones: Node3D = Node3D.new()
	zones.name = "GameplayReadableZones"
	root.add_child(zones)
	ctx.own(zones)
	for i: int in range(6):
		var angle: float = TAU * float(i) / 6.0
		var zone: Node3D = Node3D.new()
		zone.name = "PropSpawnReference%d" % i
		zone.position = Vector3(cos(angle) * 26.0, 0.12, sin(angle) * 26.0)
		zone.add_to_group(SHADOW_ZONE_GROUP)
		zones.add_child(zone)
		ctx.own(zone)
	for i: int in range(8):
		var marker: MeshInstance3D = MeshInstance3D.new()
		marker.name = "HunterSightlineAuditMarker%d" % i
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.35, 0.04, 0.35)
		mesh.material = _materials["white"]
		marker.mesh = mesh
		marker.position = Vector3(lerpf(-18.0, 18.0, float(i % 4) / 3.0), 0.08, 30.0 if i < 4 else -30.0)
		zones.add_child(marker)
		ctx.own(marker)

func _add_preview_camera(ctx, root: Node3D) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "WesternTownPreviewCamera"
	camera.position = Vector3(0.0, 22.0, 52.0)
	camera.look_at_from_position(camera.position, Vector3(0.0, 2.8, 0.0), Vector3.UP)
	camera.fov = 47.0
	camera.current = true
	root.add_child(camera)
	ctx.own(camera)
	var town_label: Label3D = Label3D.new()
	town_label.name = "WesternTownGameplayLabel"
	town_label.text = "WESTERN WORLD - 24 PLAYER PROP HUNT"
	town_label.font_size = 48
	town_label.pixel_size = 0.018
	town_label.modulate = Color(1.0, 0.84, 0.52, 1.0)
	town_label.outline_modulate = Color(0.23, 0.10, 0.03, 1.0)
	town_label.outline_size = 10
	town_label.position = Vector3(0.0, 6.5, -42.0)
	root.add_child(town_label)
	ctx.own(town_label)

func _add_box(ctx, parent: Node, name: String, pos: Vector3, size: Vector3, material: Material, collide: bool, groups: Array) -> Node3D:
	if collide:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = name
		body.position = pos
		body.collision_layer = WORLD_LAYER
		body.collision_mask = 1
		for group_name: Variant in groups:
			body.add_to_group(str(group_name))
		parent.add_child(body)
		ctx.own(body)
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = name + "Visual"
		var mesh: BoxMesh = BoxMesh.new()
		mesh.resource_name = name + "Mesh"
		mesh.size = size
		mesh.material = material
		visual.mesh = mesh
		body.add_child(visual)
		ctx.own(visual)
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.name = name + "Shape"
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		ctx.own(shape)
		return body
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = name
	mesh_node.position = pos
	var visual_mesh: BoxMesh = BoxMesh.new()
	visual_mesh.resource_name = name + "Mesh"
	visual_mesh.size = size
	visual_mesh.material = material
	mesh_node.mesh = visual_mesh
	parent.add_child(mesh_node)
	ctx.own(mesh_node)
	return mesh_node

func _add_cylinder_mesh(ctx, parent: Node, name: String, pos: Vector3, radius: float, height: float, material: Material, segments: int, rot_deg: Vector3) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.resource_name = name + "Mesh"
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.material = material
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.rotation_degrees = rot_deg
	parent.add_child(mesh_node)
	ctx.own(mesh_node)

func _add_sphere_mesh(ctx, parent: Node, name: String, pos: Vector3, radius: float, material: Material) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.resource_name = name + "Mesh"
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	mesh_node.mesh = mesh
	mesh_node.position = pos
	parent.add_child(mesh_node)
	ctx.own(mesh_node)
