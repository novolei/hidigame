extends Node3D

const MODEL_SCENE_PATH := "res://assets/characters/cute_ice_cream/ice_cream.fbx"
const COMPATIBLE_ACTIONS := ["idle", "move", "walk", "run", "jump", "fall", "crouch", "prone", "prone_crawl"]
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
		push_warning("Cute ice cream model could not be loaded: %s" % MODEL_SCENE_PATH)
		return

	_model_root = (model_scene as PackedScene).instantiate() as Node3D
	if not _model_root:
		push_warning("Cute ice cream model did not instantiate as Node3D.")
		return

	_model_root.name = "CuteIceCreamVisual"
	add_child(_model_root)
	_ground_model_root()
	_polish_materials(_model_root)
	_animation_player = _create_generated_animation_player()
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
	return PackedStringArray(COMPATIBLE_ACTIONS)


func has_action(action_name: String) -> bool:
	var normalized := action_name.to_lower()
	if normalized == "move":
		normalized = "walk"
	return COMPATIBLE_ACTIONS.has(normalized)


func _create_generated_animation_player() -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	add_child(player)
	player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	library.add_animation("idle", _make_root_animation(1.6, [
		{"time": 0.0, "position": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE},
		{"time": 0.8, "position": Vector3(0.0, 0.035, 0.0), "rotation": Vector3(0.0, 0.0, 0.025), "scale": Vector3(1.015, 0.99, 1.015)},
		{"time": 1.6, "position": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE},
	], true))
	library.add_animation("walk", _make_root_animation(0.9, [
		{"time": 0.0, "position": Vector3.ZERO, "rotation": Vector3(0.0, 0.0, -0.045), "scale": Vector3.ONE},
		{"time": 0.225, "position": Vector3(0.0, 0.075, 0.0), "rotation": Vector3(0.0, 0.0, 0.04), "scale": Vector3(1.025, 0.975, 1.025)},
		{"time": 0.45, "position": Vector3.ZERO, "rotation": Vector3(0.0, 0.0, 0.045), "scale": Vector3.ONE},
		{"time": 0.675, "position": Vector3(0.0, 0.075, 0.0), "rotation": Vector3(0.0, 0.0, -0.04), "scale": Vector3(1.025, 0.975, 1.025)},
		{"time": 0.9, "position": Vector3.ZERO, "rotation": Vector3(0.0, 0.0, -0.045), "scale": Vector3.ONE},
	], true))
	library.add_animation("run", _make_root_animation(0.58, [
		{"time": 0.0, "position": Vector3.ZERO, "rotation": Vector3(0.0, 0.0, -0.065), "scale": Vector3.ONE},
		{"time": 0.145, "position": Vector3(0.0, 0.12, 0.0), "rotation": Vector3(0.0, 0.0, 0.065), "scale": Vector3(1.04, 0.955, 1.04)},
		{"time": 0.29, "position": Vector3.ZERO, "rotation": Vector3(0.0, 0.0, 0.065), "scale": Vector3.ONE},
		{"time": 0.435, "position": Vector3(0.0, 0.12, 0.0), "rotation": Vector3(0.0, 0.0, -0.065), "scale": Vector3(1.04, 0.955, 1.04)},
		{"time": 0.58, "position": Vector3.ZERO, "rotation": Vector3(0.0, 0.0, -0.065), "scale": Vector3.ONE},
	], true))
	library.add_animation("jump", _make_root_animation(0.72, [
		{"time": 0.0, "position": Vector3(0.0, -0.06, 0.0), "rotation": Vector3.ZERO, "scale": Vector3(1.06, 0.91, 1.06)},
		{"time": 0.24, "position": Vector3(0.0, 0.34, 0.0), "rotation": Vector3(-0.08, 0.0, 0.08), "scale": Vector3(0.96, 1.11, 0.96)},
		{"time": 0.72, "position": Vector3.ZERO, "rotation": Vector3.ZERO, "scale": Vector3.ONE},
	], false))
	library.add_animation("fall", _make_root_animation(0.9, [
		{"time": 0.0, "position": Vector3(0.0, 0.10, 0.0), "rotation": Vector3(0.08, 0.0, -0.025), "scale": Vector3(0.98, 1.04, 0.98)},
		{"time": 0.45, "position": Vector3(0.0, 0.04, 0.0), "rotation": Vector3(0.04, 0.0, 0.025), "scale": Vector3.ONE},
		{"time": 0.9, "position": Vector3(0.0, 0.10, 0.0), "rotation": Vector3(0.08, 0.0, -0.025), "scale": Vector3(0.98, 1.04, 0.98)},
	], true))
	library.add_animation("crouch", _make_root_animation(1.2, [
		{"time": 0.0, "position": Vector3(0.0, -0.12, 0.0), "rotation": Vector3.ZERO, "scale": Vector3(1.10, 0.78, 1.10)},
		{"time": 0.6, "position": Vector3(0.0, -0.09, 0.0), "rotation": Vector3(0.0, 0.0, 0.018), "scale": Vector3(1.08, 0.80, 1.08)},
		{"time": 1.2, "position": Vector3(0.0, -0.12, 0.0), "rotation": Vector3.ZERO, "scale": Vector3(1.10, 0.78, 1.10)},
	], true))
	library.add_animation("prone", _make_root_animation(1.2, [
		{"time": 0.0, "position": Vector3(0.0, -0.22, 0.0), "rotation": Vector3.ZERO, "scale": Vector3(1.18, 0.56, 1.18)},
		{"time": 0.6, "position": Vector3(0.0, -0.19, 0.0), "rotation": Vector3(0.0, 0.0, -0.014), "scale": Vector3(1.16, 0.58, 1.16)},
		{"time": 1.2, "position": Vector3(0.0, -0.22, 0.0), "rotation": Vector3.ZERO, "scale": Vector3(1.18, 0.56, 1.18)},
	], true))
	library.add_animation("prone_crawl", _make_root_animation(0.85, [
		{"time": 0.0, "position": Vector3(0.0, -0.22, 0.0), "rotation": Vector3(0.0, 0.0, -0.045), "scale": Vector3(1.18, 0.56, 1.18)},
		{"time": 0.2125, "position": Vector3(0.0, -0.15, 0.0), "rotation": Vector3(0.0, 0.0, 0.045), "scale": Vector3(1.12, 0.62, 1.12)},
		{"time": 0.425, "position": Vector3(0.0, -0.22, 0.0), "rotation": Vector3(0.0, 0.0, 0.045), "scale": Vector3(1.18, 0.56, 1.18)},
		{"time": 0.6375, "position": Vector3(0.0, -0.15, 0.0), "rotation": Vector3(0.0, 0.0, -0.045), "scale": Vector3(1.12, 0.62, 1.12)},
		{"time": 0.85, "position": Vector3(0.0, -0.22, 0.0), "rotation": Vector3(0.0, 0.0, -0.045), "scale": Vector3(1.18, 0.56, 1.18)},
	], true))
	player.add_animation_library("", library)
	return player


