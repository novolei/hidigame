extends SceneTree

const PARTY_MONSTER_SCENE_PATH := "res://assets/characters/party_monster/party_monster_skin.tscn"
const ANIMATION_ROOT := "res://assets/characters/party_monster/source/PartyMonsterRumblePBR/Animation"


func _init() -> void:
	var failures: Array[String] = []
	var loaded_scene: Variant = load(PARTY_MONSTER_SCENE_PATH)
	if not loaded_scene is PackedScene:
		failures.append("Party Monster wrapper scene should load as PackedScene")
		_finish(failures)
		return

	var skin: Node = (loaded_scene as PackedScene).instantiate()
	if skin == null:
		failures.append("Party Monster wrapper should instantiate")
		_finish(failures)
		return

	if skin.has_method("set_character_model_id"):
		skin.call("set_character_model_id", "party_monster_c01")
	if skin.has_method("_build_skin"):
		skin.call("_build_skin")
	else:
		failures.append("Party Monster wrapper should expose _build_skin for runtime construction")

	var animation_player: AnimationPlayer = _find_animation_player(skin)
	if animation_player == null:
		failures.append("Party Monster should create an AnimationPlayer")

	var disk_animation_paths: PackedStringArray = _collect_fbx_paths(ANIMATION_ROOT)
	var exposed_paths: PackedStringArray = skin.call("animation_source_paths") if skin.has_method("animation_source_paths") else PackedStringArray()
	var exposed_clips: PackedStringArray = skin.call("available_animation_clips") if skin.has_method("available_animation_clips") else PackedStringArray()
	if disk_animation_paths.size() != 73:
		failures.append("Party Monster source animation folder should contain 73 FBX files; got %d" % disk_animation_paths.size())
	if exposed_paths.size() != disk_animation_paths.size():
		failures.append("Party Monster should expose every animation source path; expected %d got %d" % [disk_animation_paths.size(), exposed_paths.size()])
	for path in disk_animation_paths:
		if not exposed_paths.has(path):
			failures.append("Party Monster animation source is not exposed: %s" % path)
	if exposed_clips.size() != disk_animation_paths.size():
		failures.append("Party Monster should expose one named clip for every source FBX; expected %d got %d" % [disk_animation_paths.size(), exposed_clips.size()])
	if animation_player:
		for clip_name in exposed_clips:
			if not animation_player.has_animation(clip_name):
				failures.append("AnimationPlayer should contain exposed clip: %s" % clip_name)

	var required_actions := [
		"idle", "long_idle", "dizzy", "walk", "run", "jump", "jump_start", "jump_air", "jump_end", "fall", "land",
		"attack", "attack_drill", "attack_saw", "attack_shark", "get_hit", "hit", "defense", "defense_hit",
		"die", "die_recover", "trip", "dance", "victory", "grab", "grab_idle", "push", "slide", "throw",
		"animation_layer_run", "root_motion_run", "root_motion_walk", "root_motion_slide",
	]
	for action_name in required_actions:
		if not skin.has_method("has_action") or not bool(skin.call("has_action", action_name)):
			failures.append("Party Monster should expose action: %s" % action_name)
		var action_clips: PackedStringArray = skin.call("action_animation_clips", action_name) if skin.has_method("action_animation_clips") else PackedStringArray()
		if action_clips.is_empty():
			failures.append("Party Monster action should map to at least one clip: %s" % action_name)
		if animation_player:
			for clip_name in action_clips:
				if not animation_player.has_animation(clip_name):
					failures.append("Action %s references missing clip %s" % [action_name, clip_name])

	for method_name in ["idle", "move", "run", "jump", "fall", "land", "attack", "get_hit", "die", "trip", "dance", "dizzy", "victory", "grab", "grab_idle", "push", "slide", "throw", "play_action", "play_clip", "get_current_animation_length"]:
		if not skin.has_method(method_name):
			failures.append("Party Monster should expose method: %s" % method_name)

	for action_name in ["idle", "move", "attack", "get_hit", "dance", "victory", "jump", "push", "slide", "throw", "trip", "die"]:
		if skin.has_method("play_action") and not bool(skin.call("play_action", action_name)):
			failures.append("Party Monster play_action should accept: %s" % action_name)
		var current_clip := str(skin.call("get_current_animation_clip")) if skin.has_method("get_current_animation_clip") else ""
		if current_clip.is_empty():
			failures.append("Party Monster play_action should select a current clip for: %s" % action_name)
		elif animation_player and not animation_player.has_animation(current_clip):
			failures.append("Current clip should exist after action %s: %s" % [action_name, current_clip])
		if skin.has_method("get_current_animation_length") and float(skin.call("get_current_animation_length")) <= 0.0:
			failures.append("Party Monster current clip should report positive length for: %s" % action_name)

	if skin.has_method("play_action") and skin.has_method("get_current_animation_action"):
		skin.call("play_action", "dance")
		if skin.has_method("idle"):
			skin.call("idle")
		if str(skin.call("get_current_animation_action")) != "dance":
			failures.append("Party Monster idle should not interrupt dance performance")
		if skin.has_method("move"):
			skin.call("move")
		if str(skin.call("get_current_animation_action")) == "dance":
			failures.append("Party Monster movement should interrupt dance performance")
		skin.call("play_action", "victory")
		if skin.has_method("jump"):
			skin.call("jump")
		if str(skin.call("get_current_animation_action")) == "victory":
			failures.append("Party Monster jump should interrupt victory performance")

	if skin.has_method("play_action"):
		skin.call("play_action", "idle")
	elif skin.has_method("idle"):
		skin.call("idle")
	if skin.has_method("_process"):
		skin.call("_process", 8.1)
	if skin.has_method("get_current_animation_action") and str(skin.call("get_current_animation_action")) != "long_idle":
		failures.append("Party Monster should enter long_idle/dizzy after standing idle for the configured timeout")

	_append_performance_camera_source_failures(failures)
	skin.free()
	_finish(failures)


