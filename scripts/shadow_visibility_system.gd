extends Node
class_name ShadowVisibilitySystem

const CHECK_INTERVAL := 0.2
const RAY_LENGTH := 5.0
const BODY_CENTER_HEIGHT := 1.0
const SAMPLE_RADIUS := 0.42
const WORLD_COLLISION_MASK := 2
const LOCAL_LIGHT_MIN_ENERGY := 0.08
const EMISSIVE_REVEAL_RADIUS := 3.5
const EMISSIVE_MIN_ENERGY := 0.25
const REVEAL_ENVIRONMENT_GROUP := "stalker_reveal_environment"

enum ShadowLevel {
	BRIGHT,
	WEAK_SHADOW,
	STRONG_SHADOW,
	FULL_SHADOW,
}

var shadow_owner: CharacterBody3D = null
var shadow_level: ShadowLevel = ShadowLevel.BRIGHT
var blocked_ray_count := 0
var visibility_alpha := 1.0
var check_accumulator := 0.0
var forced_reveal_remaining := 0.0

signal visibility_changed(level: int, alpha: float, blocked_rays: int)


func initialize(owner_node: CharacterBody3D) -> void:
	shadow_owner = owner_node
	force_shadow_check()


func _process(delta: float) -> void:
	if forced_reveal_remaining > 0.0:
		forced_reveal_remaining = maxf(0.0, forced_reveal_remaining - delta)
	check_accumulator -= delta
	if check_accumulator <= 0.0:
		check_accumulator = CHECK_INTERVAL
		force_shadow_check()


func force_shadow_check() -> void:
	if not shadow_owner or not shadow_owner.is_inside_tree():
		_set_shadow_state(ShadowLevel.BRIGHT, 1.0, 0)
		return

	if forced_reveal_remaining > 0.0 or _has_clear_local_light() or _has_clear_environment_reveal():
		_set_shadow_state(ShadowLevel.BRIGHT, 1.0, 0)
		return

	var blocked := _count_blocked_upward_rays()
	match blocked:
		5:
			_set_shadow_state(ShadowLevel.FULL_SHADOW, 0.0, blocked)
		4:
			_set_shadow_state(ShadowLevel.STRONG_SHADOW, 0.2, blocked)
		3:
			_set_shadow_state(ShadowLevel.WEAK_SHADOW, 0.5, blocked)
		_:
			_set_shadow_state(ShadowLevel.BRIGHT, 1.0, blocked)


func force_reveal(duration: float) -> void:
	forced_reveal_remaining = maxf(forced_reveal_remaining, duration)
	force_shadow_check()


func get_shadow_level() -> int:
	return int(shadow_level)


func get_shadow_rays_blocked() -> int:
	return blocked_ray_count


func get_visibility_alpha() -> float:
	return visibility_alpha


func is_in_shadow() -> bool:
	return blocked_ray_count >= 3


func _count_blocked_upward_rays() -> int:
	var space_state := shadow_owner.get_world_3d().direct_space_state
	var origin := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	var offsets := [
		Vector3.ZERO,
		Vector3.FORWARD * SAMPLE_RADIUS,
		Vector3.BACK * SAMPLE_RADIUS,
		Vector3.LEFT * SAMPLE_RADIUS,
		Vector3.RIGHT * SAMPLE_RADIUS,
	]
	var blocked := 0
	for offset in offsets:
		var start: Vector3 = origin + offset
		var end: Vector3 = start + Vector3.UP * RAY_LENGTH
		var query := PhysicsRayQueryParameters3D.create(start, end, WORLD_COLLISION_MASK)
		if shadow_owner is CollisionObject3D:
			query.exclude = [(shadow_owner as CollisionObject3D).get_rid()]
		var result := space_state.intersect_ray(query)
		if not result.is_empty():
			blocked += 1
	return blocked


func _has_clear_local_light() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	var lights: Array[Light3D] = []
	_collect_local_lights(scene, lights)
	for light in lights:
		if _does_light_reveal_owner(light):
			return true
	return false


func _has_clear_environment_reveal() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	return _node_reveals_from_environment(scene)


func _node_reveals_from_environment(node: Node) -> bool:
	if _is_reveal_environment_node(node) or _is_nearby_emissive_mesh(node):
		return true
	for child in node.get_children():
		if _node_reveals_from_environment(child):
			return true
	return false


