extends RigidBody3D
class_name FruitProp


# Compatibility note: the class name is retained for older tests and level code.
# Runtime behavior is now a generic, replicable map prop.
const PLAYER_IMPACT_MIN_SPEED := 1.4
const PLAYER_IMPACT_BASE_MULTIPLIER := 0.38
const PLAYER_IMPACT_DISGUISED_MULTIPLIER := 0.52
const PLAYER_IMPACT_MAX_IMPULSE := 7.5
const PLAYER_ROLL_TORQUE_MULTIPLIER := 1.35
const GROUND_CLEARANCE := 0.045
const PHYSICS_LAYER_WORLD := 2
const PHYSICS_LAYER_PROP := 4
const MAX_LINEAR_SPEED := 7.0
const MAX_ANGULAR_SPEED := 7.5
const FLOOR_SETTLE_LINEAR_SPEED := 0.14
const FLOOR_SETTLE_ANGULAR_SPEED := 0.22
const NETWORK_SYNC_INTERVAL := 0.08
const NETWORK_POSITION_EPSILON := 0.015
const NETWORK_ROTATION_EPSILON := 0.01
const NETWORK_VELOCITY_EPSILON := 0.04
const CLIENT_IMPACT_REQUEST_INTERVAL := 0.12
const CLIENT_MAX_REPORTED_IMPACT_SPEED := 9.0

var prop_id := "apple"
var display_name := "Apple"
var category := "fruit"
var scene_path := "res://Prefabs/Fruits/apple.tscn"
var fallback_material_path := "res://Materials/M_fruit.tres"
var disguise_scale := Vector3.ONE
var collision_radius := 0.22
var collision_height := 0.45
var collision_half_height := 0.225
var collision_kind := "cylinder"
var visual_bounds := AABB()
var visual_root: Node3D = null
var ground_position := Vector3.ZERO
var _network_sync_elapsed := 0.0
var _network_sync_initialized := false
var _last_synced_transform := Transform3D()
var _last_synced_linear_velocity := Vector3.ZERO
var _last_synced_angular_velocity := Vector3.ZERO
var _last_synced_sleeping := true
var _client_impact_request_cooldown := 0.0


func _ready() -> void:
	_configure_physics_body()
	_configure_multiplayer_body_authority()
	add_to_group("map_props")
	add_to_group("replicable_props")
	if category == "fruit":
		add_to_group("fruit_props")


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_network_sync_elapsed += delta
		if _network_sync_elapsed >= NETWORK_SYNC_INTERVAL:
			_network_sync_elapsed = 0.0
			if _should_broadcast_network_state():
				_broadcast_network_state()
	elif _client_impact_request_cooldown > 0.0:
		_client_impact_request_cooldown = maxf(0.0, _client_impact_request_cooldown - delta)


func apply_data(data: Dictionary) -> void:
	prop_id = str(data.get("id", prop_id))
	display_name = str(data.get("name", data.get("display_name", display_name)))
	category = str(data.get("category", category))
	scene_path = str(data.get("scene", scene_path))
	fallback_material_path = str(data.get("material", data.get("material_path", fallback_material_path)))
	disguise_scale = data.get("scale", disguise_scale)
	collision_radius = clampf(float(data.get("radius", collision_radius)), 0.12, 0.85)
	collision_height = clampf(float(data.get("collision_height", collision_height)), 0.24, 1.35)
	_configure_physics_body()
	ground_position = data.get("position", global_position)
	global_position = ground_position
	rotation.y = float(data.get("rotation_y", rotation.y))
	_refresh_groups()
	_rebuild_visual()
	_configure_multiplayer_body_authority()


func get_disguise_preset() -> Dictionary:
	return {
		"id": "map_prop_" + prop_id,
		"name": display_name,
		"mesh": "scene",
		"scene_path": scene_path,
		"material_path": fallback_material_path,
		"scale": disguise_scale,
		"offset": _get_grounded_disguise_offset(),
		"prop_height": max(visual_bounds.size.y, 0.6),
		"collision_radius": _get_disguise_collision_radius(),
		"collision_height": _get_disguise_collision_height(),
		"drop_height": clampf(max(visual_bounds.size.y, 1.0) * 0.32, 1.1, 3.0),
		"rotation": Vector3.ZERO,
		"tags": ["#prop", "#" + category, "#" + prop_id],
	}


func _refresh_groups() -> void:
	add_to_group("map_props")
	add_to_group("replicable_props")
	if category == "fruit":
		add_to_group("fruit_props")
	elif is_in_group("fruit_props"):
		remove_from_group("fruit_props")


