extends Node3D

const MODEL_SCENE_PATH := "res://assets/characters/gingerbread/gingerbread_24k_animated.glb"
const ALBEDO_TEXTURE_PATH := ""
const NORMAL_TEXTURE_PATH := ""
const MODEL_SCALE := 0.32
const MODEL_BASE_ROTATION := Vector3.ZERO
const RUNTIME_PAINT_TRIANGLE_LIMIT := 8000
const RUNTIME_PAINT_TRIANGLE_TARGET := 6000
const LOOPING_ACTIONS := {
	"idle": true,
	"walk": true,
	"run": true,
	"fall": true,
	"crouch": true,
	"prone": true,
	"prone_crawl": true,
}
const COMPATIBLE_ACTIONS := {
	"idle": true,
	"walk": true,
	"run": true,
	"jump": true,
	"fall": true,
	"land": true,
	"crouch": true,
	"prone": true,
	"prone_crawl": true,
}
const ANIMATED_BONES := [
	"spine01",
	"spine02",
	"neck",
	"head",
	"shoulder.L",
	"upper_arm.L",
	"forearm.L",
	"hand.L",
	"shoulder.R",
	"upper_arm.R",
	"forearm.R",
	"hand.R",
	"waist.L",
	"hip.L",
	"chin.L",
	"foot.L",
	"waist.R",
	"hip.R",
	"chin.R",
	"foot.R",
]
@export_range(0.0, 1.0, 0.01) var walk_run_blending := 0.0:
	set = set_walk_run_blending

var _model_root: Node3D
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _bone_indices := {}
var _current_action := ""
var _procedural_time := 0.0
var _animation_paused := false


func _ready() -> void:
	_build_skin()
	idle()


func _process(delta: float) -> void:
	if not _model_root or _animation_paused:
		return
	_procedural_time += delta
	var bob := 0.0
	var lean := 0.0
	var squash := Vector3.ONE
	match _current_action:
		"walk", "run", "prone_crawl":
			var speed := 5.0 if _current_action == "walk" else 7.5
			bob = absf(sin(_procedural_time * speed)) * 0.035
			lean = sin(_procedural_time * speed * 0.5) * 0.045
			squash = Vector3(1.0 + bob * 0.22, 1.0 - bob * 0.12, 1.0 + bob * 0.08)
		"jump":
			bob = 0.055
			lean = -0.05
			squash = Vector3(0.96, 1.04, 0.96)
		"fall":
			bob = -0.025
			lean = 0.05
			squash = Vector3(1.04, 0.96, 1.04)
		"crouch":
			bob = -0.11 + sin(_procedural_time * 2.0) * 0.01
			lean = sin(_procedural_time * 1.5) * 0.012
			squash = Vector3(1.08, 0.78, 1.08)
		"prone":
			bob = -0.22 + sin(_procedural_time * 1.3) * 0.006
			squash = Vector3(1.16, 0.58, 1.18)
		_:
			bob = sin(_procedural_time * 1.8) * 0.012
			lean = sin(_procedural_time * 1.2) * 0.014
	_model_root.position = Vector3(0.0, bob, 0.0)
	_model_root.rotation = MODEL_BASE_ROTATION + Vector3(0.0, 0.0, lean)
	_model_root.scale = Vector3.ONE * MODEL_SCALE * squash


func _build_skin() -> void:
	if _model_root:
		return

	var model_scene := load(MODEL_SCENE_PATH)
	if not model_scene is PackedScene:
		push_warning("Gingerbread animated model could not be loaded: %s" % MODEL_SCENE_PATH)
		return

	_model_root = (model_scene as PackedScene).instantiate() as Node3D
	if not _model_root:
		push_warning("Gingerbread animated model did not instantiate as Node3D.")
		return

	_model_root.name = "GingerbreadVisual"
	_model_root.rotation = MODEL_BASE_ROTATION
	_model_root.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model_root)
	_prioritize_body_mesh(_model_root)
	_hide_helper_meshes(_model_root)
	_optimize_runtime_paint_meshes(_model_root)
	_apply_textures(_model_root)
	_animation_player = _find_animation_player(_model_root)
	_skeleton = _find_skeleton(_model_root)
	_cache_bone_indices()
	if not _animation_player and _skeleton:
		_create_generated_animation_player()
	_configure_animation_loops()


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
	_play_action("jump", ["idle"])