func _append_performance_camera_source_failures(failures: Array[String]) -> void:
	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd").replace("\r\n", "\n")
	for token in ["SKIN_PERFORMANCE_ACTIONS := [\"dance\", \"victory\"]", "request_skin_performance_action", "_begin_skin_performance_camera", "_on_active_skin_action_finished", "set_camera_rig_pose", "SKIN_PERFORMANCE_CAMERA_RETURN_DELAY"]:
		if not player_source.contains(token):
			failures.append("Player should keep Party Monster performance camera token: %s" % token)
	for token in ["match_intro_locked or prep_phase_locked", "_push_skin_performance_wheel_bar", "SKIN_PERFORMANCE_WHEEL_CHARGE_STEP", "SkinPerformanceWheelBar", "_reset_skin_performance_wheel_bar", "_start_skin_performance_effects", "SKIN_PERFORMANCE_CONFETTI_COUNT"]:
		if not player_source.contains(token):
			failures.append("Player should keep gated wheel performance token: %s" % token)
	for token in ["_submit_skin_performance_action", "_request_skin_performance_action_rpc", "_apply_skin_performance_action_rpc.rpc", "_skin_performance_previous_current_camera", "_get_skin_performance_camera", "performance_camera.current = true", "_restore_skin_performance_view_camera"]:
		if not player_source.contains(token):
			failures.append("Player should broadcast Party Monster performance staging token: %s" % token)
	for token in ["SKIN_PERFORMANCE_CAMERA_FRONT_YAW_OFFSET := 0.0", "_get_skin_performance_front_camera_yaw", "var performance_yaw := _get_skin_performance_front_camera_yaw()", "SKIN_PERFORMANCE_CAMERA_SPRING_LENGTH := 5.2", "SKIN_PERFORMANCE_CAMERA_FOV := 58.0", "SKIN_PERFORMANCE_DISCO_LIGHT_COUNT := 3", "SKIN_PERFORMANCE_DISCO_LIGHT_ENERGY", "DiscoLightMarker%02d", "light.shadow_enabled = false"]:
		if not player_source.contains(token):
			failures.append("Player should keep front full-body performance staging token: %s" % token)
	for token in ["SKIN_PERFORMANCE_MUSIC_PATHS", "performance_victory_folk.mp3", "performance_victory_strings.mp3", "performance_victory_8bit.mp3", "SkinPerformanceMusicAudio", "_play_skin_performance_music", "_stop_skin_performance_music", "if not _should_render_local_feedback():\n\t\t_reset_skin_performance_wheel_bar()"]:
		if not player_source.contains(token):
			failures.append("Player should keep local-only random performance music token: %s" % token)
	if player_source.contains("SKIN_PERFORMANCE_CAMERA_YAW := 0.0") or player_source.contains("set_camera_rig_pose\", SKIN_PERFORMANCE_CAMERA_YAW"):
		failures.append("Performance camera should derive its front yaw from the visual body instead of using a fixed world orbit yaw")
	if player_source.contains("SKIN_PERFORMANCE_CAMERA_FRONT_YAW_OFFSET := PI"):
		failures.append("Performance camera front yaw offset should not flip to the character back side")
	if player_source.contains("tween.finished.connect(_clear_skin_performance_effects)"):
		failures.append("Performance disco lights should last until the performance camera restores, not only until the confetti tween ends")
	if player_source.contains("_reset_skin_performance_wheel_bar()\n\t\t_play_skin_action(selected_action)"):
		failures.append("Performance wheel completion should broadcast the selected action instead of playing only on the local client")
	if player_source.contains("if not is_multiplayer_authority() or not _spring_arm_offset:\n\t\treturn"):
		failures.append("Performance camera should not be restricted to the performing player's local authority")
	if not player_source.contains("func _animate_remote_skin_from_network_motion(delta: float) -> void") or not player_source.contains("if _skin_performance_camera_active:\n\t\treturn"):
		failures.append("Remote network motion should not immediately override an active performance broadcast")
	if player_source.contains("outline.name = \"PartyMonsterBountyOutline\"") or player_source.contains("_get_party_monster_bounty_outline_material") or player_source.contains("func _refresh_party_monster_bounty_outlines"):
		failures.append("Party Monster bounty marker should not create copied full-body transparent outline meshes")
	for token in ["_try_party_monster_trip_from_slide_collisions", "_try_party_monster_trip_from_forward_sensor", "PhysicsRayQueryParameters3D.create", "PARTY_MONSTER_TRIP_MIN_SURFACE_HEIGHT_RATIO", "_is_party_monster_trip_surface_high_enough", "_begin_party_monster_trip_lock", "_finish_party_monster_trip_lock", "_should_hold_party_monster_trip_action"]:
		if not player_source.contains(token):
			failures.append("Player should keep Party Monster deterministic trip token: %s" % token)
	var skin_source := FileAccess.get_file_as_string("res://assets/characters/party_monster/party_monster_skin.gd").replace("\r\n", "\n")
	for token in ["\"trip\": [\"trip_01\", \"trip_02\"]", "_make_trip_animation_camera_safe"]:
		if not skin_source.contains(token):
			failures.append("Party Monster skin should keep camera-safe trip token: %s" % token)
	var spring_source := FileAccess.get_file_as_string("res://scripts/spring_arm_offset.gd").replace("\r\n", "\n")
	for token in ["capture_camera_rig_state", "apply_camera_rig_state", "set_camera_input_locked", "_camera_input_locked", "_request_owner_skin_performance_action(\"dance\")", "_request_owner_skin_performance_action(\"victory\")", "refresh_camera_collision_exclusions", "add_excluded_object", "clear_excluded_objects"]:
		if not spring_source.contains(token):
			failures.append("Spring arm should keep camera rig token: %s" % token)
	if spring_source.contains("button_event.button_index == MOUSE_BUTTON_WHEEL_UP:\n\t\t\tzoom_camera"):
		failures.append("Spring arm mouse wheel up should trigger dance instead of zoom")
	if spring_source.contains("button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:\n\t\t\tzoom_camera"):
		failures.append("Spring arm mouse wheel down should trigger victory instead of zoom")


func _collect_fbx_paths(root_path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_fbx_paths_recursive(root_path, paths)
	paths.sort()
	return paths


func _collect_fbx_paths_recursive(path: String, paths: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not file_name.begins_with("."):
			var child_path := path.path_join(file_name)
			if dir.current_is_dir():
				_collect_fbx_paths_recursive(child_path, paths)
			elif file_name.get_extension().to_lower() == "fbx":
				paths.append(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("[PartyMonsterAnimationCatalogTest] PASS")
		quit(0)
		return
	for failure in failures:
		push_error("[PartyMonsterAnimationCatalogTest] " + failure)
	quit(1)
