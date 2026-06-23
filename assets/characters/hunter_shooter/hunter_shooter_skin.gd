extends Node3D

const MODEL_SCENE_PATH := "res://assets/characters/hunter_shooter/GodotRobot3rdPersonShooterFinal.glb"
const LOOPING_ACTIONS := {
	"2HandStandingIdle": true,
	"2HandAimWalk": true,
	"2HandRunAim": true,
	"2HandSprint": true,
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
		push_warning("Hunter shooter model could not be loaded: %s" % MODEL_SCENE_PATH)
		return

	_model_root = (model_scene as PackedScene).instantiate() as Node3D
	if not _model_root:
		push_warning("Hunter shooter model did not instantiate as Node3D.")
		return

	_model_root.name = "HunterShooterVisual"
	add_child(_model_root)
	_animation_player = _find_animation_player(_model_root)
	_configure_animation_loops()


func set_walk_run_blending(value: float) -> void:
	walk_run_blending = clampf(value, 0.0, 1.0)


func idle() -> void:
	_play_animation("2HandStandingIdle", ["2HandAim", "IdleNoGun"])


func move() -> void:
	_play_animation("2HandRunAim" if walk_run_blending >= 0.65 else "2HandAimWalk", ["2HandSprint", "2HandStandingIdle"])


func run() -> void:
	walk_run_blending = 1.0
	_play_animation("2HandSprint", ["2HandRunAim", "2HandAimWalk"])


func jump() -> void:
	_play_animation("Jump", ["2HandStandingIdle"])


func fall() -> void:
	_play_animation("Dive", ["Jump", "2HandStandingIdle"])


func attack() -> void:
	_play_animation("2HandStandAimShot", ["2HandStandHipShot", "2HandStandingIdle"])


func set_animation_paused(paused: bool) -> void:
	_animation_paused = paused
	if _animation_player:
		_animation_player.speed_scale = 0.0 if paused else 1.0


func available_actions() -> PackedStringArray:
	_build_skin()
	return PackedStringArray(["idle", "move", "run", "jump", "fall", "attack"])


func has_action(action_name: String) -> bool:
	_build_skin()
	match action_name.to_lower():
		"idle":
			return _has_any_animation(["2HandStandingIdle", "2HandAim", "IdleNoGun"])
		"walk", "move":
			return _has_any_animation(["2HandAimWalk", "2HandRunAim"])
		"run":
			return _has_any_animation(["2HandSprint", "2HandRunAim"])
		"jump":
			return _has_animation("Jump")
		"fall":
			return _has_any_animation(["Dive", "Jump"])
		"attack":
			return _has_any_animation(["2HandStandAimShot", "2HandStandHipShot"])
	return false


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


func _has_any_animation(animation_names: Array[String]) -> bool:
	for animation_name in animation_names:
		if _has_animation(animation_name):
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