func fall() -> void:
	_play_action("fall", ["jump", "idle"])


func land() -> void:
	_play_action("land", ["idle"])


func crouch() -> void:
	_play_action("crouch", ["idle"])


func prone() -> void:
	_play_action("prone", ["crouch", "idle"])


func prone_crawl() -> void:
	_play_action("prone_crawl", ["prone", "crouch", "idle"])


func hurt() -> void:
	if not _model_root:
		return
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(_model_root, "scale", Vector3(MODEL_SCALE * 1.08, MODEL_SCALE * 0.88, MODEL_SCALE * 1.08), 0.08)
	tween.tween_property(_model_root, "scale", Vector3.ONE * MODEL_SCALE, 0.18)


func set_animation_paused(paused: bool) -> void:
	_animation_paused = paused
	if _animation_player:
		_animation_player.speed_scale = 0.0 if paused else 1.0


func available_actions() -> PackedStringArray:
	if not _animation_player:
		return PackedStringArray(COMPATIBLE_ACTIONS.keys())
	return _animation_player.get_animation_list()


func has_action(action_name: String) -> bool:
	_build_skin()
	if not _animation_player:
		return COMPATIBLE_ACTIONS.has(action_name)
	return not _resolve_animation_name(action_name).is_empty()


func _play_action(action_name: String, fallbacks: Array[String] = []) -> void:
	_build_skin()
	if not _animation_player:
		if COMPATIBLE_ACTIONS.has(action_name):
			_current_action = action_name
		elif not fallbacks.is_empty():
			for fallback in fallbacks:
				if COMPATIBLE_ACTIONS.has(fallback):
					_current_action = fallback
					break
		return

	var resolved_name := _resolve_animation_name(action_name)
	if resolved_name.is_empty():
		for fallback in fallbacks:
			resolved_name = _resolve_animation_name(fallback)
			if not resolved_name.is_empty():
				break
	if resolved_name.is_empty() or resolved_name == _current_action:
		return

	_current_action = resolved_name
	_animation_player.play(resolved_name, 0.12)


func _resolve_animation_name(action_name: String) -> String:
	if not _animation_player:
		return ""
	if _animation_player.has_animation(action_name):
		return action_name

	var wanted := action_name.to_lower()
	for animation_name in _animation_player.get_animation_list():
		var normalized := animation_name.to_lower()
		if normalized == wanted \
				or normalized == "export_" + wanted \
				or normalized.ends_with("/" + wanted) \
				or normalized.ends_with("|" + wanted) \
				or normalized.ends_with("_" + wanted):
			return animation_name
	return ""


func _configure_animation_loops() -> void:
	if not _animation_player:
		return

	for action_name in LOOPING_ACTIONS.keys():
		var resolved_name := _resolve_animation_name(action_name)
		if resolved_name.is_empty():
			continue
		var animation := _animation_player.get_animation(resolved_name)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null


func _cache_bone_indices() -> void:
	_bone_indices.clear()
	if not _skeleton:
		return
	for index in range(_skeleton.get_bone_count()):
		_bone_indices[_skeleton.get_bone_name(index)] = index