func _rebuild_visual() -> void:
	for child in get_children():
		child.queue_free()

	var scene := load(scene_path)
	if scene is PackedScene:
		visual_root = (scene as PackedScene).instantiate() as Node3D
		if visual_root:
			visual_root.name = "MapPropVisual"
			visual_root.scale = disguise_scale
			add_child(visual_root)
			_apply_fallback_material(visual_root)
			_disable_nested_collisions(visual_root)
			visual_bounds = _calculate_visual_bounds()
	else:
		push_warning("Map prop scene did not load: " + scene_path)
		visual_bounds = AABB()

	var collision := CollisionShape3D.new()
	var shape := _build_collision_shape()
	collision.position = Vector3.ZERO
	collision.shape = shape
	add_child(collision)
	_place_body_and_visual_on_ground()
	mass = _calculate_mass()
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = _calculate_center_of_mass_offset()
	sleeping = true


func apply_player_impact(player_velocity: Vector3, contact_point: Vector3 = Vector3.ZERO, contact_normal: Vector3 = Vector3.ZERO, disguised_player: bool = false) -> void:
	if not multiplayer.is_server():
		_request_authoritative_player_impact(player_velocity, contact_point, contact_normal, disguised_player)
		return
	_apply_player_impact_authoritative(player_velocity, contact_point, contact_normal, disguised_player)


func _request_authoritative_player_impact(player_velocity: Vector3, contact_point: Vector3, contact_normal: Vector3, disguised_player: bool) -> void:
	if _client_impact_request_cooldown > 0.0:
		return
	_client_impact_request_cooldown = CLIENT_IMPACT_REQUEST_INTERVAL
	var reported_velocity := player_velocity
	if reported_velocity.length() > CLIENT_MAX_REPORTED_IMPACT_SPEED:
		reported_velocity = reported_velocity.normalized() * CLIENT_MAX_REPORTED_IMPACT_SPEED
	var level := _get_level_node()
	if level and level.has_method("request_map_prop_impact"):
		level.request_map_prop_impact(self, reported_velocity, contact_point, contact_normal, disguised_player)
		return
	_request_player_impact_rpc.rpc_id(1, reported_velocity, contact_point, contact_normal, disguised_player)


