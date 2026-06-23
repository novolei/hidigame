extends Node3D

const MODEL_SCENE_PATH := "res://assets/characters/walkall/walkall.fbx"
const SOURCE_ANIMATION := "all"
const COMPATIBLE_ACTIONS := ["idle", "move", "walk", "run", "jump", "fall", "crouch", "prone"]
const ACTION_SEGMENTS := {
	"walk": {"start": 0.0, "end": 2.0, "loop": true, "speed": 1.0},
	"run": {"start": 0.0, "end": 2.0, "loop": true, "speed": 1.35},
	"jump": {"start": 2.0, "end": 4.04, "loop": false, "speed": 1.0},
	"fall": {"start": 2.82, "end": 4.04, "loop": true, "speed": 0.85},
}
const LOOPLESS_POSES := {
	"idle": {"position": Vector3.ZERO, "scale": Vector3.ONE},
	"crouch": {"position": Vector3(0.0, -0.012, 0.0), "scale": Vector3(1.08, 0.78, 1.08)},
	"prone": {"position": Vector3(0.0, -0.024, 0.0), "scale": Vector3(1.20, 0.54, 1.20)},
}

@export_range(0.0, 1.0, 0.01) var walk_run_blending := 0.0:
	set = set_walk_run_blending

var _model_root: Node3D
var _animation_player: AnimationPlayer
var _current_action := ""
var _animation_paused := false
var _base_position := Vector3.ZERO


func _ready() -> void:
	_build_skin()
	idle()


func _process(_delta: float) -> void:
	if _animation_paused or not _animation_player or not _animation_player.has_animation(SOURCE_ANIMATION):
		return
	if not ACTION_SEGMENTS.has(_current_action):
		return

	var segment: Dictionary = ACTION_SEGMENTS[_current_action]
	var segment_start := float(segment.get("start", 0.0))
	var segment_end := minf(float(segment.get("end", _source_animation_length())), _source_animation_length())
	if segment_end <= segment_start:
		return
	if _animation_player.current_animation != SOURCE_ANIMATION or not _animation_player.is_playing():
		_animation_player.play(SOURCE_ANIMATION, 0.08)
		_animation_player.seek(segment_start, true)
	if _animation_player.current_animation_position >= segment_end:
		if bool(segment.get("loop", false)):
			_animation_player.seek(segment_start, true)
		else:
			idle()


func _build_skin() -> void:
	if _model_root:
		return

	var model_scene := load(MODEL_SCENE_PATH)
	if not model_scene is PackedScene:
		push_warning("Walkall model could not be loaded: %s" % MODEL_SCENE_PATH)
		return

	_model_root = (model_scene as PackedScene).instantiate() as Node3D
	if not _model_root:
		push_warning("Walkall model did not instantiate as Node3D.")
		return

	_model_root.name = "WalkallVisual"
	add_child(_model_root)
	_hide_import_helpers(_model_root)
	_ground_model_root()
	_base_position = _model_root.position
	_animation_player = _find_animation_player(_model_root)


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)


func idle() -> void:
	_play_action("idle")


func move() -> void:
	_play_action("run" if walk_run_blending >= 0.65 else "walk")


func run() -> void:
	walk_run_blending = 1.0
	_play_action("run")


func jump() -> void:
	_play_action("jump", ["walk", "idle"])


func fall() -> void:
	_play_action("fall", ["jump", "idle"])


func crouch() -> void:
	_play_action("crouch", ["idle"])


func prone() -> void:
	_play_action("prone", ["crouch", "idle"])


func set_animation_paused(paused: bool) -> void:
	_animation_paused = paused
	if _animation_player:
		_animation_player.speed_scale = 0.0 if paused else _speed_for_current_action()


func available_actions() -> PackedStringArray:
	return PackedStringArray(COMPATIBLE_ACTIONS)


func has_action(action_name: String) -> bool:
	var normalized := action_name.to_lower()
	if normalized == "move":
		normalized = "walk"
	return COMPATIBLE_ACTIONS.has(normalized)