func _create_generated_animation_player() -> void:
	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	_animation_player.root_node = _animation_player.get_path_to(_model_root)
	var library := AnimationLibrary.new()
	_add_pose_animation(library, "idle", 1.6, true, [
		{"time": 0.0, "rotations": _idle_pose(1.0)},
		{"time": 0.8, "rotations": _idle_pose(-1.0)},
		{"time": 1.6, "rotations": _idle_pose(1.0)},
	])
	_add_locomotion_animation(library, "walk", 0.85, 0.64)
	_add_locomotion_animation(library, "run", 0.55, 1.0)
	_add_pose_animation(library, "jump", 0.55, false, [
		{"time": 0.0, "rotations": _crouch_pose(1.0)},
		{"time": 0.18, "rotations": _jump_pose()},
		{"time": 0.55, "rotations": _fall_pose(0.35)},
	])
	_add_pose_animation(library, "fall", 0.8, true, [
		{"time": 0.0, "rotations": _fall_pose(1.0)},
		{"time": 0.4, "rotations": _fall_pose(-1.0)},
		{"time": 0.8, "rotations": _fall_pose(1.0)},
	])
	_add_pose_animation(library, "land", 0.35, false, [
		{"time": 0.0, "rotations": _fall_pose(0.25)},
		{"time": 0.12, "rotations": _crouch_pose(1.0)},
		{"time": 0.35, "rotations": _idle_pose(0.0)},
	])
	_add_pose_animation(library, "crouch", 1.2, true, [
		{"time": 0.0, "rotations": _crouch_pose(0.7)},
		{"time": 0.6, "rotations": _crouch_pose(-0.7)},
		{"time": 1.2, "rotations": _crouch_pose(0.7)},
	])
	_add_pose_animation(library, "prone", 1.2, true, [
		{"time": 0.0, "rotations": _prone_pose(0.45)},
		{"time": 0.6, "rotations": _prone_pose(-0.45)},
		{"time": 1.2, "rotations": _prone_pose(0.45)},
	])
	_add_prone_crawl_animation(library)
	_animation_player.add_animation_library("", library)


func _add_locomotion_animation(library: AnimationLibrary, action_name: String, length: float, intensity: float) -> void:
	var keyframes := []
	for step in range(5):
		var time := length * float(step) / 4.0
		var phase := TAU * float(step) / 4.0
		keyframes.append({"time": time, "rotations": _locomotion_pose(phase, intensity)})
	_add_pose_animation(library, action_name, length, true, keyframes)


func _add_prone_crawl_animation(library: AnimationLibrary) -> void:
	var keyframes := []
	for step in range(5):
		var time := float(step) / 4.0
		var phase := TAU * float(step) / 4.0
		keyframes.append({"time": time, "rotations": _prone_crawl_pose(phase)})
	_add_pose_animation(library, "prone_crawl", 1.0, true, keyframes)


func _add_pose_animation(library: AnimationLibrary, animation_name: String, length: float, looping: bool, keyframes: Array) -> void:
	if not _skeleton:
		return
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	var skeleton_path := str(_model_root.get_path_to(_skeleton))
	for bone_name in ANIMATED_BONES:
		var bone_index := int(_bone_indices.get(bone_name, -1))
		if bone_index < 0:
			continue
		var track_index := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, NodePath("%s:bones/%d/rotation" % [skeleton_path, bone_index]))
		animation.value_track_set_update_mode(track_index, Animation.UPDATE_CONTINUOUS)
		for keyframe in keyframes:
			var rotations: Dictionary = keyframe.get("rotations", {})
			var euler: Vector3 = rotations.get(bone_name, Vector3.ZERO)
			animation.track_insert_key(track_index, float(keyframe.get("time", 0.0)), _quat(euler))
	library.add_animation(animation_name, animation)


func _idle_pose(sway: float) -> Dictionary:
	return {
		"spine01": Vector3(0.0, 0.0, 0.025 * sway),
		"spine02": Vector3(0.025, 0.0, -0.045 * sway),
		"neck": Vector3(-0.015, 0.0, 0.025 * sway),
		"head": Vector3(-0.02, 0.0, 0.055 * sway),
		"shoulder.L": Vector3(0.0, 0.0, 0.08),
		"upper_arm.L": Vector3(0.0, 0.04, 0.05 + 0.03 * sway),
		"forearm.L": Vector3(0.03, 0.0, 0.02),
		"shoulder.R": Vector3(0.0, 0.0, -0.08),
		"upper_arm.R": Vector3(0.0, -0.04, -0.05 + 0.03 * sway),
		"forearm.R": Vector3(0.03, 0.0, -0.02),
	}


