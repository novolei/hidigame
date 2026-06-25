@tool
extends RefCounted

const SCOREBOARD_SCRIPT: String = "res://scripts/hunter_home_scoreboard.gd"
const FONT_PATH: String = "res://assets/fonts/SairaCondensed-Bold.woff2"

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	var decor: Node3D = root.get_node_or_null("HunterHomeDecor") as Node3D
	if decor == null:
		decor = Node3D.new()
		decor.name = "HunterHomeDecor"
		root.add_child(decor)
		ctx.own(decor)
	ctx.clear_children(decor)
	_hide_old_square_visuals(root)
	_reposition_hunter_slots(root)
	_build_arena(ctx, root, decor)
	ctx.log("Rebuilt HunterHomeDecor as bright circular arena with three-sided scoreboard and scrolling ticker")
	ctx.mark_modified()

func _hide_old_square_visuals(root: Node) -> void:
	var paths: Array[String] = [
		"Floor/MeshInstance3D",
		"Gate/MeshInstance3D",
		"WallNorthVisual",
		"WallSouthVisual",
		"WallEastVisual",
		"WallWestVisual",
	]
	for path: String in paths:
		var node: Node3D = root.get_node_or_null(path) as Node3D
		if node != null:
			node.visible = false

func _reposition_hunter_slots(root: Node) -> void:
	var slot_count: int = 16
	var radius: float = 10.2
	for index: int in range(slot_count):
		var slot: Marker3D = root.get_node_or_null("HunterSlot%d" % index) as Marker3D
		if slot == null:
			continue
		var angle: float = -PI * 0.82 + (TAU * float(index) / float(slot_count))
		slot.position = Vector3(sin(angle) * radius, 1.0, cos(angle) * radius)
		slot.rotation_degrees = Vector3(0.0, rad_to_deg(angle) + 180.0, 0.0)

