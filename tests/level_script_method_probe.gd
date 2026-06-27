extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var content: String = FileAccess.get_file_as_string("res://scripts/level.gd")
	_expect(content.contains("func get_benchmark_metrics()"), "level.gd should define get_benchmark_metrics")
	_expect(content.contains("func _set_benchmark_mode_enabled"), "level.gd should define _set_benchmark_mode_enabled")
	_expect(content.contains("_game_settings()"), "level.gd should resolve GameSettings dynamically")
	if failures.is_empty():
		print("[LevelScriptMethodProbe] PASS")
		quit(0)
		return
	for failure in failures:
		push_error("[LevelScriptMethodProbe] " + failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
