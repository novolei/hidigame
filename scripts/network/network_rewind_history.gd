extends Node
class_name NetworkRewindHistory

@export_range(4, 180, 1) var max_history_ticks: int = 48
@export_range(0.1, 2.5, 0.01, "or_greater") var player_body_radius: float = 0.48
@export_range(0.1, 2.5, 0.01, "or_greater") var disguised_body_radius: float = 0.62
@export_range(0.1, 1.0, 0.01, "or_greater") var head_radius: float = 0.28
@export_range(0.5, 4.5, 0.01, "or_greater") var default_height: float = 1.8
@export_range(0, 12, 1) var max_query_tick_delta: int = 8

var _history_by_tick: Dictionary = {}


static func find_in_tree(tree: SceneTree) -> NetworkRewindHistory:
	if tree == null:
		return null
	var nodes: Array[Node] = tree.get_nodes_in_group("network_rewind_history")
	for node: Node in nodes:
		if node is NetworkRewindHistory:
			return node as NetworkRewindHistory
	return null


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("network_rewind_history")
	if not NetworkTime.after_tick.is_connected(_after_network_tick):
		NetworkTime.after_tick.connect(_after_network_tick)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if NetworkTime.after_tick.is_connected(_after_network_tick):
		NetworkTime.after_tick.disconnect(_after_network_tick)


func _after_network_tick(_delta: float, tick: int) -> void:
	if not RuntimeMode.is_multiplayer_server(multiplayer):
		return
	record_history(tick)


func record_history(tick: int = -1) -> void:
	var sample_tick: int = NetworkTime.tick if tick < 0 else tick
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var states: Array[Dictionary] = []
	var players: Array[Node] = tree.get_nodes_in_group("players")
	for raw_player: Node in players:
		if raw_player == null or not is_instance_valid(raw_player):
			continue
		if not raw_player is Node3D:
			continue
		var player: Node3D = raw_player as Node3D
		var peer_id: int = _peer_id_for_player(player)
		if peer_id <= 0:
			continue
		if player.has_method("is_dead") and bool(player.call("is_dead")):
			continue
		var is_disguised: bool = player.has_method("is_disguised") and bool(player.call("is_disguised"))
		var height: float = _height_for_player(player)
		var radius: float = disguised_body_radius if is_disguised else _radius_for_player(player)
		states.append({
			"peer_id": peer_id,
			"target": player,
			"position": player.global_position,
			"height": height,
			"radius": radius,
			"head_radius": head_radius,
			"disguised": is_disguised,
		})
	_history_by_tick[sample_tick] = states
	_prune_history()


func find_player_hit_on_segment(
	origin: Vector3,
	direction: Vector3,
	max_distance: float,
	query_tick: int,
	excluded_peer_id: int = 0
) -> Dictionary:
	if direction.length_squared() <= 0.000001 or max_distance <= 0.0:
		return {}
	var clean_direction: Vector3 = direction.normalized()
	var resolved_tick: int = _valid_resolved_tick(query_tick)
	if resolved_tick < 0:
		return {}
	var states: Array = _history_by_tick.get(resolved_tick, [])
	var best_hit: Dictionary = {}
	var best_distance: float = INF
	for raw_state: Variant in states:
		if not raw_state is Dictionary:
			continue
		var state: Dictionary = raw_state as Dictionary
		var peer_id: int = int(state.get("peer_id", 0))
		if excluded_peer_id > 0 and peer_id == excluded_peer_id:
			continue
		var target: Variant = state.get("target", null)
		if target == null or not is_instance_valid(target):
			continue
		var position: Vector3 = state.get("position", Vector3.ZERO)
		var height: float = float(state.get("height", default_height))
		var radius: float = float(state.get("radius", player_body_radius))
		var head_hit: Dictionary = _test_sphere_hit(origin, clean_direction, max_distance, position + Vector3.UP * height * 0.82, float(state.get("head_radius", head_radius)))
		if not head_hit.is_empty() and float(head_hit.get("distance", INF)) < best_distance:
			best_distance = float(head_hit.get("distance", INF))
			best_hit = _build_hit(state, head_hit, resolved_tick, query_tick, true)
		var body_centers: Array[Vector3] = [
			position + Vector3.UP * height * 0.24,
			position + Vector3.UP * height * 0.48,
			position + Vector3.UP * height * 0.68,
		]
		for center: Vector3 in body_centers:
			var body_hit: Dictionary = _test_sphere_hit(origin, clean_direction, max_distance, center, radius)
			if body_hit.is_empty():
				continue
			var body_distance: float = float(body_hit.get("distance", INF))
			if body_distance < best_distance:
				best_distance = body_distance
				best_hit = _build_hit(state, body_hit, resolved_tick, query_tick, false)
	return best_hit