func _build_arena(ctx, root: Node, decor: Node3D) -> void:
	var font: Font = load(FONT_PATH) as Font
	var light_maple: StandardMaterial3D = _mat("arena_light_maple", Color(0.98, 0.84, 0.56, 1.0), 0.0, 0.34, Color(0.0, 0.0, 0.0), 0.0)
	var warm_maple: StandardMaterial3D = _mat("arena_warm_maple", Color(1.0, 0.72, 0.34, 1.0), 0.0, 0.38, Color(0.0, 0.0, 0.0), 0.0)
	var pale_wood: StandardMaterial3D = _mat("arena_pale_wood", Color(1.0, 0.9, 0.67, 1.0), 0.0, 0.31, Color(0.0, 0.0, 0.0), 0.0)
	var white_line: StandardMaterial3D = _mat("arena_white_line", Color(0.98, 0.98, 0.94, 1.0), 0.0, 0.22, Color(0.75, 0.82, 1.0), 0.28)
	var purple: StandardMaterial3D = _mat("arena_modern_purple", Color(0.24, 0.16, 0.62, 1.0), 0.05, 0.28, Color(0.16, 0.08, 0.72), 0.35)
	var yellow: StandardMaterial3D = _mat("arena_sport_yellow", Color(1.0, 0.72, 0.08, 1.0), 0.0, 0.2, Color(1.0, 0.54, 0.05), 0.55)
	var cyan: StandardMaterial3D = _mat("arena_cyan_led", Color(0.1, 0.68, 1.0, 1.0), 0.0, 0.16, Color(0.08, 0.72, 1.0), 1.65)
	var blue: StandardMaterial3D = _mat("arena_scoreboard_blue", Color(0.1, 0.22, 0.88, 1.0), 0.02, 0.17, Color(0.08, 0.28, 1.0), 1.2)
	var screen: StandardMaterial3D = _mat("arena_screen_glass", Color(0.03, 0.045, 0.09, 1.0), 0.12, 0.12, Color(0.03, 0.11, 0.26), 0.35)
	var dark: StandardMaterial3D = _mat("arena_charcoal", Color(0.015, 0.018, 0.024, 1.0), 0.1, 0.5, Color(0.0, 0.0, 0.0), 0.0)
	var rail: StandardMaterial3D = _mat("arena_white_guardrail", Color(0.86, 0.91, 0.94, 1.0), 0.3, 0.22, Color(0.0, 0.0, 0.0), 0.0)
	var seat: StandardMaterial3D = _mat("arena_seat_dark", Color(0.022, 0.026, 0.035, 1.0), 0.04, 0.44, Color(0.0, 0.0, 0.0), 0.0)
	var glass: StandardMaterial3D = _mat("arena_soft_glass", Color(0.58, 0.9, 1.0, 0.38), 0.0, 0.08, Color(0.28, 0.78, 1.0), 0.65)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_add_mesh(ctx, decor, "CircularMapleFloor", _disk_mesh(14.2, 96, 0.02), pale_wood, Vector3.ZERO, Vector3.ZERO)
	_add_mesh(ctx, decor, "CourtYellowOuterRing", _annulus_mesh(12.75, 14.15, 128, 0.055), yellow, Vector3.ZERO, Vector3.ZERO)
	_add_mesh(ctx, decor, "CourtPurpleInnerRing", _annulus_mesh(4.7, 5.0, 96, 0.075), purple, Vector3.ZERO, Vector3.ZERO)
	_add_mesh(ctx, decor, "CourtWhiteCenterRing", _annulus_mesh(2.35, 2.48, 96, 0.09), white_line, Vector3.ZERO, Vector3.ZERO)
	_add_mesh(ctx, decor, "CourtCyanReadyHalo", _annulus_mesh(8.95, 9.15, 128, 0.085), cyan, Vector3.ZERO, Vector3.ZERO)

	for i: int in range(12):
		var z: float = -9.6 + float(i) * 1.75
		var mat: StandardMaterial3D = light_maple if i % 2 == 0 else warm_maple
		_add_box(ctx, decor, "WoodPlank%02d" % i, Vector3(20.5, 0.035, 1.42), Vector3(0.0, 0.085, z), Vector3.ZERO, mat)
	_add_box(ctx, decor, "CourtMidline", Vector3(0.12, 0.06, 23.2), Vector3(0.0, 0.15, 0.0), Vector3.ZERO, white_line)
	_add_box(ctx, decor, "CourtLeftSideline", Vector3(0.16, 0.07, 20.5), Vector3(-10.6, 0.17, 0.0), Vector3.ZERO, yellow)
	_add_box(ctx, decor, "CourtRightSideline", Vector3(0.16, 0.07, 20.5), Vector3(10.6, 0.17, 0.0), Vector3.ZERO, yellow)
	_add_box(ctx, decor, "CourtNearBaseline", Vector3(21.2, 0.07, 0.16), Vector3(0.0, 0.17, 10.35), Vector3.ZERO, yellow)
	_add_box(ctx, decor, "CourtFarBaseline", Vector3(21.2, 0.07, 0.16), Vector3(0.0, 0.17, -10.35), Vector3.ZERO, yellow)
	_add_box(ctx, decor, "LeftPurpleKey", Vector3(4.4, 0.065, 3.4), Vector3(-7.25, 0.18, 0.0), Vector3.ZERO, purple)
	_add_box(ctx, decor, "RightPurpleKey", Vector3(4.4, 0.065, 3.4), Vector3(7.25, 0.18, 0.0), Vector3.ZERO, purple)
	_add_box(ctx, decor, "CenterLogoPlate", Vector3(3.6, 0.08, 1.4), Vector3(0.0, 0.21, 0.0), Vector3.ZERO, yellow)
	var logo_cn: Label3D = _add_label(ctx, decor, "CenterCourtChinese", "猎人之家", null, 96, 0.007, Color(0.24, 0.16, 0.62, 1.0), Vector3(0.0, 0.32, 0.02), Vector3(-90.0, 0.0, 0.0), 8.0)
	logo_cn.no_depth_test = true
	var logo_en: Label3D = _add_label(ctx, decor, "CenterCourtEnglish", "HUNTER'S HOME", font, 40, 0.007, Color(0.06, 0.08, 0.16, 1.0), Vector3(0.0, 0.31, 0.72), Vector3(-90.0, 0.0, 0.0), 7.0)
	logo_en.no_depth_test = true

	_build_circular_barrier(ctx, decor, rail, glass, cyan, seat, yellow)
	_build_spawn_pads(ctx, decor, yellow, cyan, dark)
	_build_scoreboard(ctx, decor, font, screen, blue, yellow, cyan, dark)
	_build_lighting(ctx, decor)
	var camera: Camera3D = root.get_node_or_null("HunterHomePreviewCamera") as Camera3D
	if camera != null:
		camera.position = Vector3(0.0, 13.5, 22.0)
		camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
		camera.fov = 72.0

