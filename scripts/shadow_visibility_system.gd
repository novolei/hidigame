extends Node
class_name ShadowVisibilitySystem

const CHECK_INTERVAL := 0.2
const RAY_LENGTH := 5.0
const DIRECTIONAL_RAY_LENGTH := 40.0
const BODY_CENTER_HEIGHT := 1.0
const SAMPLE_RADIUS := 0.42
const WORLD_COLLISION_MASK := 3
const LOCAL_LIGHT_MIN_ENERGY := 0.08
const EMISSIVE_REVEAL_RADIUS := 3.5
const EMISSIVE_MIN_ENERGY := 0.25
const FLASHLIGHT_REVEAL_LOCKOUT := 20.0
const REVEAL_ENVIRONMENT_GROUP := "stalker_reveal_environment"
const EXPLICIT_SHADOW_ZONE_GROUP := "stalker_shadow_zone"
const HUNTER_FLASHLIGHT_GROUP := "hunter_flashlights"
const HUNTER_FLASHLIGHT_LIGHT_GROUP := "hunter_flashlight_lights"
const REVEAL_SOURCE_IGNORED_GROUPS := [
	"players",
	"replicable_props",
	"ammo_pickups",
	"dynamic_shadow_noise",
]
const MAX_RAY_SKIP_COUNT := 8
const IGNORED_SHADOW_CASTER_GROUPS := [
	"players",
	"map_props",
	"replicable_props",
	"ammo_pickups",
	"dynamic_shadow_noise",
]

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
var hunter_flashlight_exposure := 0.0
var flashlight_reveal_lockout_remaining := 0.0
var hunter_flashlight_reveal_latched := false

signal visibility_changed(level: int, alpha: float, blocked_rays: int)


func initialize(owner_node: CharacterBody3D) -> void:
	shadow_owner = owner_node
	force_shadow_check()


func _process(delta: float) -> void:
	if forced_reveal_remaining > 0.0:
		forced_reveal_remaining = maxf(0.0, forced_reveal_remaining - delta)
	if flashlight_reveal_lockout_remaining > 0.0:
		flashlight_reveal_lockout_remaining = maxf(0.0, flashlight_reveal_lockout_remaining - delta)
	_update_hunter_flashlight_exposure(delta)
	check_accumulator -= delta
	if check_accumulator <= 0.0:
		check_accumulator = CHECK_INTERVAL
		force_shadow_check()


func force_shadow_check() -> void:
	if not shadow_owner or not shadow_owner.is_inside_tree():
		_set_shadow_state(ShadowLevel.BRIGHT, 1.0, 0)
		return

	var explicit_shadow_blocked := _count_explicit_shadow_zone_blocked_rays()
	if forced_reveal_remaining > 0.0 or flashlight_reveal_lockout_remaining > 0.0 or _is_hunter_flashlight_revealed() or _has_clear_non_directional_light() or _has_clear_environment_reveal():
		_set_shadow_state(ShadowLevel.BRIGHT, 1.0, 0)
		return
	if explicit_shadow_blocked >= 3:
		_set_shadow_state(ShadowLevel.FULL_SHADOW, 0.0, explicit_shadow_blocked)
		return
	if _has_clear_directional_light():
		_set_shadow_state(ShadowLevel.BRIGHT, 1.0, 0)
		return

	var blocked := _count_blocked_shadow_rays()
	match blocked:
		5:
			_set_shadow_state(ShadowLevel.FULL_SHADOW, 0.0, blocked)
		4:
			_set_shadow_state(ShadowLevel.STRONG_SHADOW, 0.34, blocked)
		3:
			_set_shadow_state(ShadowLevel.WEAK_SHADOW, 0.68, blocked)
		_:
			_set_shadow_state(ShadowLevel.BRIGHT, 1.0, blocked)


func force_reveal(duration: float) -> void:
	forced_reveal_remaining = maxf(forced_reveal_remaining, duration)
	force_shadow_check()


func apply_hunter_flashlight_rewind_exposure(sample_seconds: float) -> void:
	var reveal_seconds: float = _hunter_flashlight_reveal_seconds()
	hunter_flashlight_exposure = minf(reveal_seconds, hunter_flashlight_exposure + maxf(sample_seconds, 0.0))
	if hunter_flashlight_exposure >= reveal_seconds and not hunter_flashlight_reveal_latched:
		hunter_flashlight_reveal_latched = true
		flashlight_reveal_lockout_remaining = maxf(flashlight_reveal_lockout_remaining, FLASHLIGHT_REVEAL_LOCKOUT)
	force_shadow_check()


func get_shadow_level() -> int:
	return int(shadow_level)


func get_shadow_rays_blocked() -> int:
	return blocked_ray_count


func get_visibility_alpha() -> float:
	return visibility_alpha


func get_hunter_flashlight_exposure() -> float:
	return hunter_flashlight_exposure


func get_flashlight_reveal_lockout_remaining() -> float:
	return flashlight_reveal_lockout_remaining


func is_in_shadow() -> bool:
	return blocked_ray_count >= 3