func _is_reveal_environment_node(node: Node) -> bool:
	if not node is Node3D:
		return false
	if not node.is_in_group(REVEAL_ENVIRONMENT_GROUP) and node.get_class() != "FogVolume":
		return false
	var radius := _get_reveal_radius(node, 5.0)
	var target := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	var source := (node as Node3D).global_position
	return source.distance_to(target) <= radius and _has_line_of_sight(source, target)


func _is_nearby_emissive_mesh(node: Node) -> bool:
	if not node is MeshInstance3D:
		return false
	var mesh_instance := node as MeshInstance3D
	if not _mesh_has_revealing_emission(mesh_instance):
		return false
	var target := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	var source := mesh_instance.global_position
	return source.distance_to(target) <= EMISSIVE_REVEAL_RADIUS and _has_line_of_sight(source, target)


func _mesh_has_revealing_emission(mesh_instance: MeshInstance3D) -> bool:
	if _material_has_revealing_emission(mesh_instance.material_override):
		return true
	var override_count := mesh_instance.get_surface_override_material_count()
	for i in range(override_count):
		if _material_has_revealing_emission(mesh_instance.get_surface_override_material(i)):
			return true
	if mesh_instance.mesh:
		for i in range(mesh_instance.mesh.get_surface_count()):
			if _material_has_revealing_emission(mesh_instance.mesh.surface_get_material(i)):
				return true
	return false


func _material_has_revealing_emission(material: Material) -> bool:
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return standard.emission_enabled and standard.emission_energy_multiplier >= EMISSIVE_MIN_ENERGY
	return false


func _get_reveal_radius(node: Node, fallback: float) -> float:
	var explicit_radius = node.get("reveal_radius")
	if explicit_radius != null:
		return maxf(float(explicit_radius), 0.0)
	var size = node.get("size")
	if size is Vector3:
		var size_vec := size as Vector3
		return maxf(maxf(size_vec.x, size_vec.y), size_vec.z) * 0.5
	return fallback


func _collect_local_lights(node: Node, lights: Array[Light3D]) -> void:
	if node is DirectionalLight3D or node is OmniLight3D or node is SpotLight3D:
		var light := node as Light3D
		if light.visible and light.light_energy >= LOCAL_LIGHT_MIN_ENERGY:
			lights.append(light)
	for child in node.get_children():
		_collect_local_lights(child, lights)


func _does_light_reveal_owner(light: Light3D) -> bool:
	if light is DirectionalLight3D:
		return _does_directional_light_reveal(light as DirectionalLight3D)

	var light_range := 0.0
	if light is OmniLight3D:
		light_range = (light as OmniLight3D).omni_range
	elif light is SpotLight3D:
		light_range = (light as SpotLight3D).spot_range
	if light_range <= 0.0:
		return false

	var target := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	var light_pos := light.global_position
	var to_target := target - light_pos
	if to_target.length() > light_range:
		return false

	if light is SpotLight3D and not _is_inside_spot_cone(light as SpotLight3D, to_target):
		return false

	return _has_line_of_sight(light_pos, target)


func _does_directional_light_reveal(light: DirectionalLight3D) -> bool:
	var target := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	var light_direction := -light.global_transform.basis.z.normalized()
	var source_probe := target - light_direction * RAY_LENGTH
	return _has_line_of_sight(source_probe, target)


func _is_inside_spot_cone(light: SpotLight3D, to_target: Vector3) -> bool:
	if to_target.length_squared() <= 0.0001:
		return true
	var forward := -light.global_transform.basis.z.normalized()
	var angle := rad_to_deg(forward.angle_to(to_target.normalized()))
	return angle <= light.spot_angle * 0.5


func _has_line_of_sight(start: Vector3, end: Vector3) -> bool:
	var space_state := shadow_owner.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(start, end, WORLD_COLLISION_MASK)
	if shadow_owner is CollisionObject3D:
		query.exclude = [(shadow_owner as CollisionObject3D).get_rid()]
	var result := space_state.intersect_ray(query)
	return result.is_empty()


func _set_shadow_state(level: ShadowLevel, alpha: float, blocked: int) -> void:
	if shadow_level == level and is_equal_approx(visibility_alpha, alpha) and blocked_ray_count == blocked:
		return
	shadow_level = level
	visibility_alpha = alpha
	blocked_ray_count = blocked
	visibility_changed.emit(int(shadow_level), visibility_alpha, blocked_ray_count)
