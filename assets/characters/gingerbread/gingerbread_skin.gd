@tool
extends Node3D

const BODY_THICKNESS := 0.30
const FRONT_Z := BODY_THICKNESS * 0.5 + 0.012
const DETAIL_Z := BODY_THICKNESS * 0.5 + 0.135
const COOKIE_COLOR := Color(0.86, 0.42, 0.12)
const COOKIE_DARK := Color(0.34, 0.13, 0.045)
const COOKIE_LIGHT := Color(1.0, 0.62, 0.20)
const ICING_COLOR := Color(1.0, 0.91, 0.66)
const EYE_BROWN := Color(0.14, 0.045, 0.018)
const SCALE_X := 0.70
const SCALE_Y := 0.60
const Y_OFFSET := 1.38

var walk_run_blending := 0.0
var _visual_root: Node3D
var _body_root: Node3D
var _action := "idle"
var _time := 0.0
var _body_outline := PackedVector2Array()
var _cookie_material: StandardMaterial3D
var _icing_material: StandardMaterial3D
var _brown_material: StandardMaterial3D
var _white_material: StandardMaterial3D


func _ready() -> void:
	_build_skin()
	idle()


func _process(delta: float) -> void:
	_time += delta
	if not _visual_root:
		return

	var bob := 0.0
	var lean := 0.0
	var squash := Vector3.ONE
	match _action:
		"move":
			var speed := lerpf(5.0, 8.5, clampf(walk_run_blending, 0.0, 1.0))
			bob = sin(_time * speed) * 0.035
			lean = sin(_time * speed * 0.5) * 0.07
			squash = Vector3(1.0 + absf(bob) * 0.45, 1.0 - absf(bob) * 0.32, 1.0)
		"jump":
			bob = 0.05
			lean = -0.08
			squash = Vector3(0.95, 1.06, 1.0)
		"fall":
			bob = -0.025
			lean = 0.08
			squash = Vector3(1.04, 0.96, 1.0)
		_:
			bob = sin(_time * 1.8) * 0.012
			lean = sin(_time * 1.2) * 0.018

	_visual_root.position = Vector3(0.0, bob, 0.0)
	_visual_root.rotation = Vector3(0.0, 0.0, lean)
	_visual_root.scale = squash


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)


func idle() -> void:
	_action = "idle"


func move() -> void:
	_action = "move"


func run() -> void:
	_action = "move"
	walk_run_blending = 1.0


func jump() -> void:
	_action = "jump"


func fall() -> void:
	_action = "fall"


func land() -> void:
	_action = "idle"


func crouch() -> void:
	_action = "idle"


func prone() -> void:
	_action = "idle"


func prone_crawl() -> void:
	_action = "move"


func hurt() -> void:
	if not _visual_root:
		return
	var tween := create_tween()
	tween.tween_property(_visual_root, "scale", Vector3(1.10, 0.86, 1.0), 0.07)
	tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.16)


func _build_skin() -> void:
	if _visual_root:
		return

	_visual_root = Node3D.new()
	_visual_root.name = "GingerbreadVisual"
	add_child(_visual_root)

	_body_root = Node3D.new()
	_body_root.name = "CookieSlab"
	_visual_root.add_child(_body_root)

	_cookie_material = _make_cookie_material()
	_icing_material = _make_material("Icing", ICING_COLOR, 0.52)
	_brown_material = _make_material("ChocolateBrown", EYE_BROWN, 0.58)
	_white_material = _make_material("WarmWhite", Color.WHITE, 0.36)

	_body_outline = _make_body_outline()
	_add_body_mesh()
	_add_face()
	_add_icing()
	_add_cookie_surface_detail()


func _make_body_outline() -> PackedVector2Array:
	var right_side: Array[Vector2] = []
	_append_arc(right_side, Vector2(0.0, 1.49), Vector2(0.69, 0.65), 92.0, -63.0, 30)
	right_side.append(Vector2(0.36, 0.90))
	right_side.append(Vector2(0.50, 0.83))
	right_side.append(Vector2(0.65, 0.66))
	right_side.append(Vector2(0.78, 0.42))
	right_side.append(Vector2(0.90, 0.11))
	right_side.append(Vector2(0.87, -0.08))
	right_side.append(Vector2(0.74, -0.23))
	right_side.append(Vector2(0.58, -0.24))
	right_side.append(Vector2(0.45, -0.06))
	right_side.append(Vector2(0.39, -0.34))
	right_side.append(Vector2(0.39, -0.88))
	right_side.append(Vector2(0.34, -1.18))
	right_side.append(Vector2(0.22, -1.36))
	right_side.append(Vector2(0.08, -1.41))
	right_side.append(Vector2(0.02, -1.29))
	right_side.append(Vector2(0.00, -0.66))

	var points := PackedVector2Array()
	for point in right_side:
		points.append(_scale_outline_point(point))
	for index in range(right_side.size() - 2, 0, -1):
		var point := right_side[index]
		points.append(_scale_outline_point(Vector2(-point.x, point.y)))
	return _smooth_closed_outline(points, 3)