func _count_blocked_shadow_rays() -> int:
	return max(_count_blocked_upward_rays(), _count_blocked_directional_light_rays())


func _count_explicit_shadow_zone_blocked_rays() -> int:
	var scene := get_tree().current_scene
	if not scene:
		return 0
	var blocked := 0
	var origin := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	for offset in _shadow_sample_offsets():
		if _point_is_inside_explicit_shadow_zone(origin + offset, scene):
			blocked += 1
	return blocked


func _count_blocked_upward_rays() -> int:
	var space_state := shadow_owner.get_world_3d().direct_space_state
	var origin := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	var blocked := 0
	for offset in _shadow_sample_offsets():
		var start: Vector3 = origin + offset
		var end: Vector3 = start + Vector3.UP * RAY_LENGTH
		if _has_shadow_blocker_between(space_state, start, end):
			blocked += 1
	return blocked


func _count_blocked_directional_light_rays() -> int:
	var scene := get_tree().current_scene
	if not scene:
		return 0
	var lights: Array[DirectionalLight3D] = []
	_collect_directional_lights(scene, lights)
	var most_blocked := 0
	for light in lights:
		if light.visible and light.light_energy >= LOCAL_LIGHT_MIN_ENERGY:
			most_blocked = max(most_blocked, _count_blocked_rays_from_directional_light(light))
	return most_blocked


func _count_blocked_rays_from_directional_light(light: DirectionalLight3D) -> int:
	var target_origin := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	var light_direction := -light.global_transform.basis.z.normalized()
	var blocked := 0
	for offset in _shadow_sample_offsets():
		var target: Vector3 = target_origin + offset
		var source := target - light_direction * DIRECTIONAL_RAY_LENGTH
		if not _has_line_of_sight(source, target):
			blocked += 1
	return blocked


func _shadow_sample_offsets() -> Array[Vector3]:
	return [
		Vector3.ZERO,
		Vector3.FORWARD * SAMPLE_RADIUS,
		Vector3.BACK * SAMPLE_RADIUS,
		Vector3.LEFT * SAMPLE_RADIUS,
		Vector3.RIGHT * SAMPLE_RADIUS,
	]


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


func _has_clear_non_directional_light() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	var lights: Array[Light3D] = []
	_collect_local_lights(scene, lights)
	for light in lights:
		if light is DirectionalLight3D:
			continue
		if light.is_in_group(HUNTER_FLASHLIGHT_LIGHT_GROUP):
			continue
		if _does_light_reveal_owner(light):
			return true
	return false


func _update_hunter_flashlight_exposure(delta: float) -> void:
	var reveal_seconds := _hunter_flashlight_reveal_seconds()
	if _is_inside_hunter_flashlight_beam():
		hunter_flashlight_exposure = minf(reveal_seconds, hunter_flashlight_exposure + delta)
		if hunter_flashlight_exposure >= reveal_seconds and not hunter_flashlight_reveal_latched:
			hunter_flashlight_reveal_latched = true
			flashlight_reveal_lockout_remaining = maxf(flashlight_reveal_lockout_remaining, FLASHLIGHT_REVEAL_LOCKOUT)
	else:
		hunter_flashlight_exposure = 0.0
		hunter_flashlight_reveal_latched = false


func _is_hunter_flashlight_revealed() -> bool:
	return hunter_flashlight_exposure >= _hunter_flashlight_reveal_seconds()


func _hunter_flashlight_reveal_seconds() -> float:
	var seconds := 5.0
	var tree := get_tree()
	if tree:
		for node in tree.get_nodes_in_group(HUNTER_FLASHLIGHT_GROUP):
			if node and node.has_method("get_reveal_seconds"):
				seconds = float(node.call("get_reveal_seconds"))
				break
	return maxf(seconds, 0.1)


func _is_inside_hunter_flashlight_beam() -> bool:
	var tree := get_tree()
	if not tree or not shadow_owner:
		return false
	var target := shadow_owner.global_position + Vector3.UP * BODY_CENTER_HEIGHT
	for node in tree.get_nodes_in_group(HUNTER_FLASHLIGHT_GROUP):
		if not node or not node.has_method("is_flashlight_active") or not bool(node.call("is_flashlight_active")):
			continue
		var origin: Vector3 = node.call("get_flashlight_origin")
		var direction: Vector3 = node.call("get_flashlight_direction")
		if direction.length_squared() <= 0.0001:
			continue
		var to_target := target - origin
		var distance := to_target.length()
		var light_range := float(node.call("get_flashlight_range")) if node.has_method("get_flashlight_range") else 18.0
		if distance > light_range or distance <= 0.001:
			continue
		var angle := rad_to_deg(direction.normalized().angle_to(to_target.normalized()))
		var half_angle := float(node.call("get_flashlight_half_angle_degrees")) if node.has_method("get_flashlight_half_angle_degrees") else 19.0
		if angle > half_angle:
			continue
		if _has_line_of_sight(origin + direction.normalized() * 0.25, target):
			return true
	return false


