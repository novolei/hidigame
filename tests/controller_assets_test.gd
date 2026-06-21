extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []

	var arena_scene := load("res://level/level.tscn")
	if not arena_scene is PackedScene:
		failures.append("Controller tutorial level did not load as a PackedScene")
	else:
		var arena := (arena_scene as PackedScene).instantiate()
		if not arena is Node3D:
			failures.append("Controller tutorial level did not instantiate as Node3D")
		if arena:
			arena.free()

	var main_scene := load("res://scenes/level/level.tscn")
	if not main_scene is PackedScene:
		failures.append("Main level did not load as a PackedScene")
	else:
		var main_level := (main_scene as PackedScene).instantiate()
		if not main_level.get_node_or_null("Environment/GDQuestControllerArena"):
			failures.append("Main level is missing Environment/GDQuestControllerArena")
		main_level.free()

	for path in [
		"res://assets/audio/player/robot_jump.wav",
		"res://assets/audio/player/robot_land.wav",
		"res://assets/audio/player/robot_step_01.wav",
		"res://assets/audio/player/robot_step_02.wav",
		"res://assets/audio/player/robot_step_03.wav",
		"res://assets/audio/player/robot_step_04.wav",
		"res://assets/audio/player/robot_step_05.wav",
	]:
		if not load(path) is AudioStream:
			failures.append("Audio did not load as AudioStream: " + path)

	if failures.is_empty():
		print("[ControllerAssetsTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[ControllerAssetsTest] " + failure)
		get_tree().quit(1)
