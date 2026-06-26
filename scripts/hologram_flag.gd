extends Node3D
class_name HologramFlag

const CharacterSkinCatalogScript := preload("res://scripts/character_skin_catalog.gd")
const PartyMonsterAccessoryCatalogScript := preload("res://scripts/party_monster_accessory_catalog.gd")
const HOLOGRAM_SHADER := preload("res://shaders/hologram_avatar.gdshader")
const HOLOGRAM_OUTLINE_SHADER := preload("res://shaders/hologram_avatar_outline.gdshader")

const DEFAULT_PLAYER_HEIGHT := 2.0
const FLAG_HEIGHT_RATIO := 0.3
const AVATAR_VISUAL_HEIGHT_MULTIPLIER := 2.55
const AVATAR_BASE_CLEARANCE_RATIO := 0.018
const MIN_AVATAR_BASE_CLEARANCE := 0.012
const MIN_AVATAR_HEIGHT := 0.35
const MAX_AVATAR_HEIGHT := 1.2
const BASE_RADIUS_MIN := 0.22
const PERFORMANCE_ACTIONS := ["dance", "victory"]
const DEFAULT_ACTION_SECONDS := 3.2
const DEFAULT_HOLOGRAM_BODY_COLOR := Color(1.0, 0.28, 0.88, 1.0)
const DEFAULT_HOLOGRAM_ACCENT_COLOR := Color(0.66, 0.18, 1.0, 1.0)
const DEFAULT_HOLOGRAM_GLOW_COLOR := Color(0.22, 0.06, 1.0, 1.0)
const DEFAULT_HOLOGRAM_SOLID_FILL_COLOR := Color(0.16, 0.05, 0.82, 1.0)
const SWEEP_HIGHLIGHT_COLOR_A := Color(0.78, 0.96, 1.0, 1.0)
const SWEEP_HIGHLIGHT_COLOR_B := Color(0.22, 0.82, 1.0, 1.0)
const SWEEP_OUTLINE_HIGHLIGHT_COLOR := Color(0.72, 0.94, 1.0, 1.0)
const GENERIC_SURFACE_TINT := Color(1.0, 0.98, 0.94, 1.0)

@export var auto_build := true
@export var owner_peer_id := 0
@export var character_model_id := CharacterSkinCatalogScript.DEFAULT_ID
@export var party_monster_accessories: Dictionary = {}
@export var skin_color := 0
@export var player_height := DEFAULT_PLAYER_HEIGHT

var _avatar_root: Node3D = null
var _projection_root: Node3D = null
var _animated_rings: Array[MeshInstance3D] = []
var _beam_materials: Array[StandardMaterial3D] = []
var _hologram_materials: Array[ShaderMaterial] = []
var _hologram_outline_materials: Array[ShaderMaterial] = []
var _last_hologram_palette: Dictionary = {}
var _action_timer := 0.0
var _next_action_index := 0
var _current_action := ""
var _target_avatar_height := DEFAULT_PLAYER_HEIGHT * FLAG_HEIGHT_RATIO
var _pulse_time := 0.0


func _ready() -> void:
	if auto_build:
		rebuild()


func configure(state: Dictionary) -> void:
	owner_peer_id = int(state.get("owner_peer_id", owner_peer_id))
	character_model_id = CharacterSkinCatalogScript.normalize(str(state.get("character_model_id", character_model_id)))
	party_monster_accessories = (state.get("party_monster_accessories", {}) as Dictionary).duplicate(true)
	skin_color = clampi(int(state.get("skin_color", skin_color)), 0, 3)
	player_height = clampf(float(state.get("player_height", player_height)), 0.8, 4.0)
	if state.has("transform") and state.get("transform") is Transform3D:
		global_transform = state.get("transform") as Transform3D
	if is_inside_tree():
		rebuild()


func rebuild() -> void:
	_clear_generated_children()
	_target_avatar_height = clampf(player_height * FLAG_HEIGHT_RATIO, MIN_AVATAR_HEIGHT, MAX_AVATAR_HEIGHT)
	_create_base_and_projection()
	_create_avatar()
	_play_next_performance_action()


