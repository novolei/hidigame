class_name NetworkInterest
extends RefCounted


static func append_unique_peer_id(recipients: PackedInt32Array, peer_id: int) -> void:
	if peer_id <= 0:
		return
	if recipients.has(peer_id):
		return
	recipients.append(peer_id)


static func is_peer_relevant_to_segment(tree: SceneTree, scene: Node, peer_id: int, segment_start: Vector3, segment_end: Vector3, relevance_radius: float) -> bool:
	var player_node: Node3D = find_player_node_for_peer(tree, scene, peer_id)
	if player_node == null:
		return true
	var observer_position: Vector3 = player_node.global_position + Vector3.UP
	var distance_sq: float = point_segment_distance_squared(observer_position, segment_start, segment_end)
	return distance_sq <= relevance_radius * relevance_radius


static func find_player_node_for_peer(tree: SceneTree, scene: Node, peer_id: int) -> Node3D:
	if scene:
		var players_container: Node = scene.get_node_or_null("PlayersContainer")
		if players_container:
			var player_by_name: Node = players_container.get_node_or_null(str(peer_id))
			if player_by_name is Node3D:
				return player_by_name as Node3D
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group("players"):
		if not node is Node3D:
			continue
		if node.has_method("get_multiplayer_authority") and int(node.get_multiplayer_authority()) == peer_id:
			return node as Node3D
		if str(node.name) == str(peer_id):
			return node as Node3D
	return null


static func point_segment_distance_squared(point: Vector3, segment_start: Vector3, segment_end: Vector3) -> float:
	var segment: Vector3 = segment_end - segment_start
	var length_sq: float = segment.length_squared()
	if length_sq <= 0.0001:
		return point.distance_squared_to(segment_start)
	var amount: float = clampf((point - segment_start).dot(segment) / length_sq, 0.0, 1.0)
	var closest: Vector3 = segment_start + segment * amount
	return point.distance_squared_to(closest)
