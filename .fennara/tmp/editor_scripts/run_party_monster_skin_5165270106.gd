@tool
extends RefCounted

func _node_path_text(node: Node) -> String:
	var names: Array[String] = []
	var current: Node = node
	while current != null:
		names.push_front(String(current.name))
		current = current.get_parent()
	return "/".join(names)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_skeletons(ctx: Variant, node: Node, count: Array[int]) -> void:
	if node is Skeleton3D:
		var skeleton: Skeleton3D = node as Skeleton3D
		count[0] += 1
		ctx.log("skeleton path=%s bones=%d pos=%s" % [_node_path_text(skeleton), skeleton.get_bone_count(), str(skeleton.position)])
		var max_bones: int = mini(skeleton.get_bone_count(), 12)
		for index: int in range(max_bones):
			ctx.log("bone[%d]=%s parent=%d rest_origin=%s pose_origin=%s" % [index, skeleton.get_bone_name(index), skeleton.get_bone_parent(index), str(skeleton.get_bone_rest(index).origin), str(skeleton.get_bone_pose(index).origin)])
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		_find_skeletons(ctx, child, count)

func run(ctx) -> void:
	var root: Node = ctx.get_scene_root()
	if root == null:
		ctx.error("Scene root was null")
		return
	if root.has_method("set_character_model_id"):
		root.call("set_character_model_id", "party_monster_c01")
	if root.has_method("idle"):
		root.call("idle")
	if root.has_method("apply_pose_now"):
		root.call("apply_pose_now", 0.0)
	var player: AnimationPlayer = _find_animation_player(root)
	if player == null:
		ctx.log("animation_player=null")
	else:
		ctx.log("animation_player=%s root_node=%s current=%s playing=%s speed=%s" % [_node_path_text(player), str(player.root_node), str(player.current_animation), str(player.is_playing()), str(player.speed_scale)])
		var names: PackedStringArray = player.get_animation_list()
		ctx.log("animations=%s" % str(names))
		for anim_name: StringName in names:
			var animation: Animation = player.get_animation(anim_name)
			if animation == null:
				continue
			ctx.log("anim=%s length=%.3f tracks=%d" % [str(anim_name), animation.length, animation.get_track_count()])
			var max_tracks: int = mini(animation.get_track_count(), 12)
			for track_index: int in range(max_tracks):
				ctx.log("  track[%d] type=%d path=%s keys=%d" % [track_index, animation.track_get_type(track_index), str(animation.track_get_path(track_index)), animation.track_get_key_count(track_index)])
	var skeleton_count: Array[int] = [0]
	_find_skeletons(ctx, root, skeleton_count)
	ctx.log("skeleton_total=%d" % skeleton_count[0])