func get_player_state_at_tick(peer_id: int, query_tick: int) -> Dictionary:
	if peer_id <= 0:
		return {}
	var resolved_tick: int = _valid_resolved_tick(query_tick)
	if resolved_tick < 0:
		return {}
	var states: Array = _history_by_tick.get(resolved_tick, [])
	for raw_state: Variant in states:
		if not raw_state is Dictionary:
			continue
		var state: Dictionary = raw_state as Dictionary
		if int(state.get("peer_id", 0)) == peer_id:
			return _build_state_result(state, resolved_tick, query_tick)
	return {}


func find_players_in_cone(
	origin: Vector3,
	direction: Vector3,
	max_distance: float,
	half_angle_degrees: float,
	query_tick: int,
	excluded_peer_id: int = 0
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if direction.length_squared() <= 0.000001 or max_distance <= 0.0 or half_angle_degrees <= 0.0:
		return results
	var resolved_tick: int = _valid_resolved_tick(query_tick)
	if resolved_tick < 0:
		return results
	var clean_direction: Vector3 = direction.normalized()
	var cos_half_angle: float = cos(deg_to_rad(half_angle_degrees))
	var states: Array = _history_by_tick.get(resolved_tick, [])
	for raw_state: Variant in states:
		if not raw_state is Dictionary:
			continue
		var state: Dictionary = raw_state as Dictionary
		var peer_id: int = int(state.get("peer_id", 0))
		if excluded_peer_id > 0 and peer_id == excluded_peer_id:
			continue
		var target: Variant = state.get("target", null)
		if target == null or not is_instance_valid(target):
			continue
		var position: Vector3 = state.get("position", Vector3.ZERO)
		var height: float = float(state.get("height", default_height))
		var radius: float = float(state.get("radius", player_body_radius))
		var center: Vector3 = position + Vector3.UP * height * 0.5
		var to_center: Vector3 = center - origin
		var distance: float = to_center.length()
		if distance <= 0.001 or distance > max_distance + radius:
			continue
		var radial_slop: float = clampf(radius / maxf(distance, 0.001), 0.0, 0.25)
		if clean_direction.dot(to_center.normalized()) < cos_half_angle - radial_slop:
			continue
		var result: Dictionary = _build_state_result(state, resolved_tick, query_tick)
		result["distance"] = distance
		result["center"] = center
		results.append(result)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distance", INF)) < float(b.get("distance", INF)))
	return results


func find_players_in_radius(
	center: Vector3,
	radius: float,
	query_tick: int,
	excluded_peer_id: int = 0
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if radius <= 0.0:
		return results
	var resolved_tick: int = _valid_resolved_tick(query_tick)
	if resolved_tick < 0:
		return results
	var states: Array = _history_by_tick.get(resolved_tick, [])
	for raw_state: Variant in states:
		if not raw_state is Dictionary:
			continue
		var state: Dictionary = raw_state as Dictionary
		var peer_id: int = int(state.get("peer_id", 0))
		if excluded_peer_id > 0 and peer_id == excluded_peer_id:
			continue
		var target: Variant = state.get("target", null)
		if target == null or not is_instance_valid(target):
			continue
		var position: Vector3 = state.get("position", Vector3.ZERO)
		var state_radius: float = float(state.get("radius", player_body_radius))
		var distance: float = position.distance_to(center)
		if distance > radius + state_radius:
			continue
		var result: Dictionary = _build_state_result(state, resolved_tick, query_tick)
		result["distance"] = distance
		results.append(result)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("distance", INF)) < float(b.get("distance", INF)))
	return results


func player_was_in_radius(peer_id: int, center: Vector3, radius: float, query_tick: int) -> bool:
	var state: Dictionary = get_player_state_at_tick(peer_id, query_tick)
	if state.is_empty():
		return false
	var state_radius: float = float(state.get("radius", player_body_radius))
	var position: Vector3 = state.get("position", Vector3.ZERO)
	return position.distance_to(center) <= radius + state_radius


func clear() -> void:
	_history_by_tick.clear()


func stored_tick_count() -> int:
	return _history_by_tick.size()


func _nearest_tick(query_tick: int) -> int:
	if _history_by_tick.is_empty():
		return -1
	if query_tick < 0:
		var latest_tick: int = -1
		for raw_tick: Variant in _history_by_tick.keys():
			latest_tick = maxi(latest_tick, int(raw_tick))
		return latest_tick
	var best_tick: int = -1
	var best_delta: int = 2147483647
	for raw_tick: Variant in _history_by_tick.keys():
		var candidate_tick: int = int(raw_tick)
		var delta: int = absi(candidate_tick - query_tick)
		if delta < best_delta:
			best_delta = delta
			best_tick = candidate_tick
	return best_tick