func _build_circular_barrier(ctx, decor: Node3D, rail: StandardMaterial3D, glass: StandardMaterial3D, cyan: StandardMaterial3D, seat: StandardMaterial3D, yellow: StandardMaterial3D) -> void:
	var segments: int = 48
	var radius: float = 14.25
	var tangent_width: float = (TAU * radius / float(segments)) * 0.88
	for i: int in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		var pos: Vector3 = Vector3(sin(angle) * radius, 1.1, cos(angle) * radius)
		var rot: Vector3 = Vector3(0.0, rad_to_deg(angle), 0.0)
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "ArenaCircularFence%02d" % i
		body.position = pos
		body.rotation_degrees = rot
		decor.add_child(body)
		ctx.own(body)
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(tangent_width, 2.4, 0.55)
		shape_node.shape = shape
		body.add_child(shape_node)
		ctx.own(shape_node)
		_add_box(ctx, body, "GlassPanel", Vector3(tangent_width, 1.8, 0.08), Vector3(0.0, 0.35, 0.0), Vector3.ZERO, glass)
		_add_box(ctx, body, "UpperWhiteRail", Vector3(tangent_width, 0.14, 0.2), Vector3(0.0, 1.38, -0.03), Vector3.ZERO, rail)
		_add_box(ctx, body, "LowerWhiteRail", Vector3(tangent_width, 0.14, 0.22), Vector3(0.0, -0.48, -0.03), Vector3.ZERO, rail)
		if i % 2 == 0:
			_add_box(ctx, body, "CyanRibbon", Vector3(tangent_width * 0.78, 0.07, 0.16), Vector3(0.0, 1.72, -0.08), Vector3.ZERO, cyan)
		if i % 6 == 0:
			_add_box(ctx, body, "YellowPortalAccent", Vector3(0.22, 1.95, 0.24), Vector3(-tangent_width * 0.45, 0.35, -0.14), Vector3.ZERO, yellow)
	for row: int in range(3):
		var seat_radius: float = 15.35 + float(row) * 0.78
		var y: float = 0.74 + float(row) * 0.34
		for j: int in range(44):
			if j % 5 == 0 and row == 0:
				continue
			var angle2: float = TAU * float(j) / 44.0
			var pos2: Vector3 = Vector3(sin(angle2) * seat_radius, y, cos(angle2) * seat_radius)
			var rot2: Vector3 = Vector3(0.0, rad_to_deg(angle2), 0.0)
			_add_box(ctx, decor, "ArenaSeat%d_%02d" % [row, j], Vector3(0.54, 0.22, 0.48), pos2, rot2, seat)
	_add_mesh(ctx, decor, "UpperCyanLightRig", _annulus_mesh(14.6, 14.9, 128, 4.65), cyan, Vector3.ZERO, Vector3.ZERO)
	_add_mesh(ctx, decor, "UpperYellowRibbon", _annulus_mesh(13.55, 13.75, 128, 3.95), yellow, Vector3.ZERO, Vector3.ZERO)

func _build_spawn_pads(ctx, decor: Node3D, yellow: StandardMaterial3D, cyan: StandardMaterial3D, dark: StandardMaterial3D) -> void:
	for i: int in range(16):
		var angle: float = -PI * 0.82 + (TAU * float(i) / 16.0)
		var pos: Vector3 = Vector3(sin(angle) * 10.2, 0.23, cos(angle) * 10.2)
		var rot: Vector3 = Vector3(0.0, rad_to_deg(angle) + 90.0, 0.0)
		var pad_root: Node3D = Node3D.new()
		pad_root.name = "CircularHunterSpawnPad%02d" % i
		pad_root.position = pos
		pad_root.rotation_degrees = rot
		decor.add_child(pad_root)
		ctx.own(pad_root)
		_add_box(ctx, pad_root, "PadDarkBase", Vector3(1.75, 0.08, 0.92), Vector3.ZERO, Vector3.ZERO, dark)
		_add_box(ctx, pad_root, "PadYellowLane", Vector3(1.28, 0.045, 0.1), Vector3(0.0, 0.055, -0.32), Vector3.ZERO, yellow)
		_add_box(ctx, pad_root, "PadCyanReady", Vector3(0.16, 0.055, 0.76), Vector3(-0.62, 0.075, 0.0), Vector3.ZERO, cyan)
		_add_box(ctx, pad_root, "PadCyanReadyR", Vector3(0.16, 0.055, 0.76), Vector3(0.62, 0.075, 0.0), Vector3.ZERO, cyan)