@rpc("any_peer", "call_local", "reliable")
func _request_player_impact_rpc(player_velocity: Vector3, contact_point: Vector3, contact_normal: Vector3, disguised_player: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != 0 and not Network.players.has(sender_id):
		return
	var reported_velocity := player_velocity
	if reported_velocity.length() > CLIENT_MAX_REPORTED_IMPACT_SPEED:
		reported_velocity = reported_velocity.normalized() * CLIENT_MAX_REPORTED_IMPACT_SPEED
	_apply_player_impact_authoritative(reported_velocity, contact_point, contact_normal, disguised_player)


func _apply_player_impact_authoritative(player_velocity: Vector3, contact_point: Vector3 = Vector3.ZERO, contact_normal: Vector3 = Vector3.ZERO, disguised_player: bool = false) -> void:
	var horizontal_velocity := Vector3(player_velocity.x, 0.0, player_velocity.z)
	var speed := horizontal_velocity.length()
	if speed < PLAYER_IMPACT_MIN_SPEED:
		return

	var impact_direction := horizontal_velocity.normalized()
	if contact_normal.length_squared() > 0.01:
		var normal_direction := Vector3(-contact_normal.x, 0.0, -contact_normal.z)
		if normal_direction.length_squared() > 0.01:
			impact_direction = normal_direction.normalized().lerp(impact_direction, 0.35).normalized()

	var multiplier := PLAYER_IMPACT_DISGUISED_MULTIPLIER if disguised_player else PLAYER_IMPACT_BASE_MULTIPLIER
	var mass_resistance := clampf(3.0 / maxf(mass, 1.0), 0.35, 1.0)
	var impulse_strength := clampf(speed * multiplier * mass_resistance, 0.0, PLAYER_IMPACT_MAX_IMPULSE)
	var impulse := impact_direction * impulse_strength
	sleeping = false
	apply_central_impulse(impulse)

	var roll_axis := Vector3.UP.cross(impact_direction)
	if roll_axis.length_squared() > 0.01:
		var roll_multiplier := PLAYER_ROLL_TORQUE_MULTIPLIER
		if collision_kind in ["box", "flat_box"]:
			roll_multiplier *= 0.45
		elif collision_kind == "sphere":
			roll_multiplier *= 0.75
		apply_torque_impulse(roll_axis.normalized() * impulse_strength * maxf(collision_radius, 0.2) * roll_multiplier)
	_broadcast_network_state()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var next_linear := state.linear_velocity
	var next_angular := state.angular_velocity
	if next_linear.length() > MAX_LINEAR_SPEED:
		next_linear = next_linear.normalized() * MAX_LINEAR_SPEED
	if next_angular.length() > MAX_ANGULAR_SPEED:
		next_angular = next_angular.normalized() * MAX_ANGULAR_SPEED

	var has_floor_contact := false
	var has_wall_contact := false
	for i in range(state.get_contact_count()):
		var normal := state.get_contact_local_normal(i)
		if normal.y > 0.55:
			has_floor_contact = true
		elif absf(normal.y) < 0.35:
			has_wall_contact = true

	if has_floor_contact:
		next_linear.y = minf(next_linear.y, 0.0)
		next_linear.x *= 0.975
		next_linear.z *= 0.975
		next_angular *= _floor_angular_damping()
		if next_linear.length() < FLOOR_SETTLE_LINEAR_SPEED and next_angular.length() < FLOOR_SETTLE_ANGULAR_SPEED:
			next_linear = Vector3.ZERO
			next_angular = Vector3.ZERO
			sleeping = true
	if has_wall_contact:
		next_linear *= 0.82
		next_angular *= 0.88

	state.linear_velocity = next_linear
	state.angular_velocity = next_angular


func _get_grounded_disguise_offset() -> Vector3:
	if visual_bounds.size == Vector3.ZERO:
		return Vector3.ZERO
	return Vector3(0.0, max(0.0, -visual_bounds.position.y) + 0.02, 0.0)


func _configure_physics_body() -> void:
	collision_layer = PHYSICS_LAYER_PROP
	collision_mask = PHYSICS_LAYER_WORLD
	gravity_scale = 1.45
	linear_damp = 2.6
	angular_damp = 1.8
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 8
	if _has_property("continuous_cd"):
		set("continuous_cd", true)
	var material := PhysicsMaterial.new()
	material.friction = 0.78
	material.bounce = 0.025
	physics_material_override = material


func _configure_multiplayer_body_authority() -> void:
	if multiplayer.is_server():
		freeze = false
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	sleeping = true


func _should_broadcast_network_state() -> bool:
	if not _network_sync_initialized:
		return true
	if _last_synced_sleeping != sleeping:
		return true
	if global_position.distance_squared_to(_last_synced_transform.origin) > NETWORK_POSITION_EPSILON * NETWORK_POSITION_EPSILON:
		return true
	var current_rotation := global_transform.basis.get_rotation_quaternion()
	var synced_rotation := _last_synced_transform.basis.get_rotation_quaternion()
	if current_rotation.angle_to(synced_rotation) > NETWORK_ROTATION_EPSILON:
		return true
	if linear_velocity.distance_squared_to(_last_synced_linear_velocity) > NETWORK_VELOCITY_EPSILON * NETWORK_VELOCITY_EPSILON:
		return true
	if angular_velocity.distance_squared_to(_last_synced_angular_velocity) > NETWORK_VELOCITY_EPSILON * NETWORK_VELOCITY_EPSILON:
		return true
	return false


func _broadcast_network_state() -> void:
	if not multiplayer.is_server():
		return
	var was_sleeping := _last_synced_sleeping
	_store_synced_network_state()
	var level := _get_level_node()
	if level and level.has_method("_server_publish_map_prop_state"):
		level._server_publish_map_prop_state(self, sleeping or was_sleeping != sleeping)
		return
	if sleeping or was_sleeping != sleeping:
		_sync_prop_rest_state.rpc(global_transform, linear_velocity, angular_velocity, sleeping)
	else:
		_sync_prop_motion_state.rpc(global_transform, linear_velocity, angular_velocity, sleeping)


func _store_synced_network_state() -> void:
	_network_sync_initialized = true
	_last_synced_transform = global_transform
	_last_synced_linear_velocity = linear_velocity
	_last_synced_angular_velocity = angular_velocity
	_last_synced_sleeping = sleeping


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_prop_motion_state(next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	_apply_network_physics_state(next_transform, next_linear_velocity, next_angular_velocity, next_sleeping)


@rpc("authority", "call_remote", "reliable")
func _sync_prop_rest_state(next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool) -> void:
	_apply_network_physics_state(next_transform, next_linear_velocity, next_angular_velocity, next_sleeping)


func _apply_network_physics_state(next_transform: Transform3D, next_linear_velocity: Vector3, next_angular_velocity: Vector3, next_sleeping: bool, force: bool = false) -> void:
	if is_inside_tree() and multiplayer.is_server() and not force:
		return
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	if is_inside_tree():
		global_transform = next_transform
	else:
		transform = next_transform
	linear_velocity = next_linear_velocity
	angular_velocity = next_angular_velocity
	sleeping = next_sleeping


func _get_level_node() -> Node:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene and scene.has_method("_server_publish_map_prop_state"):
		return scene
	var node := get_parent()
	while node:
		if node.has_method("_server_publish_map_prop_state") or node.has_method("request_map_prop_impact"):
			return node
		node = node.get_parent()
	return null


func _place_body_and_visual_on_ground() -> void:
	var base_ground := ground_position
	global_position = Vector3(base_ground.x, base_ground.y + collision_half_height + GROUND_CLEARANCE, base_ground.z)
	if not visual_root:
		return
	visual_root.position.y = 0.0
	visual_bounds = _calculate_visual_bounds()
	if visual_bounds.size == Vector3.ZERO:
		return
	var target_bottom := -collision_half_height + GROUND_CLEARANCE
	visual_root.position.y += target_bottom - visual_bounds.position.y
	visual_bounds = _calculate_visual_bounds()


func _build_collision_shape() -> Shape3D:
	var size := visual_bounds.size
	if size == Vector3.ZERO:
		size = Vector3(collision_radius * 2.0, collision_height, collision_radius * 2.0)
	var horizontal_max := maxf(size.x, size.z)
	var horizontal_min := minf(size.x, size.z)
	var visual_radius := horizontal_max * 0.5
	var flatness := size.y / maxf(horizontal_max, 0.001)
	collision_kind = _infer_collision_kind(size)

	match collision_kind:
		"sphere":
			var sphere := SphereShape3D.new()
			collision_radius = clampf(maxf(maxf(horizontal_max, size.y) * 0.44, collision_radius), 0.22, 2.4)
			collision_height = collision_radius * 2.0
			collision_half_height = collision_radius
			sphere.radius = collision_radius
			return sphere
		"flat_box":
			var box := BoxShape3D.new()
			var box_size := Vector3(
				clampf(size.x * 0.72, 0.35, 3.2),
				clampf(maxf(size.y * 0.52, 0.16), 0.16, 0.55),
				clampf(size.z * 0.72, 0.35, 3.2)
			)
			collision_radius = maxf(box_size.x, box_size.z) * 0.5
			collision_height = box_size.y
			collision_half_height = box_size.y * 0.5
			box.size = box_size
			return box
		"box":
			var box := BoxShape3D.new()
			var box_size := Vector3(
				clampf(size.x * 0.68, 0.28, 2.8),
				clampf(size.y * 0.64, 0.22, 1.8),
				clampf(size.z * 0.68, 0.28, 2.8)
			)
			collision_radius = maxf(box_size.x, box_size.z) * 0.5
			collision_height = box_size.y
			collision_half_height = box_size.y * 0.5
			box.size = box_size
			return box
		"tall":
			var cylinder := CylinderShape3D.new()
			collision_radius = clampf(maxf(visual_radius * 0.44, collision_radius), 0.20, 1.4)
			collision_height = clampf(size.y * 0.82, 0.5, 2.8)
			collision_half_height = collision_height * 0.5
			cylinder.radius = collision_radius
			cylinder.height = collision_height
			return cylinder
		_:
			var cylinder := CylinderShape3D.new()
			var radius_factor := 0.38 if horizontal_min / maxf(horizontal_max, 0.001) > 0.62 else 0.30
			collision_radius = clampf(maxf(visual_radius * radius_factor, collision_radius), 0.18, 1.6)
			collision_height = clampf(size.y * clampf(0.52 + flatness * 0.18, 0.46, 0.78), 0.26, 1.65)
			collision_half_height = collision_height * 0.5
			cylinder.radius = collision_radius
			cylinder.height = collision_height
			return cylinder


func _infer_collision_kind(size: Vector3) -> String:
	var id := prop_id.to_lower()
	if id in ["apple", "watermelon", "coconut", "orange", "lemon", "lime", "tomato", "egg", "potato"]:
		return "sphere"
	if id in ["plate", "dish", "dish_full", "pizza_cheese", "pizza_pepperoni", "steak", "egg_cooked"]:
		return "flat_box"
	if id in ["banana", "banana_bunch", "cucumber", "zucchini", "corn", "carrot", "eggplant", "hot_dog", "drumstick"]:
		return "box"
	if id in ["pineapple", "soda_can_cola", "soda_can_beer", "ice_cream_vanilla_cone", "ice_cream_chocolate_cone", "ice_cream_strawberry_cone"]:
		return "tall"
	if size.y > maxf(size.x, size.z) * 1.25:
		return "tall"
	if size.y < maxf(size.x, size.z) * 0.32:
		return "flat_box"
	return "cylinder"


func _calculate_mass() -> float:
	var volume := PI * collision_radius * collision_radius * maxf(collision_height, 0.2)
	if collision_kind in ["box", "flat_box"]:
		volume = maxf(collision_radius * 2.0, 0.2) * maxf(collision_height, 0.16) * maxf(collision_radius * 1.35, 0.2)
	elif collision_kind == "sphere":
		volume = (4.0 / 3.0) * PI * pow(collision_radius, 3.0)
	var density := 2.6
	if category in ["dish", "sushi"]:
		density = 3.2
	elif category in ["fruit", "vegetable"]:
		density = 3.6
	elif category == "junk_food":
		density = 2.4
	return clampf(2.4 + volume * density, 2.4, 24.0)


func _calculate_center_of_mass_offset() -> Vector3:
	if collision_kind in ["tall", "box"]:
		return Vector3(0.0, -collision_half_height * 0.22, 0.0)
	if prop_id.to_lower() == "pineapple":
		return Vector3(0.0, -collision_half_height * 0.32, 0.0)
	if collision_kind == "flat_box":
		return Vector3(0.0, -collision_half_height * 0.08, 0.0)
	return Vector3.ZERO


func _floor_angular_damping() -> float:
	if collision_kind == "sphere":
		return 0.96
	if collision_kind == "tall":
		return 0.84
	if collision_kind in ["box", "flat_box"]:
		return 0.78
	return 0.90


func _has_property(property_name: String) -> bool:
	for property in get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _disable_nested_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_nested_collisions(child)


func _get_map_collision_radius() -> float:
	if visual_bounds.size == Vector3.ZERO:
		return collision_radius
	var visual_radius := maxf(visual_bounds.size.x, visual_bounds.size.z) * 0.34
	return clampf(maxf(collision_radius, visual_radius), 0.18, 1.6)


func _get_map_collision_height() -> float:
	if visual_bounds.size == Vector3.ZERO:
		return collision_height
	var visual_height := visual_bounds.size.y * 0.58
	return clampf(maxf(collision_height, visual_height), 0.28, 1.8)


func _get_disguise_collision_radius() -> float:
	if visual_bounds.size == Vector3.ZERO:
		return clampf(collision_radius, 0.32, 1.25)
	var visual_radius := maxf(visual_bounds.size.x, visual_bounds.size.z) * 0.34
	return clampf(maxf(collision_radius, visual_radius), 0.32, 1.25)


func _get_disguise_collision_height() -> float:
	if visual_bounds.size == Vector3.ZERO:
		return clampf(collision_height, 0.45, 2.2)
	var visual_height := visual_bounds.size.y * 0.58
	return clampf(maxf(collision_height, visual_height), 0.45, 2.2)


func _calculate_visual_bounds() -> AABB:
	if not visual_root:
		return AABB()
	var meshes: Array[MeshInstance3D] = []
	_find_mesh_instances(visual_root, meshes)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		if not mesh_instance.mesh:
			continue
		var local_bounds := _transform_aabb(global_transform.affine_inverse() * mesh_instance.global_transform, mesh_instance.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return bounds if has_bounds else AABB()


func _find_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_mesh_instances(child, result)


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


func _apply_fallback_material(node: Node) -> void:
	if fallback_material_path.is_empty():
		return
	var material_resource := load(fallback_material_path)
	if not material_resource is Material:
		return
	_apply_material_to_unassigned_meshes(node, material_resource as Material)


func _apply_material_to_unassigned_meshes(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if _mesh_instance_has_material(mesh_instance):
			pass
		else:
			mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material_to_unassigned_meshes(child, material)


func _mesh_instance_has_material(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.material_override:
		return true
	var override_count := mesh_instance.get_surface_override_material_count()
	for i in range(override_count):
		if mesh_instance.get_surface_override_material(i):
			return true
	if mesh_instance.mesh:
		for i in range(mesh_instance.mesh.get_surface_count()):
			if mesh_instance.mesh.surface_get_material(i):
				return true
	return false