func _locomotion_pose(phase: float, intensity: float) -> Dictionary:
	var stride := sin(phase)
	var counter := -stride
	var lift := absf(cos(phase))
	return {
		"spine01": Vector3(0.0, 0.0, 0.055 * stride * intensity),
		"spine02": Vector3(-0.05 * intensity, 0.0, -0.075 * stride * intensity),
		"neck": Vector3(0.035 * lift * intensity, 0.0, 0.025 * stride * intensity),
		"head": Vector3(0.04 * lift * intensity, 0.0, -0.05 * stride * intensity),
		"upper_arm.L": Vector3(0.42 * counter * intensity, 0.08, 0.08),
		"forearm.L": Vector3(0.16 + 0.2 * maxf(counter, 0.0) * intensity, 0.0, 0.04),
		"hand.L": Vector3(0.08 * counter * intensity, 0.0, 0.0),
		"upper_arm.R": Vector3(0.42 * stride * intensity, -0.08, -0.08),
		"forearm.R": Vector3(0.16 + 0.2 * maxf(stride, 0.0) * intensity, 0.0, -0.04),
		"hand.R": Vector3(0.08 * stride * intensity, 0.0, 0.0),
		"waist.L": Vector3(0.0, 0.0, 0.08 * counter * intensity),
		"hip.L": Vector3(0.48 * stride * intensity, 0.0, 0.05),
		"chin.L": Vector3(-0.32 * maxf(stride, 0.0) * intensity, 0.0, 0.0),
		"foot.L": Vector3(0.18 * maxf(counter, 0.0) * intensity, 0.0, 0.0),
		"waist.R": Vector3(0.0, 0.0, 0.08 * stride * intensity),
		"hip.R": Vector3(0.48 * counter * intensity, 0.0, -0.05),
		"chin.R": Vector3(-0.32 * maxf(counter, 0.0) * intensity, 0.0, 0.0),
		"foot.R": Vector3(0.18 * maxf(stride, 0.0) * intensity, 0.0, 0.0),
	}


func _jump_pose() -> Dictionary:
	return {
		"spine01": Vector3(-0.08, 0.0, 0.0),
		"spine02": Vector3(-0.16, 0.0, 0.0),
		"neck": Vector3(0.08, 0.0, 0.0),
		"head": Vector3(0.12, 0.0, 0.0),
		"upper_arm.L": Vector3(-0.75, 0.18, 0.25),
		"forearm.L": Vector3(0.2, 0.0, 0.05),
		"upper_arm.R": Vector3(-0.75, -0.18, -0.25),
		"forearm.R": Vector3(0.2, 0.0, -0.05),
		"hip.L": Vector3(0.32, 0.0, 0.05),
		"chin.L": Vector3(-0.22, 0.0, 0.0),
		"hip.R": Vector3(0.32, 0.0, -0.05),
		"chin.R": Vector3(-0.22, 0.0, 0.0),
	}


func _fall_pose(sway: float) -> Dictionary:
	return {
		"spine01": Vector3(0.06, 0.0, 0.03 * sway),
		"spine02": Vector3(0.12, 0.0, -0.05 * sway),
		"neck": Vector3(-0.08, 0.0, 0.02 * sway),
		"head": Vector3(-0.1, 0.0, 0.04 * sway),
		"upper_arm.L": Vector3(0.35, 0.0, 0.22 + 0.08 * sway),
		"forearm.L": Vector3(0.28, 0.0, 0.06),
		"upper_arm.R": Vector3(0.35, 0.0, -0.22 + 0.08 * sway),
		"forearm.R": Vector3(0.28, 0.0, -0.06),
		"hip.L": Vector3(-0.18, 0.0, 0.05),
		"chin.L": Vector3(0.18, 0.0, 0.0),
		"hip.R": Vector3(0.14, 0.0, -0.05),
		"chin.R": Vector3(-0.12, 0.0, 0.0),
	}