func _build_scoreboard(ctx, decor: Node3D, font: Font, screen: StandardMaterial3D, blue: StandardMaterial3D, yellow: StandardMaterial3D, cyan: StandardMaterial3D, dark: StandardMaterial3D) -> void:
	var scoreboard: Node3D = Node3D.new()
	scoreboard.name = "ArenaScoreboard"
	scoreboard.position = Vector3(0.0, 7.25, 0.0)
	var script: Script = load(SCOREBOARD_SCRIPT) as Script
	if script != null:
		scoreboard.set_script(script)
	decor.add_child(scoreboard)
	ctx.own(scoreboard)
	_add_mesh(ctx, scoreboard, "ScoreboardTopHalo", _annulus_mesh(2.85, 3.15, 96, 1.25), blue, Vector3.ZERO, Vector3.ZERO)
	_add_mesh(ctx, scoreboard, "ScoreboardBottomHalo", _annulus_mesh(2.85, 3.15, 96, -1.28), blue, Vector3.ZERO, Vector3.ZERO)
	_add_mesh(ctx, scoreboard, "ScoreboardCyanCrown", _annulus_mesh(3.15, 3.3, 96, 1.56), cyan, Vector3.ZERO, Vector3.ZERO)
	for i: int in range(3):
		var angle: float = TAU * float(i) / 3.0
		var face: Node3D = Node3D.new()
		face.name = "ScoreboardFace%d" % i
		face.rotation_degrees = Vector3(0.0, rad_to_deg(angle), 0.0)
		scoreboard.add_child(face)
		ctx.own(face)
		_add_box(ctx, face, "MainScreen", Vector3(4.6, 2.35, 0.18), Vector3(0.0, 0.0, -2.78), Vector3.ZERO, screen)
		_add_box(ctx, face, "TopBlueTicker", Vector3(4.75, 0.34, 0.22), Vector3(0.0, 1.36, -2.83), Vector3.ZERO, blue)
		_add_box(ctx, face, "BottomBlueTicker", Vector3(4.75, 0.34, 0.22), Vector3(0.0, -1.36, -2.83), Vector3.ZERO, blue)
		_add_box(ctx, face, "YellowSideAccentL", Vector3(0.14, 2.62, 0.24), Vector3(-2.46, 0.0, -2.84), Vector3.ZERO, yellow)
		_add_box(ctx, face, "YellowSideAccentR", Vector3(0.14, 2.62, 0.24), Vector3(2.46, 0.0, -2.84), Vector3.ZERO, yellow)
		var cn: Label3D = _add_label(ctx, face, "TitleChinese%d" % i, "猎人之家", null, 76, 0.0065, Color(1.0, 0.96, 0.76, 1.0), Vector3(0.0, 0.48, -2.96), Vector3.ZERO, 6.0)
		cn.no_depth_test = true
		var en: Label3D = _add_label(ctx, face, "TitleEnglish%d" % i, "HUNTER'S HOME", font, 44, 0.0068, Color(0.55, 0.88, 1.0, 1.0), Vector3(0.0, 0.02, -2.97), Vector3.ZERO, 4.0)
		en.no_depth_test = true
		var status: Label3D = _add_label(ctx, face, "StatusText%d" % i, "HUNTERS  READY   00 : 03   PROPS  HIDING", font, 24, 0.0068, Color(1.0, 0.74, 0.2, 1.0), Vector3(0.0, -0.42, -2.98), Vector3.ZERO, 3.0)
		status.no_depth_test = true
		var ticker: Label3D = _add_label(ctx, face, "TickerText%d" % i, "HUNTER HOME LIVE  |  猎人之家现场  |  READY ROOM OPEN", font, 24, 0.0056, Color(0.94, 0.98, 1.0, 1.0), Vector3(0.0, -1.36, -3.02), Vector3.ZERO, 2.0)
		ticker.no_depth_test = true
		var top: Label3D = _add_label(ctx, face, "ArenaTopText%d" % i, "SUPER HIDE & SEEK ARENA", font, 22, 0.0054, Color(0.96, 0.98, 1.0, 1.0), Vector3(0.0, 1.36, -3.02), Vector3.ZERO, 2.0)
		top.no_depth_test = true
	_add_box(ctx, scoreboard, "ScoreboardSuspensionStem", Vector3(0.34, 2.2, 0.34), Vector3(0.0, 2.65, 0.0), Vector3.ZERO, dark)
	for j: int in range(6):
		var cable_angle: float = TAU * float(j) / 6.0
		var cable_pos: Vector3 = Vector3(sin(cable_angle) * 2.8, 2.6, cos(cable_angle) * 2.8)
		_add_box(ctx, scoreboard, "ScoreboardCable%d" % j, Vector3(0.08, 2.0, 0.08), cable_pos, Vector3.ZERO, dark)

