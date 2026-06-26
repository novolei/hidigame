extends Node

signal fov_changed(value: float)

const CONFIG_PATH := "user://settings.cfg"
const DEFAULT_FOV := 68.0
const MIN_FOV := 55.0
const MAX_FOV := 90.0
const DEBUG_LOG_ENV := "MAOMAO_DEBUG_LOG"

var camera_fov := DEFAULT_FOV


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		camera_fov = clampf(float(config.get_value("video", "camera_fov", DEFAULT_FOV)), MIN_FOV, MAX_FOV)
	else:
		camera_fov = DEFAULT_FOV


func set_camera_fov(value: float) -> void:
	var normalized := clampf(value, MIN_FOV, MAX_FOV)
	if is_equal_approx(camera_fov, normalized):
		return
	camera_fov = normalized
	_save_settings()
	fov_changed.emit(camera_fov)


func reset_camera_fov() -> void:
	set_camera_fov(DEFAULT_FOV)


func should_log_runtime_debug() -> bool:
	return _environment_bool(DEBUG_LOG_ENV, OS.is_debug_build() and DisplayServer.get_name() != "headless")


func _environment_bool(env_name: String, default_value: bool) -> bool:
	var raw_value := OS.get_environment(env_name).strip_edges().to_lower()
	if raw_value in ["1", "true", "yes", "on"]:
		return true
	if raw_value in ["0", "false", "no", "off"]:
		return false
	return default_value


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("video", "camera_fov", camera_fov)
	config.save(CONFIG_PATH)