func _crouch_pose(sway: float) -> Dictionary:
	return {
		"spine01": Vector3(0.22, 0.0, 0.025 * sway),
		"spine02": Vector3(0.2, 0.0, -0.035 * sway),
		"neck": Vector3(-0.12, 0.0, 0.02 * sway),
		"head": Vector3(-0.16, 0.0, 0.03 * sway),
		"upper_arm.L": Vector3(0.28, 0.1, 0.12),
		"forearm.L": Vector3(0.35, 0.0, 0.05),
		"upper_arm.R": Vector3(0.28, -0.1, -0.12),
		"forearm.R": Vector3(0.35, 0.0, -0.05),
		"hip.L": Vector3(0.55, 0.0, 0.08),
		"chin.L": Vector3(-0.62, 0.0, 0.0),
		"foot.L": Vector3(0.2, 0.0, 0.0),
		"hip.R": Vector3(0.55, 0.0, -0.08),
		"chin.R": Vector3(-0.62, 0.0, 0.0),
		"foot.R": Vector3(0.2, 0.0, 0.0),
	}


func _prone_pose(sway: float) -> Dictionary:
	return {
		"spine01": Vector3(0.42, 0.0, 0.025 * sway),
		"spine02": Vector3(0.36, 0.0, -0.035 * sway),
		"neck": Vector3(-0.24, 0.0, 0.02 * sway),
		"head": Vector3(-0.28, 0.0, 0.03 * sway),
		"upper_arm.L": Vector3(0.65, 0.18, 0.16),
		"forearm.L": Vector3(0.58, 0.0, 0.06),
		"upper_arm.R": Vector3(0.65, -0.18, -0.16),
		"forearm.R": Vector3(0.58, 0.0, -0.06),
		"hip.L": Vector3(0.82, 0.0, 0.1),
		"chin.L": Vector3(-0.72, 0.0, 0.0),
		"foot.L": Vector3(0.25, 0.0, 0.0),
		"hip.R": Vector3(0.82, 0.0, -0.1),
		"chin.R": Vector3(-0.72, 0.0, 0.0),
		"foot.R": Vector3(0.25, 0.0, 0.0),
	}


func _prone_crawl_pose(phase: float) -> Dictionary:
	var crawl := sin(phase)
	var pose := _prone_pose(crawl)
	pose["upper_arm.L"] = Vector3(0.7 + 0.18 * maxf(crawl, 0.0), 0.2, 0.2)
	pose["forearm.L"] = Vector3(0.46 - 0.16 * crawl, 0.0, 0.07)
	pose["upper_arm.R"] = Vector3(0.7 - 0.18 * minf(crawl, 0.0), -0.2, -0.2)
	pose["forearm.R"] = Vector3(0.46 + 0.16 * crawl, 0.0, -0.07)
	pose["hip.L"] = Vector3(0.82 - 0.2 * crawl, 0.0, 0.1)
	pose["hip.R"] = Vector3(0.82 + 0.2 * crawl, 0.0, -0.1)
	return pose


func _quat(euler: Vector3) -> Quaternion:
	return Basis.from_euler(euler).get_rotation_quaternion()


func _hide_helper_meshes(node: Node) -> void:
	if node is MeshInstance3D and node.name.begins_with("Icosphere"):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.visible = false
		mesh_instance.set_meta("camouflage_ignore", true)
	for child in node.get_children():
		_hide_helper_meshes(child)


func _prioritize_body_mesh(node: Node) -> bool:
	var node_name := str(node.name).to_lower()
	if (node_name == "gb_man_body" or node_name.ends_with("_body") or node_name.contains("body")) and node is MeshInstance3D:
		var parent := node.get_parent()
		if parent:
			parent.move_child(node, 0)
		return true
	for child in node.get_children():
		if _prioritize_body_mesh(child):
			return true
	return false


