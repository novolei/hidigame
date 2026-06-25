extends Node

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_scene: PackedScene = load("res://scenes/level/player.tscn")
	var player: Character = player_scene.instantiate() as Character
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var walk_speed := player.get_walk_speed_for_test()
	var run_speed := player.get_run_speed_for_test()
	var walk_interval := player.get_footstep_interval_for_test(false)
	var run_interval := player.get_footstep_interval_for_test(true)
	var run_volume := player.get_footstep_volume_db_for_test(true)
	var walk_audible := player.is_footstep_audible_for_test(false)
	var run_audible := player.is_footstep_audible_for_test(true)

	_expect(run_speed >= walk_speed * 1.8, "Run speed should be clearly faster than walk speed")
	_expect(walk_interval > run_interval * 1.5, "Walking footsteps should keep a slower internal rhythm than running footsteps")
	_expect(not walk_audible, "Walking footsteps should be silent")
	_expect(run_audible, "Running footsteps should remain audible")
	_expect(run_volume > -12.0, "Running footsteps should stay clearly audible")

	player.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("[PlayerMovementAudioProfileTest] PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("[PlayerMovementAudioProfileTest] " + failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