func _make_root_animation(length: float, keys: Array[Dictionary], loops: bool) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(position_track, NodePath("CuteIceCreamVisual"))
	var rotation_track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(rotation_track, NodePath("CuteIceCreamVisual"))
	var scale_track := animation.add_track(Animation.TYPE_SCALE_3D)
	animation.track_set_path(scale_track, NodePath("CuteIceCreamVisual"))
	for key in keys:
		var time := float(key.get("time", 0.0))
		animation.position_track_insert_key(position_track, time, key.get("position", Vector3.ZERO))
		animation.rotation_track_insert_key(rotation_track, time, Basis.from_euler(key.get("rotation", Vector3.ZERO)).get_rotation_quaternion())
		animation.scale_track_insert_key(scale_track, time, key.get("scale", Vector3.ONE))
	return animation


func _configure_animation_loops() -> void:
	if not _animation_player:
		return
	for animation_name in LOOPING_ACTIONS.keys():
		if not _animation_player.has_animation(animation_name):
			continue
		var animation := _animation_player.get_animation(animation_name)
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
	var normalized := action_name.to_lower()
	if normalized == "move":
		normalized = "walk"
	if _animation_player.has_animation(normalized):
		return normalized
	return ""


func _polish_materials(node: Node) -> void:
	for mesh_instance in _collect_meshes(node):
		if not mesh_instance.mesh:
			continue
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D:
				continue
			var polished := (material as StandardMaterial3D).duplicate(true) as StandardMaterial3D
			polished.resource_local_to_scene = true
			polished.roughness = maxf(polished.roughness, 0.64)
			polished.metallic = 0.0
			mesh_instance.set_surface_override_material(surface, polished)


func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		meshes.append_array(_collect_meshes(child))
	return meshes


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