func _process(delta: float) -> void:
	_pulse_time += delta
	_process_projector_pulse(delta)
	_action_timer -= delta
	if _action_timer <= 0.0:
		_play_next_performance_action()


func _clear_generated_children() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_avatar_root = null
	_projection_root = null
	_animated_rings.clear()
	_beam_materials.clear()
	_hologram_materials.clear()
	_hologram_outline_materials.clear()
	_last_hologram_palette.clear()
	_action_timer = 0.0
	_current_action = ""


func _create_base_and_projection() -> void:
	_projection_root = Node3D.new()
	_projection_root.name = "ProjectionRig"
	add_child(_projection_root)

	var base_radius: float = maxf(BASE_RADIUS_MIN, _target_avatar_height * 0.42)
	var base_height: float = maxf(0.055, _target_avatar_height * 0.09)
	var base_material: StandardMaterial3D = _make_marble_base_material()
	var base: MeshInstance3D = _make_cylinder_mesh("ProjectorBase", base_radius, base_radius, base_height, 96, true, true, base_material)
	base.position.y = base_height * 0.5
	_projection_root.add_child(base)

	var marble_rim: MeshInstance3D = _make_torus_mesh("ProjectorMarbleRim", base_radius * 0.88, base_radius * 1.02, 96, 12, base_material)
	marble_rim.position.y = base_height + 0.006
	_projection_root.add_child(marble_rim)

	var glow_material: StandardMaterial3D = _make_standard_material(Color(1.0, 0.22, 0.86, 0.5), Color(1.0, 0.28, 0.9, 1.0), 4.9, 0.5, true)
	var glow_disc: MeshInstance3D = _make_cylinder_mesh("ProjectorGlowDisc", base_radius * 0.76, base_radius * 0.54, 0.018, 72, true, true, glow_material)
	glow_disc.position.y = base_height + 0.012
	_projection_root.add_child(glow_disc)
	_beam_materials.append(glow_material)

	var inner_shadow_material: StandardMaterial3D = _make_standard_material(Color(0.005, 0.018, 0.026, 0.92), Color(0.0, 0.12, 0.16, 1.0), 0.12, 0.92, true)
	var inner_shadow: MeshInstance3D = _make_cylinder_mesh("ProjectorDarkCenter", base_radius * 0.46, base_radius * 0.42, 0.012, 64, true, true, inner_shadow_material)
	inner_shadow.position.y = base_height + 0.024
	_projection_root.add_child(inner_shadow)

	for index in range(3):
		var ring_color: Color = [Color(1.0, 0.42, 0.92, 0.24), Color(0.72, 0.18, 1.0, 0.25), Color(1.0, 0.82, 0.98, 0.22)][index]
		var ring_material: StandardMaterial3D = _make_standard_material(ring_color, Color(ring_color.r, ring_color.g, ring_color.b, 1.0), 3.05, ring_color.a, true)
		var ring_radius: float = base_radius * (0.68 + float(index) * 0.18)
		var ring_thickness: float = maxf(0.006, base_radius * 0.018)
		var ring: MeshInstance3D = _make_torus_mesh("ScanRing%02d" % index, ring_radius - ring_thickness, ring_radius + ring_thickness, 96, 8, ring_material)
		ring.position.y = base_height + 0.03 + float(index) * _target_avatar_height * 0.28
		_projection_root.add_child(ring)
		_animated_rings.append(ring)
		_beam_materials.append(ring_material)


