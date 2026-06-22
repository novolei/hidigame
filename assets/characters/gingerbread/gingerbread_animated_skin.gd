extends Node3D

const MODEL_SCENE_PATH := "res://assets/characters/gingerbread/gingerbread_meshy_rigged_animated.glb"
const MESHY_RIGGED_RUNTIME_FOOT_OFFSET := 0.96
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

@export_range(0.0, 1.0, 0.01) var walk_run_blending := 0.0:
	set = set_walk_run_blending

var _model_root: Node3D
var _animation_player: AnimationPlayer
var _current_action := ""
var _procedural_time := 0.0
var _animation_paused := false


func _ready() -> void:
	_build_skin()
	idle()


func _process(delta: float) -> void:
	if _animation_player or not _model_root or _animation_paused:
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
		_:
			bob = sin(_procedural_time * 1.8) * 0.012
			lean = sin(_procedural_time * 1.2) * 0.014
	_model_root.position = Vector3(0.0, MESHY_RIGGED_RUNTIME_FOOT_OFFSET + bob, 0.0)
	_model_root.rotation = Vector3(0.0, 0.0, lean)
	_model_root.scale = squash


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
	_model_root.position.y = MESHY_RIGGED_RUNTIME_FOOT_OFFSET
	add_child(_model_root)
	_hide_helper_meshes(_model_root)
	_animation_player = _find_animation_player(_model_root)
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
	tween.tween_property(_model_root, "scale", Vector3(1.08, 0.88, 1.08), 0.08)
	tween.tween_property(_model_root, "scale", Vector3.ONE, 0.18)


func set_animation_paused(paused: bool) -> void:
	_animation_paused = paused


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
		if normalized == wanted or normalized.ends_with("/" + wanted) or normalized.ends_with("|" + wanted):
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


func _hide_helper_meshes(node: Node) -> void:
	if node is MeshInstance3D and node.name.begins_with("Icosphere"):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.visible = false
		mesh_instance.set_meta("camouflage_ignore", true)
	for child in node.get_children():
		_hide_helper_meshes(child)