func _has_clear_directional_light() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	var lights: Array[DirectionalLight3D] = []
	_collect_directional_lights(scene, lights)
	for light in lights:
		if light.visible and light.light_energy >= LOCAL_LIGHT_MIN_ENERGY and _does_directional_light_reveal(light):
			return true
	return false


func _has_clear_environment_reveal() -> bool:
	var scene := get_tree().current_scene
	if not scene:
		return false
	return _node_reveals_from_environment(scene)


func _node_reveals_from_environment(node: Node) -> bool:
	if _is_ignored_reveal_source(node):
		return false
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
		if light.visible and light.light_energy >= LOCAL_LIGHT_MIN_ENERGY and not light.is_in_group(HUNTER_FLASHLIGHT_LIGHT_GROUP) and not _is_ignored_reveal_source(light):
			lights.append(light)
	for child in node.get_children():
		_collect_local_lights(child, lights)


func _collect_directional_lights(node: Node, lights: Array[DirectionalLight3D]) -> void:
	if node is DirectionalLight3D:
		lights.append(node as DirectionalLight3D)
	for child in node.get_children():
		_collect_directional_lights(child, lights)


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
	var source_probe := target - light_direction * DIRECTIONAL_RAY_LENGTH
	return _has_line_of_sight(source_probe, target)


func _is_inside_spot_cone(light: SpotLight3D, to_target: Vector3) -> bool:
	if to_target.length_squared() <= 0.0001:
		return true
	var forward := -light.global_transform.basis.z.normalized()
	var angle := rad_to_deg(forward.angle_to(to_target.normalized()))
	return angle <= light.spot_angle * 0.5


func _has_line_of_sight(start: Vector3, end: Vector3) -> bool:
	var space_state := shadow_owner.get_world_3d().direct_space_state
	return not _has_shadow_blocker_between(space_state, start, end)


func _has_shadow_blocker_between(space_state: PhysicsDirectSpaceState3D, start: Vector3, end: Vector3) -> bool:
	var exclude: Array[RID] = []
	if shadow_owner is CollisionObject3D:
		exclude.append((shadow_owner as CollisionObject3D).get_rid())
	for i in range(MAX_RAY_SKIP_COUNT):
		var query := PhysicsRayQueryParameters3D.create(start, end, WORLD_COLLISION_MASK)
		query.exclude = exclude
		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return false
		var collider = result.get("collider")
		if _is_valid_shadow_caster(collider):
			return true
		if collider is CollisionObject3D:
			exclude.append((collider as CollisionObject3D).get_rid())
		else:
			return false
	return false


func _point_is_inside_explicit_shadow_zone(point: Vector3, node: Node) -> bool:
	if node is Area3D and node.is_in_group(EXPLICIT_SHADOW_ZONE_GROUP):
		if _point_is_inside_area_shapes(point, node as Area3D):
			return true
	for child in node.get_children():
		if _point_is_inside_explicit_shadow_zone(point, child):
			return true
	return false


func _point_is_inside_area_shapes(point: Vector3, area: Area3D) -> bool:
	for child in area.get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.disabled or not collision.shape:
			continue
		if _point_is_inside_shape(point, collision.global_transform, collision.shape):
			return true
	return false


func _point_is_inside_shape(point: Vector3, shape_transform: Transform3D, shape: Shape3D) -> bool:
	var local_point := shape_transform.affine_inverse() * point
	if shape is BoxShape3D:
		var half_extents := (shape as BoxShape3D).size * 0.5
		return absf(local_point.x) <= half_extents.x and absf(local_point.y) <= half_extents.y and absf(local_point.z) <= half_extents.z
	if shape is SphereShape3D:
		return local_point.length() <= (shape as SphereShape3D).radius
	if shape is CylinderShape3D:
		var cylinder := shape as CylinderShape3D
		var radial := Vector2(local_point.x, local_point.z).length()
		return radial <= cylinder.radius and absf(local_point.y) <= cylinder.height * 0.5
	return false


func _is_valid_shadow_caster(collider) -> bool:
	if not collider is Node:
		return true
	var node := collider as Node
	for group_name in IGNORED_SHADOW_CASTER_GROUPS:
		if node.is_in_group(group_name):
			return false
	var parent := node.get_parent()
	while parent:
		for group_name in IGNORED_SHADOW_CASTER_GROUPS:
			if parent.is_in_group(group_name):
				return false
		parent = parent.get_parent()
	return true


func _is_ignored_reveal_source(node: Node) -> bool:
	var current := node
	while current:
		for group_name in REVEAL_SOURCE_IGNORED_GROUPS:
			if current.is_in_group(group_name):
				return true
		current = current.get_parent()
	return false


func _set_shadow_state(level: ShadowLevel, alpha: float, blocked: int) -> void:
	if shadow_level == level and is_equal_approx(visibility_alpha, alpha) and blocked_ray_count == blocked:
		return
	shadow_level = level
	visibility_alpha = alpha
	blocked_ray_count = blocked
	visibility_changed.emit(int(shadow_level), visibility_alpha, blocked_ray_count)