func _build_lighting(ctx, decor: Node3D) -> void:
	for i: int in range(16):
		var angle: float = TAU * float(i) / 16.0
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "ArenaBowlLight%02d" % i
		light.position = Vector3(sin(angle) * 10.8, 5.2, cos(angle) * 10.8)
		light.light_energy = 0.62
		light.light_color = Color(0.86, 0.94, 1.0, 1.0)
		light.omni_range = 8.0
		decor.add_child(light)
		ctx.own(light)
	var center_light: OmniLight3D = OmniLight3D.new()
	center_light.name = "ArenaCenterShowLight"
	center_light.position = Vector3(0.0, 6.2, 0.0)
	center_light.light_energy = 1.0
	center_light.light_color = Color(1.0, 0.9, 0.68, 1.0)
	center_light.omni_range = 18.0
	decor.add_child(center_light)
	ctx.own(center_light)

func _mat(name: String, albedo: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = roughness
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _add_box(ctx, parent: Node, name: String, size: Vector3, position: Vector3, rotation_degrees: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = position
	node.rotation_degrees = rotation_degrees
	node.set_surface_override_material(0, material)
	parent.add_child(node)
	ctx.own(node)
	return node

func _add_mesh(ctx, parent: Node, name: String, mesh: Mesh, material: Material, position: Vector3, rotation_degrees: Vector3) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	node.position = position
	node.rotation_degrees = rotation_degrees
	node.set_surface_override_material(0, material)
	parent.add_child(node)
	ctx.own(node)
	return node

func _add_label(ctx, parent: Node, name: String, text: String, font: Font, font_size: int, pixel_size: float, color: Color, position: Vector3, rotation_degrees: Vector3, outline_size: float) -> Label3D:
	var label: Label3D = Label3D.new()
	label.name = name
	label.text = text
	label.font = font
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = int(outline_size)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.82)
	label.double_sided = true
	label.shaded = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = position
	label.rotation_degrees = rotation_degrees
	label.render_priority = 20
	label.outline_render_priority = 19
	parent.add_child(label)
	ctx.own(label)
	return label

func _disk_mesh(radius: float, segments: int, y: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	vertices.append(Vector3(0.0, y, 0.0))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))
	for i: int in range(segments + 1):
		var angle: float = TAU * float(i) / float(segments)
		vertices.append(Vector3(sin(angle) * radius, y, cos(angle) * radius))
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.5 + sin(angle) * 0.5, 0.5 + cos(angle) * 0.5))
	for i2: int in range(1, segments + 1):
		indices.append(0)
		indices.append(i2)
		indices.append(i2 + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _annulus_mesh(inner_radius: float, outer_radius: float, segments: int, y: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in range(segments + 1):
		var angle: float = TAU * float(i) / float(segments)
		vertices.append(Vector3(sin(angle) * inner_radius, y, cos(angle) * inner_radius))
		vertices.append(Vector3(sin(angle) * outer_radius, y, cos(angle) * outer_radius))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, float(i) / float(segments)))
		uvs.append(Vector2(1.0, float(i) / float(segments)))
	for i2: int in range(segments):
		var a: int = i2 * 2
		var b: int = a + 1
		var c: int = a + 2
		var d: int = a + 3
		indices.append(a)
		indices.append(b)
		indices.append(c)
		indices.append(c)
		indices.append(b)
		indices.append(d)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