func _make_cylinder_mesh(node_name: String, bottom_radius: float, top_radius: float, height: float, segments: int, cap_top: bool, cap_bottom: bool, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 2
	mesh.cap_top = cap_top
	mesh.cap_bottom = cap_bottom
	mesh.material = material
	mesh_instance.mesh = mesh
	return mesh_instance


func _make_torus_mesh(node_name: String, inner_radius: float, outer_radius: float, rings: int, ring_segments: int, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(inner_radius, 0.001)
	mesh.outer_radius = maxf(outer_radius, mesh.inner_radius + 0.001)
	mesh.rings = rings
	mesh.ring_segments = ring_segments
	mesh.material = material
	mesh_instance.mesh = mesh
	return mesh_instance


func _make_marble_base_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_standard_material(Color(0.82, 0.86, 0.86, 1.0), Color(0.015, 0.085, 0.095, 1.0), 0.12, 1.0, false)
	material.metallic = 0.0
	material.metallic_specular = 0.42
	material.roughness = 0.32
	return material


func _make_standard_material(albedo: Color, emission: Color, emission_energy: float, alpha: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_local_to_scene = true
	material.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.38
	material.metallic = 0.0
	material.disable_receive_shadows = true
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material



func _make_hologram_outline_material(scan_color: Color, scan_edge_color: Color, scan_glow_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_local_to_scene = true
	material.shader = HOLOGRAM_OUTLINE_SHADER
	material.render_priority = 9
	material.set_shader_parameter("scan_color", scan_color)
	material.set_shader_parameter("scan_edge_color", scan_edge_color)
	material.set_shader_parameter("scan_glow_color", scan_glow_color)
	material.set_shader_parameter("sweep_highlight_color", SWEEP_OUTLINE_HIGHLIGHT_COLOR)
	material.set_shader_parameter("outline_width", 0.006)
	material.set_shader_parameter("emission_power", 4.75)
	material.set_shader_parameter("line_alpha", 0.42)
	material.set_shader_parameter("scan_line_repetitions", 27.0)
	material.set_shader_parameter("scan_line_width", 0.03)
	material.set_shader_parameter("scan_glow_width", 0.068)
	material.set_shader_parameter("sweep_glitch_rate", 0.62)
	material.set_shader_parameter("sweep_line_count", 3.0)
	material.set_shader_parameter("glitch_line_cycle", 24.0)
	material.set_shader_parameter("fresnel_power", 1.4)
	return material


func _create_avatar() -> void:
	_avatar_root = Node3D.new()
	_avatar_root.name = "AvatarRoot"
	add_child(_avatar_root)

	var avatar: Node3D = _instantiate_skin_avatar()
	avatar.name = "HologramAvatar"
	_avatar_root.add_child(avatar)
	_fit_avatar_to_target_height(avatar)
	_apply_hologram_materials(avatar)


func _instantiate_skin_avatar() -> Node3D:
	var normalized: String = CharacterSkinCatalogScript.normalize(character_model_id)
	var scene_path: String = CharacterSkinCatalogScript.scene_path_for(normalized)
	if scene_path.is_empty():
		normalized = CharacterSkinCatalogScript.DEFAULT_ID
		scene_path = CharacterSkinCatalogScript.scene_path_for(normalized)
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene:
		var avatar: Node3D = scene.instantiate() as Node3D
		if avatar:
			if avatar.has_method("set_character_model_id"):
				avatar.call("set_character_model_id", normalized)
			if avatar.has_method("set_accessory_loadout"):
				avatar.call("set_accessory_loadout", PartyMonsterAccessoryCatalogScript.sanitize_loadout(party_monster_accessories, normalized))
			return avatar
	return _build_fallback_avatar()


func _build_fallback_avatar() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackAvatar"
	var fallback_material: StandardMaterial3D = _make_standard_material(_skin_color_tint(), Color(0.1, 0.8, 1.0, 1.0), 1.0, 1.0, false)

	var body: MeshInstance3D = _make_cylinder_mesh("FallbackBody", 0.24, 0.20, 1.05, 32, true, true, fallback_material)
	body.position.y = 0.58
	root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "FallbackHead"
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.38
	head_mesh.radial_segments = 32
	head_mesh.rings = 16
	head_mesh.material = fallback_material
	head.mesh = head_mesh
	head.position.y = 1.28
	root.add_child(head)
	return root


func _fit_avatar_to_target_height(avatar: Node3D) -> void:
	var base_height: float = maxf(0.055, _target_avatar_height * 0.09)
	var base_top: float = base_height + maxf(MIN_AVATAR_BASE_CLEARANCE, _target_avatar_height * AVATAR_BASE_CLEARANCE_RATIO)
	var visual_target_height: float = _target_avatar_height * AVATAR_VISUAL_HEIGHT_MULTIPLIER
	var bounds: AABB = _calculate_bounds_relative_to(_avatar_root, avatar)
	if bounds.size.y <= 0.001:
		avatar.scale = Vector3.ONE * visual_target_height
		avatar.position.y = base_top
		return
	var scale_factor: float = visual_target_height / bounds.size.y
	avatar.scale *= scale_factor
	bounds = _calculate_bounds_relative_to(_avatar_root, avatar)
	if bounds.size.y > 0.001:
		avatar.position.y += base_top - bounds.position.y


func _apply_hologram_materials(root: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(root, meshes)
	var palette: Dictionary = _make_hologram_palette(meshes, root)
	_last_hologram_palette = palette.duplicate(true)
	var scan_color: Color = palette.get("body_color", DEFAULT_HOLOGRAM_BODY_COLOR) as Color
	var scan_edge_color: Color = palette.get("accent_color", DEFAULT_HOLOGRAM_ACCENT_COLOR) as Color
	var scan_glow_color: Color = palette.get("glow_color", DEFAULT_HOLOGRAM_GLOW_COLOR) as Color
	var solid_fill_color: Color = palette.get("solid_fill_color", DEFAULT_HOLOGRAM_SOLID_FILL_COLOR) as Color
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var surface_count: int = mesh_instance.mesh.get_surface_count()
		for surface in range(surface_count):
			var source_material: Material = mesh_instance.get_active_material(surface)
			var material := ShaderMaterial.new()
			material.resource_local_to_scene = true
			material.shader = HOLOGRAM_SHADER
			material.render_priority = 8
			var source_texture: Texture2D = _texture_from_material(source_material)
			var source_color: Color = _color_from_material(source_material)
			material.set_shader_parameter("use_source_texture", source_texture != null)
			if source_texture:
				material.set_shader_parameter("source_texture", source_texture)
			material.set_shader_parameter("source_tint", Color(scan_color.r, scan_color.g, scan_color.b, source_color.a))
			material.set_shader_parameter("scan_color", scan_color)
			material.set_shader_parameter("scan_edge_color", scan_edge_color)
			material.set_shader_parameter("scan_glow_color", scan_glow_color)
			material.set_shader_parameter("solid_fill_color", solid_fill_color)
			material.set_shader_parameter("sweep_highlight_color_a", SWEEP_HIGHLIGHT_COLOR_A)
			material.set_shader_parameter("sweep_highlight_color_b", SWEEP_HIGHLIGHT_COLOR_B)
			material.set_shader_parameter("emission_power", 5.65)
			material.set_shader_parameter("solid_fill_alpha", 0.22)
			material.set_shader_parameter("solid_fill_emission", 0.72)
			material.set_shader_parameter("line_alpha", 0.9)
			material.set_shader_parameter("fresnel_power", 1.55)
			material.set_shader_parameter("scan_line_repetitions", 27.0)
			material.set_shader_parameter("scan_line_width", 0.03)
			material.set_shader_parameter("scan_glow_width", 0.068)
			material.set_shader_parameter("scan_line_intensity", 2.75)
			material.set_shader_parameter("scan_glow_intensity", 1.8)
			material.set_shader_parameter("sweep_highlight_intensity", 3.4)
			material.set_shader_parameter("sweep_glitch_rate_a", 0.72)
			material.set_shader_parameter("sweep_glitch_rate_b", 0.48)
			material.set_shader_parameter("sweep_line_count_a", 4.0)
			material.set_shader_parameter("sweep_line_count_b", 3.0)
			material.set_shader_parameter("glitch_line_cycle", 24.0)
			material.set_shader_parameter("vertex_shift_strength", 0.0045)
			var outline_material: ShaderMaterial = _make_hologram_outline_material(scan_color, scan_edge_color, scan_glow_color)
			material.next_pass = outline_material
			mesh_instance.set_surface_override_material(surface, material)
			_hologram_materials.append(material)
			_hologram_outline_materials.append(outline_material)


func _make_hologram_palette(_meshes: Array[MeshInstance3D], _root: Node) -> Dictionary:
	var body_color: Color = _hologramize_color(_skin_color_tint(), _skin_color_tint(), 0.0)
	return {
		"body_color": body_color,
		"accent_color": body_color,
		"glow_color": body_color,
		"solid_fill_color": body_color,
		"body_sample_count": 0,
		"accent_sample_count": 0,
	}


func _palette_colors_from_material(material: Material) -> Array[Color]:
	var colors: Array[Color] = []
	if material is StandardMaterial3D:
		colors.append((material as StandardMaterial3D).albedo_color)
		return colors
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		for parameter_name in ["color_01", "color_02", "color_03", "color_04", "color_05", "color_06", "color_07", "color_08", "mask_tint", "source_tint", "albedo", "albedo_color", "base_color", "tint_color", "surface_tint"]:
			var value: Variant = shader_material.get_shader_parameter(parameter_name)
			if value is Color:
				var color := value as Color
				if parameter_name == "surface_tint" and _color_distance_rgb(color, GENERIC_SURFACE_TINT) < 0.05:
					continue
				colors.append(color)
	return colors



func _is_palette_color_usable(color: Color) -> bool:
	if color.a <= 0.01:
		return false
	return maxf(color.r, maxf(color.g, color.b)) > 0.03


func _hologramize_color(source_color: Color, fallback: Color, fallback_mix: float) -> Color:
	var source: Color = source_color if _is_palette_color_usable(source_color) else fallback
	var max_channel: float = maxf(source.r, maxf(source.g, source.b))
	if max_channel > 0.001 and max_channel < 0.88:
		var lift: float = 0.88 / max_channel
		source = Color(clampf(source.r * lift, 0.0, 1.0), clampf(source.g * lift, 0.0, 1.0), clampf(source.b * lift, 0.0, 1.0), 1.0)
	source = source.lerp(fallback, clampf(fallback_mix, 0.0, 1.0))
	return Color(clampf(source.r, 0.04, 1.0), clampf(source.g, 0.04, 1.0), clampf(source.b, 0.04, 1.0), 1.0)



func _color_distance_rgb(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)



func _texture_from_material(material: Material) -> Texture2D:
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_texture
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		for parameter_name in ["source_texture", "albedo_texture", "texture_albedo", "base_texture", "diffuse_texture"]:
			var value: Variant = shader_material.get_shader_parameter(parameter_name)
			if value is Texture2D:
				return value as Texture2D
	return null


func _color_from_material(material: Material) -> Color:
	var palette_colors: Array[Color] = _palette_colors_from_material(material)
	if not palette_colors.is_empty():
		return palette_colors[0]
	return _skin_color_tint()


func _skin_color_tint() -> Color:
	match skin_color:
		1:
			return Color(1.0, 0.86, 0.22, 1.0)
		2:
			return Color(0.36, 1.0, 0.48, 1.0)
		3:
			return Color(1.0, 0.28, 0.22, 1.0)
		_:
			return Color(0.28, 0.78, 1.0, 1.0)


func _process_projector_pulse(delta: float) -> void:
	for index in range(_animated_rings.size()):
		var ring: MeshInstance3D = _animated_rings[index]
		if not ring or not is_instance_valid(ring):
			continue
		var phase: float = _pulse_time * (1.2 + float(index) * 0.16) + float(index) * 0.7
		var pulse: float = 1.0 + sin(phase) * 0.08
		ring.scale = Vector3(pulse, 1.0, pulse)
		ring.rotation.y += delta * (0.35 + float(index) * 0.08)
	for index in range(_beam_materials.size()):
		var material: StandardMaterial3D = _beam_materials[index]
		if not material:
			continue
		var alpha: float = 0.13 + 0.09 * (0.5 + 0.5 * sin(_pulse_time * 2.4 + float(index) * 0.9))
		var color: Color = material.albedo_color
		material.albedo_color = Color(color.r, color.g, color.b, clampf(alpha, 0.06, 0.34))

func _play_next_performance_action() -> void:
	if not _avatar_root:
		return
	var avatar: Node = _avatar_root.get_node_or_null("HologramAvatar")
	if not avatar:
		return
	for attempt in range(PERFORMANCE_ACTIONS.size()):
		var action: String = str(PERFORMANCE_ACTIONS[_next_action_index % PERFORMANCE_ACTIONS.size()])
		_next_action_index += 1
		if not _avatar_supports_action(avatar, action):
			continue
		if _play_avatar_action(avatar, action):
			_current_action = action
			_action_timer = maxf(_avatar_current_animation_length(avatar), DEFAULT_ACTION_SECONDS)
			return
	_play_avatar_action(avatar, "idle")
	_current_action = "idle"
	_action_timer = DEFAULT_ACTION_SECONDS


func _avatar_supports_action(avatar: Node, action: String) -> bool:
	if avatar.has_method("has_action"):
		return bool(avatar.call("has_action", action))
	return avatar.has_method(action) or avatar.has_method("play_action")


func _play_avatar_action(avatar: Node, action: String) -> bool:
	if avatar.has_method(action):
		avatar.call(action)
		return true
	if avatar.has_method("play_action"):
		return bool(avatar.call("play_action", action))
	return false


func _avatar_current_animation_length(avatar: Node) -> float:
	if avatar.has_method("get_current_animation_length"):
		return float(avatar.call("get_current_animation_length"))
	return 0.0


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, result)


func _calculate_bounds_relative_to(relative_root: Node3D, node: Node3D) -> AABB:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(node, meshes)
	var has_bounds := false
	var bounds := AABB()
	var root_inverse: Transform3D = relative_root.global_transform.affine_inverse()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_transform: Transform3D = root_inverse * mesh_instance.global_transform
		var local_bounds: AABB = _transform_aabb(local_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var transformed := AABB(transform * aabb.position, Vector3.ZERO)
	for x in [0.0, 1.0]:
		for y in [0.0, 1.0]:
			for z in [0.0, 1.0]:
				var corner := aabb.position + Vector3(aabb.size.x * x, aabb.size.y * y, aabb.size.z * z)
				transformed = transformed.expand(transform * corner)
	return transformed


func get_target_avatar_height_for_test() -> float:
	return _target_avatar_height


func get_avatar_visual_height_for_test() -> float:
	if not _avatar_root:
		return 0.0
	var avatar := _avatar_root.get_node_or_null("HologramAvatar") as Node3D
	if not avatar:
		return 0.0
	return _calculate_bounds_relative_to(self, avatar).size.y


func get_avatar_base_gap_for_test() -> float:
	if not _avatar_root:
		return 0.0
	var avatar := _avatar_root.get_node_or_null("HologramAvatar") as Node3D
	if not avatar:
		return 0.0
	var bounds: AABB = _calculate_bounds_relative_to(self, avatar)
	var base_top: float = maxf(0.055, _target_avatar_height * 0.09)
	return bounds.position.y - base_top


func get_hologram_material_count_for_test() -> int:
	return _hologram_materials.size()


func get_hologram_palette_for_test() -> Dictionary:
	return _last_hologram_palette.duplicate(true)


func get_first_hologram_shader_color_for_test(parameter_name: String) -> Color:
	if _hologram_materials.is_empty():
		return Color(0.0, 0.0, 0.0, 0.0)
	var value: Variant = _hologram_materials[0].get_shader_parameter(parameter_name)
	if value is Color:
		return value as Color
	return Color(0.0, 0.0, 0.0, 0.0)


func get_first_hologram_shader_float_for_test(parameter_name: String) -> float:
	if _hologram_materials.is_empty():
		return 0.0
	var value: Variant = _hologram_materials[0].get_shader_parameter(parameter_name)
	if value is float:
		return value as float
	if value is int:
		return float(value)
	return 0.0


func get_hologram_outline_material_count_for_test() -> int:
	return _hologram_outline_materials.size()


func get_projection_beam_material_count_for_test() -> int:
	return 0


func get_current_performance_action_for_test() -> String:
	return _current_action


func force_next_hologram_action_for_test() -> void:
	_action_timer = 0.0
	_play_next_performance_action()