func _optimize_runtime_paint_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var optimized := _build_runtime_paint_mesh(mesh_instance.mesh)
		if optimized:
			optimized.resource_name = "%s_runtime_6k" % str(mesh_instance.name)
			mesh_instance.mesh = optimized
	for child in node.get_children():
		_optimize_runtime_paint_meshes(child)


func _build_runtime_paint_mesh(source_mesh: Mesh) -> ArrayMesh:
	if not source_mesh:
		return null
	var optimized := ArrayMesh.new()
	optimized.resource_local_to_scene = true
	for surface in range(source_mesh.get_surface_count()):
		var arrays := source_mesh.surface_get_arrays(surface) if source_mesh.has_method("surface_get_arrays") else []
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var triangle_count := int(indices.size() / 3.0) if not indices.is_empty() else int(vertices.size() / 3.0)
		if triangle_count <= RUNTIME_PAINT_TRIANGLE_LIMIT:
			optimized.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		else:
			optimized.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _sample_surface_arrays_for_runtime_paint(arrays, triangle_count))
		var material := source_mesh.surface_get_material(surface)
		if material and surface < optimized.get_surface_count():
			optimized.surface_set_material(surface, material)
	if optimized.get_surface_count() == 0:
		return null
	return optimized


func _sample_surface_arrays_for_runtime_paint(source_arrays: Array, triangle_count: int) -> Array:
	var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
	var source_normals := PackedVector3Array()
	var source_tangents := PackedFloat32Array()
	var source_colors := PackedColorArray()
	var source_uvs := PackedVector2Array()
	var source_uv2s := PackedVector2Array()
	var indices := PackedInt32Array()
	var source_bones: Variant = source_arrays[Mesh.ARRAY_BONES]
	var source_weights: Variant = source_arrays[Mesh.ARRAY_WEIGHTS]
	if source_arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
		source_normals = source_arrays[Mesh.ARRAY_NORMAL]
	if source_arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
		source_tangents = source_arrays[Mesh.ARRAY_TANGENT]
	if source_arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
		source_colors = source_arrays[Mesh.ARRAY_COLOR]
	if source_arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
		source_uvs = source_arrays[Mesh.ARRAY_TEX_UV]
	if source_arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array:
		source_uv2s = source_arrays[Mesh.ARRAY_TEX_UV2]
	if source_arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = source_arrays[Mesh.ARRAY_INDEX]
	var target_count := mini(RUNTIME_PAINT_TRIANGLE_TARGET, triangle_count)
	var step := maxf(float(triangle_count) / float(target_count), 1.0)
	var out_vertex_count := target_count * 3
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_tangents := PackedFloat32Array()
	var out_colors := PackedColorArray()
	var out_uvs := PackedVector2Array()
	var out_uv2s := PackedVector2Array()
	var out_bones := PackedInt32Array()
	var out_weights := PackedFloat32Array()
	var has_tangents := source_tangents.size() == vertices.size() * 4
	var has_colors := source_colors.size() == vertices.size()
	var has_uv2s := source_uv2s.size() == vertices.size()
	var has_skinning: bool = (source_bones is PackedInt32Array or source_bones is PackedFloat32Array) \
		and (source_weights is PackedFloat32Array or source_weights is PackedFloat64Array) \
		and source_bones.size() >= vertices.size() * 4 \
		and source_weights.size() >= vertices.size() * 4
	out_vertices.resize(out_vertex_count)
	out_normals.resize(out_vertex_count)
	out_uvs.resize(out_vertex_count)
	if has_tangents:
		out_tangents.resize(out_vertex_count * 4)
	if has_colors:
		out_colors.resize(out_vertex_count)
	if has_uv2s:
		out_uv2s.resize(out_vertex_count)
	if has_skinning:
		out_bones.resize(out_vertex_count * 4)
		out_weights.resize(out_vertex_count * 4)
	for sample_index in range(target_count):
		var triangle_index := mini(int(floor(float(sample_index) * step)), triangle_count - 1)
		var vertex_indices := PackedInt32Array()
		vertex_indices.resize(3)
		if not indices.is_empty():
			vertex_indices[0] = indices[triangle_index * 3]
			vertex_indices[1] = indices[triangle_index * 3 + 1]
			vertex_indices[2] = indices[triangle_index * 3 + 2]
		else:
			vertex_indices[0] = triangle_index * 3
			vertex_indices[1] = triangle_index * 3 + 1
			vertex_indices[2] = triangle_index * 3 + 2
		var write_index := sample_index * 3
		for corner in range(3):
			var out_index := write_index + corner
			var source_index := clampi(vertex_indices[corner], 0, vertices.size() - 1)
			out_vertices[out_index] = vertices[source_index]
			if source_normals.size() == vertices.size():
				out_normals[out_index] = source_normals[source_index]
			if has_tangents:
				for tangent_component in range(4):
					out_tangents[out_index * 4 + tangent_component] = source_tangents[source_index * 4 + tangent_component]
			if has_colors:
				out_colors[out_index] = source_colors[source_index]
			if source_uvs.size() == vertices.size():
				out_uvs[out_index] = source_uvs[source_index]
			if has_uv2s:
				out_uv2s[out_index] = source_uv2s[source_index]
			if has_skinning:
				for influence in range(4):
					out_bones[out_index * 4 + influence] = int(source_bones[source_index * 4 + influence])
					out_weights[out_index * 4 + influence] = float(source_weights[source_index * 4 + influence])
		if source_normals.size() != vertices.size():
			var normal := (out_vertices[write_index + 1] - out_vertices[write_index]).cross(out_vertices[write_index + 2] - out_vertices[write_index]).normalized()
			out_normals[write_index] = normal
			out_normals[write_index + 1] = normal
			out_normals[write_index + 2] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_vertices
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	if has_tangents:
		arrays[Mesh.ARRAY_TANGENT] = out_tangents
	if has_colors:
		arrays[Mesh.ARRAY_COLOR] = out_colors
	arrays[Mesh.ARRAY_TEX_UV] = out_uvs
	if has_uv2s:
		arrays[Mesh.ARRAY_TEX_UV2] = out_uv2s
	if has_skinning:
		arrays[Mesh.ARRAY_BONES] = out_bones
		arrays[Mesh.ARRAY_WEIGHTS] = out_weights
	return arrays