func _play_action(action_name: String, fallbacks: Array[String] = []) -> void:
	_build_skin()
	var normalized := action_name.to_lower()
	if normalized == "move":
		normalized = "walk"
	if not has_action(normalized):
		for fallback in fallbacks:
			if has_action(fallback):
				normalized = fallback
				break
	if normalized.is_empty() or normalized == _current_action:
		return

	_current_action = normalized
	_apply_visual_pose(normalized)
	if not _animation_player or not _animation_player.has_animation(SOURCE_ANIMATION):
		return

	if ACTION_SEGMENTS.has(normalized) and not _animation_paused:
		var segment: Dictionary = ACTION_SEGMENTS[normalized]
		_animation_player.speed_scale = float(segment.get("speed", 1.0))
		_animation_player.play(SOURCE_ANIMATION, 0.08)
		_animation_player.seek(float(segment.get("start", 0.0)), true)
	else:
		_animation_player.stop()
		_animation_player.seek(0.0, true)


func _apply_visual_pose(action_name: String) -> void:
	if not _model_root:
		return
	var pose: Dictionary = LOOPLESS_POSES.get(action_name, LOOPLESS_POSES["idle"])
	_model_root.position = _base_position + (pose.get("position", Vector3.ZERO) as Vector3)
	_model_root.scale = pose.get("scale", Vector3.ONE) as Vector3


func _source_animation_length() -> float:
	if not _animation_player or not _animation_player.has_animation(SOURCE_ANIMATION):
		return 0.0
	var animation := _animation_player.get_animation(SOURCE_ANIMATION)
	return animation.length if animation else 0.0


func _speed_for_current_action() -> float:
	if ACTION_SEGMENTS.has(_current_action):
		var segment: Dictionary = ACTION_SEGMENTS[_current_action]
		return float(segment.get("speed", 1.0))
	return 1.0


func _hide_import_helpers(node: Node) -> void:
	var node_name := str(node.name)
	if node is Node3D:
		var spatial := node as Node3D
		if node_name.begins_with("QuickRigCharacter_Ctrl_") or node_name.begins_with("imagePlane"):
			spatial.visible = false
	if node is Skeleton3D and node_name == "Skeleton3D" and not _has_mesh_descendant(node):
		(node as Skeleton3D).visible = false
	for child in node.get_children():
		_hide_import_helpers(child)


func _has_mesh_descendant(node: Node) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D or _has_mesh_descendant(child):
			return true
	return false


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _ground_model_root() -> void:
	if not _model_root:
		return
	var bounds := _calculate_bounds(_model_root)
	if bounds.size == Vector3.ZERO:
		return
	_model_root.position.y -= bounds.position.y


func _calculate_bounds(node: Node) -> AABB:
	return _calculate_bounds_with_transform(node, Transform3D.IDENTITY)


func _calculate_bounds_with_transform(node: Node, parent_transform: Transform3D) -> AABB:
	var local_transform := parent_transform
	if node is Node3D:
		local_transform = parent_transform * (node as Node3D).transform
	var initialized := false
	var bounds := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		bounds = _transformed_aabb(local_transform, (node as MeshInstance3D).mesh.get_aabb())
		initialized = true
	for child in node.get_children():
		var child_bounds := _calculate_bounds_with_transform(child, local_transform)
		if child_bounds.size == Vector3.ZERO:
			continue
		if not initialized:
			bounds = child_bounds
			initialized = true
		else:
			bounds = bounds.merge(child_bounds)
	return bounds


func _transformed_aabb(transform: Transform3D, local_aabb: AABB) -> AABB:
	var points := [
		local_aabb.position,
		local_aabb.position + Vector3(local_aabb.size.x, 0.0, 0.0),
		local_aabb.position + Vector3(0.0, local_aabb.size.y, 0.0),
		local_aabb.position + Vector3(0.0, 0.0, local_aabb.size.z),
		local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0.0),
		local_aabb.position + Vector3(local_aabb.size.x, 0.0, local_aabb.size.z),
		local_aabb.position + Vector3(0.0, local_aabb.size.y, local_aabb.size.z),
		local_aabb.position + local_aabb.size,
	]
	var first: Vector3 = transform * points[0]
	var bounds := AABB(first, Vector3.ZERO)
	for index in range(1, points.size()):
		bounds = bounds.expand(transform * points[index])
	return bounds