func _valid_resolved_tick(query_tick: int) -> int:
	var resolved_tick: int = _nearest_tick(query_tick)
	if resolved_tick < 0:
		return -1
	if query_tick >= 0 and max_query_tick_delta > 0 and absi(resolved_tick - query_tick) > max_query_tick_delta:
		return -1
	return resolved_tick


func _build_state_result(state: Dictionary, resolved_tick: int, query_tick: int) -> Dictionary:
	return {
		"target": state.get("target", null),
		"peer_id": int(state.get("peer_id", 0)),
		"position": state.get("position", Vector3.ZERO),
		"height": float(state.get("height", default_height)),
		"radius": float(state.get("radius", player_body_radius)),
		"head_radius": float(state.get("head_radius", head_radius)),
		"disguised": bool(state.get("disguised", false)),
		"tick": resolved_tick,
		"query_tick": query_tick,
		"tick_delta": 0 if query_tick < 0 else resolved_tick - query_tick,
	}


func _prune_history() -> void:
	if _history_by_tick.size() <= max_history_ticks:
		return
	var ticks: Array = _history_by_tick.keys()
	ticks.sort()
	while ticks.size() > max_history_ticks:
		var oldest_tick: Variant = ticks.pop_front()
		_history_by_tick.erase(oldest_tick)


func _peer_id_for_player(player: Node) -> int:
	var parsed_id: int = int(str(player.name))
	if parsed_id > 0:
		return parsed_id
	if player.has_method("get_multiplayer_authority"):
		return int(player.call("get_multiplayer_authority"))
	return 0


func _height_for_player(player: Node3D) -> float:
	var collision_shape: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null and collision_shape.shape != null:
		var shape: Shape3D = collision_shape.shape
		if shape is CapsuleShape3D:
			var capsule: CapsuleShape3D = shape as CapsuleShape3D
			return clampf(capsule.height + capsule.radius * 2.0, 0.8, 4.2)
		if shape is CylinderShape3D:
			var cylinder: CylinderShape3D = shape as CylinderShape3D
			return clampf(cylinder.height, 0.8, 4.2)
		if shape is BoxShape3D:
			var box: BoxShape3D = shape as BoxShape3D
			return clampf(box.size.y, 0.8, 4.2)
		if shape is SphereShape3D:
			var sphere: SphereShape3D = shape as SphereShape3D
			return clampf(sphere.radius * 2.0, 0.8, 4.2)
	return default_height


func _radius_for_player(player: Node3D) -> float:
	var collision_shape: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape != null and collision_shape.shape != null:
		var shape: Shape3D = collision_shape.shape
		if shape is CapsuleShape3D:
			return clampf((shape as CapsuleShape3D).radius, 0.18, 1.25)
		if shape is CylinderShape3D:
			return clampf((shape as CylinderShape3D).radius, 0.18, 1.25)
		if shape is SphereShape3D:
			return clampf((shape as SphereShape3D).radius, 0.18, 1.25)
		if shape is BoxShape3D:
			var box_size: Vector3 = (shape as BoxShape3D).size
			return clampf(maxf(box_size.x, box_size.z) * 0.5, 0.18, 1.25)
	return player_body_radius


func _test_sphere_hit(origin: Vector3, direction: Vector3, max_distance: float, center: Vector3, radius: float) -> Dictionary:
	var origin_to_center: Vector3 = origin - center
	var b: float = origin_to_center.dot(direction)
	var c: float = origin_to_center.length_squared() - radius * radius
	var discriminant: float = b * b - c
	if discriminant < 0.0:
		return {}
	var sqrt_discriminant: float = sqrt(discriminant)
	var distance: float = -b - sqrt_discriminant
	if distance < 0.0:
		distance = -b + sqrt_discriminant
	if distance < 0.0 or distance > max_distance:
		return {}
	var hit_position: Vector3 = origin + direction * distance
	var normal: Vector3 = (hit_position - center).normalized()
	if normal.length_squared() <= 0.000001:
		normal = -direction
	return {
		"distance": distance,
		"position": hit_position,
		"normal": normal,
	}


func _build_hit(state: Dictionary, hit: Dictionary, resolved_tick: int, query_tick: int, headshot: bool) -> Dictionary:
	return {
		"hit": true,
		"target": state.get("target", null),
		"peer_id": int(state.get("peer_id", 0)),
		"position": hit.get("position", Vector3.ZERO),
		"normal": hit.get("normal", Vector3.UP),
		"distance": float(hit.get("distance", INF)),
		"headshot": headshot,
		"tick": resolved_tick,
		"query_tick": query_tick,
		"tick_delta": 0 if query_tick < 0 else resolved_tick - query_tick,
	}
