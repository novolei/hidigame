extends Node3D

const MODEL_SCENE_PATH := "res://assets/characters/basic/BaseModel.fbx"
const ANIMATION_SOURCES := {
	"Idle": "res://assets/characters/basic/animations/BaseModel@Idle.fbx",
	"Jump": "res://assets/characters/basic/animations/BaseModel@Jump.fbx",
	"Run": "res://assets/characters/basic/animations/BaseModel@Running.fbx",
}
const LOOPING_ACTIONS := {
	"Idle": true,
	"Run": true,
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
		push_warning("Basic humanoid model could not be loaded: %s" % MODEL_SCENE_PATH)
		return

	_model_root = (model_scene as PackedScene).instantiate() as Node3D
	if not _model_root:
		push_warning("Basic humanoid model did not instantiate as Node3D.")
		return

	_model_root.name = "BasicHumanoidVisual"
	add_child(_model_root)

	_animation_player = AnimationPlayer.new()
	_animation_player.name = "AnimationPlayer"
	add_child(_animation_player)
	_animation_player.root_node = _animation_player.get_path_to(_model_root)
	_import_animation_sources()
	_configure_animation_loops()


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)


func idle() -> void:
	_play_animation("Idle")


func move() -> void:
	_play_animation("Run")


func run() -> void:
	walk_run_blending = 1.0
	_play_animation("Run")


func jump() -> void:
	_play_animation("Jump", ["Idle"])


func fall() -> void:
	_play_animation("Jump", ["Idle"])


func set_animation_paused(paused: bool) -> void:
	_animation_paused = paused
	if _animation_player:
		_animation_player.speed_scale = 0.0 if paused else 1.0


func available_actions() -> PackedStringArray:
	_build_skin()
	return PackedStringArray(["idle", "move", "run", "jump", "fall"])


func has_action(action_name: String) -> bool:
	_build_skin()
	match action_name.to_lower():
		"idle", "walk", "run", "move":
			return _has_animation("Idle") or _has_animation("Run")
		"jump", "fall":
			return _has_animation("Jump")
	return false


func _import_animation_sources() -> void:
	if not _animation_player:
		return
	var library := AnimationLibrary.new()
	for target_name in ANIMATION_SOURCES.keys():
		var source_path: String = ANIMATION_SOURCES[target_name]
		var animation := _load_first_animation(source_path)
		if animation:
			library.add_animation(target_name, animation)
	_animation_player.add_animation_library("", library)


func _load_first_animation(path: String) -> Animation:
	var scene := load(path)
	if not scene is PackedScene:
		push_warning("Basic humanoid animation scene could not load: %s" % path)
		return null
	var node := (scene as PackedScene).instantiate()
	if not node:
		return null
	var player := _find_animation_player(node)
	var animation: Animation = null
	if player:
		var names := player.get_animation_list()
		if not names.is_empty():
			animation = player.get_animation(names[0]).duplicate(true)
	node.free()
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
	var resolved := animation_name if _animation_player.has_animation(animation_name) else ""
	if resolved.is_empty():
		for fallback in fallbacks:
			if _animation_player.has_animation(fallback):
				resolved = fallback
				break
	if resolved.is_empty() or resolved == _current_action:
		return
	_current_action = resolved
	_animation_player.play(resolved, 0.12)


func _has_animation(animation_name: String) -> bool:
	return _animation_player and _animation_player.has_animation(animation_name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
