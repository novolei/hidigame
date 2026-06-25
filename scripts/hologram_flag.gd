extends Node3D
class_name HologramFlag

const CharacterSkinCatalogScript := preload("res://scripts/character_skin_catalog.gd")
const PartyMonsterAccessoryCatalogScript := preload("res://scripts/party_monster_accessory_catalog.gd")
const HOLOGRAM_SHADER := preload("res://shaders/hologram_avatar.gdshader")

const DEFAULT_PLAYER_HEIGHT := 2.0
const FLAG_HEIGHT_RATIO := 0.3
const MIN_AVATAR_HEIGHT := 0.35
const MAX_AVATAR_HEIGHT := 1.2
const BASE_RADIUS_MIN := 0.22
const PERFORMANCE_ACTIONS := ["dance", "victory"]
const DEFAULT_ACTION_SECONDS := 3.2

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
	_process_projection_pulse(delta)
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
	_action_timer = 0.0
	_current_action = ""


func _create_base_and_projection() -> void:
	_projection_root = Node3D.new()
	_projection_root.name = "ProjectionRig"
	add_child(_projection_root)

	var base_radius: float = maxf(BASE_RADIUS_MIN, _target_avatar_height * 0.42)
	var base_height: float = maxf(0.055, _target_avatar_height * 0.09)
	var base_material: StandardMaterial3D = _make_standard_material(Color(0.018, 0.040, 0.055, 1.0), Color(0.0, 0.32, 0.42, 1.0), 0.16, 1.0, false)
	var base: MeshInstance3D = _make_cylinder_mesh("ProjectorBase", base_radius, base_radius, base_height, 72, true, true, base_material)
	base.position.y = base_height * 0.5
	_projection_root.add_child(base)

	var glow_material: StandardMaterial3D = _make_standard_material(Color(0.08, 0.93, 1.0, 0.48), Color(0.08, 0.93, 1.0, 1.0), 4.6, 0.48, true)
	var glow_disc: MeshInstance3D = _make_cylinder_mesh("ProjectorGlowDisc", base_radius * 0.76, base_radius * 0.54, 0.018, 72, true, true, glow_material)
	glow_disc.position.y = base_height + 0.012
	_projection_root.add_child(glow_disc)
	_beam_materials.append(glow_material)

	var inner_shadow_material: StandardMaterial3D = _make_standard_material(Color(0.005, 0.018, 0.026, 0.92), Color(0.0, 0.12, 0.16, 1.0), 0.12, 0.92, true)
	var inner_shadow: MeshInstance3D = _make_cylinder_mesh("ProjectorDarkCenter", base_radius * 0.46, base_radius * 0.42, 0.012, 64, true, true, inner_shadow_material)
	inner_shadow.position.y = base_height + 0.024
	_projection_root.add_child(inner_shadow)

	var beam_height: float = _target_avatar_height * 1.36
	var beam_material: StandardMaterial3D = _make_standard_material(Color(0.04, 0.82, 1.0, 0.14), Color(0.04, 0.92, 1.0, 1.0), 2.7, 0.14, true)
	var beam: MeshInstance3D = _make_cylinder_mesh("UpwardLightCone", base_radius * 0.58, base_radius * 0.18, beam_height, 72, false, false, beam_material)
	beam.position.y = base_height + beam_height * 0.5
	_projection_root.add_child(beam)
	_beam_materials.append(beam_material)

	for index in range(3):
		var ring_material: StandardMaterial3D = _make_standard_material(Color(0.13, 0.92, 1.0, 0.18), Color(0.13, 0.92, 1.0, 1.0), 2.2, 0.18, true)
		var ring: MeshInstance3D = _make_cylinder_mesh("ScanRing%02d" % index, base_radius * (0.64 + float(index) * 0.17), base_radius * (0.64 + float(index) * 0.17), 0.006, 72, true, true, ring_material)
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
	var base_top: float = maxf(0.055, _target_avatar_height * 0.09) + 0.04
	var bounds: AABB = _calculate_bounds_relative_to(_avatar_root, avatar)
	if bounds.size.y <= 0.001:
		avatar.scale = Vector3.ONE * _target_avatar_height
		avatar.position.y = base_top
		return
	var scale_factor: float = _target_avatar_height / bounds.size.y
	avatar.scale *= scale_factor
	bounds = _calculate_bounds_relative_to(_avatar_root, avatar)
	if bounds.size.y > 0.001:
		avatar.position.y += base_top - bounds.position.y


func _apply_hologram_materials(root: Node) -> void:
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(root, meshes)
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
			material.set_shader_parameter("use_source_texture", source_texture != null)
			if source_texture:
				material.set_shader_parameter("source_texture", source_texture)
			material.set_shader_parameter("source_tint", _color_from_material(source_material))
			material.set_shader_parameter("hologram_color", Color(0.03, 0.82, 1.0, 0.78))
			material.set_shader_parameter("fresnel_color", Color(0.68, 1.0, 1.0, 1.0))
			material.set_shader_parameter("scan_color", Color(0.12, 0.92, 1.0, 1.0))
			material.set_shader_parameter("inherited_skin_strength", 0.48)
			material.set_shader_parameter("scan_line_repetitions", 64.0)
			material.set_shader_parameter("vertex_shift_strength", 0.0055)
			mesh_instance.set_surface_override_material(surface, material)
			_hologram_materials.append(material)


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
	if material is StandardMaterial3D:
		return (material as StandardMaterial3D).albedo_color
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		for parameter_name in ["source_tint", "albedo", "albedo_color", "base_color", "tint_color", "mask_tint"]:
			var value: Variant = shader_material.get_shader_parameter(parameter_name)
			if value is Color:
				return value as Color
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


func _process_projection_pulse(delta: float) -> void:
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


func get_hologram_material_count_for_test() -> int:
	return _hologram_materials.size()


func get_current_performance_action_for_test() -> String:
	return _current_action


func force_next_hologram_action_for_test() -> void:
	_action_timer = 0.0
	_play_next_performance_action()
