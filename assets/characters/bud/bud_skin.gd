extends Node3D

const MODEL_SCENE_PATH := "res://assets/characters/bud/bud_character.glb"
const LOOPING_ACTIONS := {
	"idle": true,
	"walk": true,
	"run": true,
	"fall": true,
	"crouch": true,
	"prone": true,
	"prone_crawl": true,
}

@export_range(0.0, 1.0, 0.01) var walk_run_blending := 0.0:
	set = set_walk_run_blending

var _model_root: Node3D
var _animation_player: AnimationPlayer
var _current_action := ""
var _animation_paused := false


func _ready() -> void:
	_build_skin()
	idle()


func _build_skin() -> void:
	if _model_root:
		return

	var model_scene := load(MODEL_SCENE_PATH)
	if not model_scene is PackedScene:
		push_warning("Bud model could not be loaded: %s" % MODEL_SCENE_PATH)
		return

	_model_root = (model_scene as PackedScene).instantiate() as Node3D
	if not _model_root:
		push_warning("Bud model did not instantiate as Node3D.")
		return

	_model_root.name = "BudVisual"
	add_child(_model_root)
	_ground_model_root()
	_animation_player = _find_animation_player(_model_root)
	_configure_animation_loops()


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)


func idle() -> void:
	_play_animation("idle")


func move() -> void:
	_play_animation("run" if walk_run_blending >= 0.65 else "walk", ["idle"])


func run() -> void:
	walk_run_blending = 1.0
	_play_animation("run", ["walk", "idle"])


func jump() -> void:
	_play_animation("jump", ["idle"])


func fall() -> void:
	_play_animation("fall", ["jump", "idle"])


func crouch() -> void:
	_play_animation("crouch", ["idle"])


func prone() -> void:
	_play_animation("prone", ["crouch", "idle"])


func prone_crawl() -> void:
	_play_animation("prone_crawl", ["prone", "crouch", "idle"])


func set_animation_paused(paused: bool) -> void:
	_animation_paused = paused
	if _animation_player:
		_animation_player.speed_scale = 0.0 if paused else 1.0


func available_actions() -> PackedStringArray:
	_build_skin()
	if not _animation_player:
		return PackedStringArray()
	return _animation_player.get_animation_list()


func has_action(action_name: String) -> bool:
	_build_skin()
	return not _resolve_animation_name(action_name).is_empty()


func _configure_animation_loops() -> void:
	if not _animation_player:
		return
	for animation_name in LOOPING_ACTIONS.keys():
		var resolved := _resolve_animation_name(animation_name)
		if resolved.is_empty():
			continue
		var animation := _animation_player.get_animation(resolved)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR


func _play_animation(animation_name: String, fallbacks: Array[String] = []) -> void:
	_build_skin()
	if not _animation_player or _animation_paused:
		return
	var resolved := _resolve_animation_name(animation_name)
	if resolved.is_empty():
		for fallback in fallbacks:
			resolved = _resolve_animation_name(fallback)
			if not resolved.is_empty():
				break
	if resolved.is_empty() or resolved == _current_action:
		return
	_current_action = resolved
	_animation_player.play(resolved, 0.12)


func _resolve_animation_name(action_name: String) -> String:
	if not _animation_player:
		return ""
	if _animation_player.has_animation(action_name):
		return action_name
	var wanted := action_name.to_lower()
	for animation_name in _animation_player.get_animation_list():
		var normalized := animation_name.to_lower()
		if normalized == wanted or normalized.ends_with("/" + wanted) or normalized.ends_with("|" + wanted):
			return animation_name
	return ""


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
