extends SceneTree


const SCENE_PATH := "res://assets/characters/gingerbread/gingerbread_animated_skin.tscn"
const ACTIONS := ["idle", "walk", "run", "jump", "fall", "crouch", "prone"]
const LIMB_TOKENS := ["Arm", "ForeArm", "Hand", "Thigh", "Shin", "Foot", "Leg"]


func _init() -> void:
	var scene := load(SCENE_PATH)
	if not scene is PackedScene:
		push_error("Could not load %s" % SCENE_PATH)
		quit(1)
		return

	var root := (scene as PackedScene).instantiate()
	root.call("_build_skin")
	var player := _find_animation_player(root)
	if not player:
		push_error("No AnimationPlayer found in gingerbread skin.")
		root.free()
		quit(1)
		return

	var failures: Array[String] = []
	for action_name in ACTIONS:
		var resolved := _resolve_animation_name(player, action_name)
		if resolved.is_empty():
			failures.append("Missing action: %s" % action_name)
			continue
		var animation := player.get_animation(resolved)
		var limb_tracks := 0
		var total_tracks := animation.get_track_count()
		for index in total_tracks:
			var path := str(animation.track_get_path(index))
			for token in LIMB_TOKENS:
				if path.contains(token):
					limb_tracks += 1
					break
		print("[GingerbreadAnimationTrackTest] %s total_tracks=%d limb_tracks=%d" % [resolved, total_tracks, limb_tracks])
		if limb_tracks <= 0:
			failures.append("Action %s has no limb tracks" % resolved)

	root.free()
	if failures.is_empty():
		print("[GingerbreadAnimationTrackTest] PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("[GingerbreadAnimationTrackTest] " + failure)
		quit(1)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _resolve_animation_name(player: AnimationPlayer, action_name: String) -> String:
	if player.has_animation(action_name):
		return action_name
	var wanted := action_name.to_lower()
	for animation_name in player.get_animation_list():
		var normalized := animation_name.to_lower()
		if normalized == wanted or normalized.ends_with("/" + wanted) or normalized.ends_with("|" + wanted):
			return animation_name
	return ""