func _scale_outline_point(point: Vector2) -> Vector2:
	return Vector2(point.x * SCALE_X, (point.y + Y_OFFSET) * SCALE_Y)


func _smooth_closed_outline(outline: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var result := outline
	for _iteration in iterations:
		var smoothed := PackedVector2Array()
		for index in result.size():
			var current := result[index]
			var next := result[(index + 1) % result.size()]
			smoothed.append(current.lerp(next, 0.25))
			smoothed.append(current.lerp(next, 0.75))
		result = smoothed
	return result


func _append_arc(points: Array[Vector2], center: Vector2, radius: Vector2, start_degrees: float, end_degrees: float, steps: int) -> void:
	for index in range(steps + 1):
		var t := float(index) / float(steps)
		var angle := deg_to_rad(lerpf(start_degrees, end_degrees, t))
		points.append(Vector2(center.x + cos(angle) * radius.x, center.y + sin(angle) * radius.y))


func _add_body_mesh() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ExtrudedCookieBody"
	mesh_instance.mesh = _build_extruded_mesh(_body_outline, BODY_THICKNESS)
	mesh_instance.material_override = _cookie_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_body_root.add_child(mesh_instance)


func _build_extruded_mesh(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var bounds := _outline_bounds(outline)
	var half_thickness := thickness * 0.5
	var dome_center := Vector2(0.0, 0.82)
	var dome_height := 0.105
	var ring_scales := PackedFloat32Array([0.16, 0.42, 0.68, 0.86, 1.0])
	var center_vertex := vertices.size()

	vertices.append(Vector3(dome_center.x, dome_center.y, half_thickness + dome_height))
	normals.append(Vector3(0.0, 0.0, 1.0))
	uvs.append(_outline_uv(dome_center, bounds))

	for scale_value in ring_scales:
		var dome := dome_height * pow(1.0 - scale_value, 0.68)
		for point in outline:
			var ring_point := dome_center + (point - dome_center) * scale_value
			vertices.append(Vector3(ring_point.x, ring_point.y, half_thickness + dome))
			var normal_hint := Vector3((ring_point.x - dome_center.x) * -0.16, (ring_point.y - dome_center.y) * -0.16, 1.0)
			normals.append(normal_hint.normalized())
			uvs.append(_outline_uv(ring_point, bounds))

	var first_ring_start := center_vertex + 1
	for index in outline.size():
		var next_index := (index + 1) % outline.size()
		indices.append_array(PackedInt32Array([center_vertex, first_ring_start + index, first_ring_start + next_index]))

	for ring_index in range(ring_scales.size() - 1):
		var inner_start := center_vertex + 1 + ring_index * outline.size()
		var outer_start := inner_start + outline.size()
		for index in outline.size():
			var next_index := (index + 1) % outline.size()
			indices.append_array(PackedInt32Array([
				inner_start + index,
				outer_start + index,
				outer_start + next_index,
				inner_start + index,
				outer_start + next_index,
				inner_start + next_index,
			]))

	var back_start := vertices.size()
	for point in outline:
		vertices.append(Vector3(point.x, point.y, -half_thickness))
		normals.append(Vector3.BACK)
		uvs.append(_outline_uv(point, bounds))

	var triangles := Geometry2D.triangulate_polygon(outline)
	for index in range(0, triangles.size(), 3):
		indices.append(triangles[index + 2] + back_start)
		indices.append(triangles[index + 1] + back_start)
		indices.append(triangles[index] + back_start)

	var front_outer_start := center_vertex + 1 + (ring_scales.size() - 1) * outline.size()
	for index in outline.size():
		var next_index := (index + 1) % outline.size()
		var a := outline[index]
		var b := outline[next_index]
		var edge := b - a
		var normal_2d := Vector2(-edge.y, edge.x).normalized()
		var normal := Vector3(normal_2d.x, normal_2d.y, 0.0)
		var base := vertices.size()
		vertices.append(Vector3(a.x, a.y, half_thickness))
		vertices.append(Vector3(b.x, b.y, half_thickness))
		vertices.append(Vector3(b.x, b.y, -half_thickness))
		vertices.append(Vector3(a.x, a.y, -half_thickness))
		for _i in 4:
			normals.append(normal)
		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(1.0, 0.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(0.0, 1.0))
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

		indices.append_array(PackedInt32Array([
			front_outer_start + index,
			front_outer_start + next_index,
			base + 1,
			front_outer_start + index,
			base + 1,
			base,
		]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _outline_bounds(outline: PackedVector2Array) -> Rect2:
	var min_point := outline[0]
	var max_point := outline[0]
	for point in outline:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func _outline_uv(point: Vector2, bounds: Rect2) -> Vector2:
	return Vector2(
		inverse_lerp(bounds.position.x, bounds.position.x + bounds.size.x, point.x),
		inverse_lerp(bounds.position.y, bounds.position.y + bounds.size.y, point.y)
	)


func _add_face() -> void:
	_add_disc("LeftEyeWhite", Vector2(-0.245, 1.49), 0.160, DETAIL_Z - 0.018, _white_material)
	_add_disc("RightEyeWhite", Vector2(0.245, 1.49), 0.160, DETAIL_Z - 0.018, _white_material)
	_add_disc("LeftEyeBrown", Vector2(-0.245, 1.49), 0.118, DETAIL_Z - 0.002, _brown_material)
	_add_disc("RightEyeBrown", Vector2(0.245, 1.49), 0.118, DETAIL_Z - 0.002, _brown_material)
	_add_disc("LeftEyeHighlightLarge", Vector2(-0.292, 1.565), 0.043, DETAIL_Z + 0.012, _white_material)
	_add_disc("RightEyeHighlightLarge", Vector2(0.198, 1.565), 0.043, DETAIL_Z + 0.012, _white_material)
	_add_disc("LeftEyeHighlightSmall", Vector2(-0.178, 1.548), 0.014, DETAIL_Z + 0.014, _white_material)
	_add_disc("RightEyeHighlightSmall", Vector2(0.312, 1.548), 0.014, DETAIL_Z + 0.014, _white_material)

	_add_tube_path("LeftBrow", [Vector2(-0.39, 1.76), Vector2(-0.29, 1.80)], DETAIL_Z + 0.010, 0.024, _brown_material)
	_add_tube_path("RightBrow", [Vector2(0.29, 1.80), Vector2(0.39, 1.76)], DETAIL_Z + 0.010, 0.024, _brown_material)
	_add_tube_path("Smile", [Vector2(-0.105, 1.325), Vector2(-0.070, 1.275), Vector2(0.0, 1.255), Vector2(0.070, 1.275), Vector2(0.105, 1.325)], DETAIL_Z + 0.006, 0.018, _brown_material)


func _add_icing() -> void:
	_add_tube_path("LeftArmIcing", [Vector2(-0.59, 0.82), Vector2(-0.65, 0.72), Vector2(-0.58, 0.62), Vector2(-0.64, 0.52), Vector2(-0.55, 0.43)], DETAIL_Z + 0.010, 0.035, _icing_material)
	_add_tube_path("RightArmIcing", [Vector2(0.55, 0.43), Vector2(0.64, 0.52), Vector2(0.58, 0.62), Vector2(0.65, 0.72), Vector2(0.59, 0.82)], DETAIL_Z + 0.010, 0.035, _icing_material)
	_add_tube_path("LowerIcingLeft", [Vector2(-0.50, 0.35), Vector2(-0.42, 0.43), Vector2(-0.32, 0.35), Vector2(-0.22, 0.43), Vector2(-0.11, 0.35), Vector2(-0.02, 0.42)], DETAIL_Z + 0.014, 0.038, _icing_material)
	_add_tube_path("LowerIcingRight", [Vector2(0.02, 0.42), Vector2(0.11, 0.35), Vector2(0.22, 0.43), Vector2(0.32, 0.35), Vector2(0.42, 0.43), Vector2(0.50, 0.35)], DETAIL_Z + 0.014, 0.038, _icing_material)
	_add_disc("LeftSideIcingDot", Vector2(-0.68, 0.65), 0.042, DETAIL_Z + 0.018, _icing_material)
	_add_disc("RightSideIcingDot", Vector2(0.68, 0.65), 0.042, DETAIL_Z + 0.018, _icing_material)


func _add_cookie_surface_detail() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21744
	var pore_material := _make_material("ToastedPores", COOKIE_DARK.lightened(0.10), 0.95)
	var crumb_material := _make_material("LightCrumbs", COOKIE_LIGHT.lightened(0.08), 0.90)
	var bounds := _outline_bounds(_body_outline)

	for index in 110:
		var point := _random_point_in_body(rng, bounds)
		if point.y > 1.42 and absf(point.x) < 0.42:
			if rng.randf() < 0.55:
				continue
		var radius := rng.randf_range(0.0035, 0.011)
		var material := crumb_material if rng.randf() < 0.30 else pore_material
		_add_surface_speck("CookieSpeck%03d" % index, point, radius, DETAIL_Z - 0.050 + rng.randf_range(0.001, 0.008), material, rng.randf_range(0.55, 1.25))

	for index in 14:
		var point := _random_point_in_body(rng, bounds)
		if point.y < 0.24 or point.y > 1.82:
			continue
		var length := rng.randf_range(0.045, 0.095)
		var angle := rng.randf_range(-0.9, 0.9)
		var offset := Vector2(cos(angle), sin(angle)) * length
		if not _point_in_polygon(point + offset, _body_outline):
			continue
		_add_tube_path("HairlineCrack%02d" % index, [point, point + offset * 0.45, point + offset], DETAIL_Z - 0.042, rng.randf_range(0.0025, 0.0045), pore_material)


func _random_point_in_body(rng: RandomNumberGenerator, bounds: Rect2) -> Vector2:
	for _attempt in 80:
		var point := Vector2(
			rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		if _point_in_polygon(point, _body_outline):
			return point
	return bounds.get_center()


func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous_index := polygon.size() - 1
	for index in polygon.size():
		var current := polygon[index]
		var previous := polygon[previous_index]
		if ((current.y > point.y) != (previous.y > point.y)):
			var crossing_x := (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x
			if point.x < crossing_x:
				inside = not inside
		previous_index = index
	return inside


func _add_surface_speck(node_name: String, point: Vector2, radius: float, z: float, material: Material, oval_scale: float) -> void:
	var speck := MeshInstance3D.new()
	speck.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	speck.mesh = mesh
	speck.material_override = material
	speck.position = Vector3(point.x, point.y, z)
	speck.rotation.z = float(hash(node_name) % 360) * TAU / 360.0
	speck.scale = Vector3(radius * oval_scale, radius, radius * 0.24)
	_body_root.add_child(speck)


func _add_disc(node_name: String, point: Vector2, radius: float, z: float, material: Material) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.018
	mesh.radial_segments = 36
	disc.mesh = mesh
	disc.material_override = material
	disc.position = Vector3(point.x, point.y, z)
	disc.rotation.x = PI * 0.5
	_body_root.add_child(disc)
	return disc


func _add_tube_path(node_name: String, points: Array[Vector2], z: float, radius: float, material: Material) -> void:
	var holder := Node3D.new()
	holder.name = node_name
	_body_root.add_child(holder)
	for index in range(points.size() - 1):
		_add_tube_segment(holder, points[index], points[index + 1], z, radius, material)
	for point in points:
		_add_tube_cap(holder, point, z, radius, material)


func _add_tube_segment(parent: Node3D, from_point: Vector2, to_point: Vector2, z: float, radius: float, material: Material) -> void:
	var direction := Vector3(to_point.x - from_point.x, to_point.y - from_point.y, 0.0)
	var length := direction.length()
	if length <= 0.001:
		return

	var segment := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 14
	segment.mesh = mesh
	segment.material_override = material
	segment.position = Vector3((from_point.x + to_point.x) * 0.5, (from_point.y + to_point.y) * 0.5, z)
	segment.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	parent.add_child(segment)


func _add_tube_cap(parent: Node3D, point: Vector2, z: float, radius: float, material: Material) -> void:
	var cap := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 6
	cap.mesh = mesh
	cap.material_override = material
	cap.position = Vector3(point.x, point.y, z)
	parent.add_child(cap)


func _make_cookie_material() -> StandardMaterial3D:
	var material := _make_material("BakedCookie", Color.WHITE, 0.94)
	material.albedo_texture = _make_cookie_texture()
	return material


func _make_cookie_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9162
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var warm_band := sin(float(x) * 0.055) * 0.020 + cos(float(y) * 0.045) * 0.016
			var noise := rng.randf_range(-0.045, 0.050)
			var color := COOKIE_COLOR.lerp(COOKIE_LIGHT, clampf(0.34 + warm_band + noise, 0.0, 1.0))
			if rng.randf() < 0.018:
				color = color.darkened(rng.randf_range(0.12, 0.28))
			elif rng.randf() < 0.025:
				color = color.lightened(rng.randf_range(0.06, 0.16))
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _make_material(material_name: String, color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