func _apply_textures(node: Node) -> void:
	if ALBEDO_TEXTURE_PATH.is_empty() and NORMAL_TEXTURE_PATH.is_empty():
		return
	var albedo_texture := load(ALBEDO_TEXTURE_PATH) as Texture2D
	var normal_texture := load(NORMAL_TEXTURE_PATH) as Texture2D
	if not albedo_texture and not normal_texture:
		return
	var meshes: Array[MeshInstance3D] = []
	_find_meshes(node, meshes)
	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count() if mesh.mesh else 0):
			var material := _get_mesh_surface_material(mesh, surface)
			if not material is StandardMaterial3D:
				continue
			var standard := (material as StandardMaterial3D).duplicate()
			standard.resource_local_to_scene = true
			if albedo_texture:
				standard.albedo_texture = albedo_texture
				standard.albedo_color = Color.WHITE
			if normal_texture:
				standard.normal_enabled = true
				standard.normal_texture = normal_texture
			mesh.set_surface_override_material(surface, standard)


func _find_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, result)


func _get_mesh_surface_material(mesh: MeshInstance3D, surface: int) -> Material:
	if mesh.get_surface_override_material(surface):
		return mesh.get_surface_override_material(surface)
	if mesh.mesh and surface < mesh.mesh.get_surface_count():
		return mesh.mesh.surface_get_material(surface)
	return null
